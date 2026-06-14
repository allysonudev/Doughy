# Plan: Recipe History (notes + version snapshots + rollback)

## Summary of the feature

Each recipe gets a **History** screen (reachable from `CalculatorView`'s
toolbar) listing two kinds of entries, newest-first:

- **Note** — free text + date. Added from the calculator results screen
  (`CalculatedRecipeView`) via "+ Add Note", pre-filled with a diff of any
  "Adjust" overrides if present, otherwise empty with placeholder text.
- **Version** — a full snapshot of the recipe's prior state + an
  auto-generated diff summary (e.g. "Salt: 2% → 2.4%\nWater: 65% → 68%") +
  date. Created automatically whenever:
  - A real edit is saved via `CreateRecipeView` and the new data differs from
    what was persisted (no-op saves create nothing).
  - The user taps **"Set as Default"** on the results screen (see below).
  - The user **restores** a version (the pre-restore state is snapshotted
    first, so restores are themselves reversible).

Both entry kinds are swipe-to-delete. Version entries additionally have a
"Restore this version" action.

### "Set as Default" (results screen)

Shown whenever the user has set *any* value in the calculator's "Adjust"
fields — ingredient percent overrides, preferment percent/temp overrides, or
a custom single-dough-weight — regardless of whether that value happens to
match the recipe's current default (simpler condition, avoids edge-case
diffing bugs).

Tapping it shows a confirmation listing every changed value, e.g.:
```
Salt: 2% → 2.2%
Water: 63% → 68%
Weight: 350g → 400g
```
Confirming:
1. Snapshots the *current* recipe state as a new "version" history entry
   (diff summary = the same lines shown in the confirmation).
2. Overwrites the recipe's ingredient percentages, temperatures, preferment
   percentages/temps, and `defaultWeight` with the calculator's override
   values.

## 1. CoreData model

New entity `XCHistoryEntry` in `Doughy.xcdatamodeld` (new model version,
lightweight/additive migration):

- `id: UUID`
- `date: Date`
- `kind: String` — `"note"` or `"version"`
- `text: String` — note body, or the auto-generated diff summary for versions
- `snapshot: Data?` — JSON-encoded `RecipeSnapshot`, present only for
  `"version"` entries

Relationship: `XCRecipe.historyEntries` (toMany, deletionRule = **Cascade**)
↔ `XCHistoryEntry.recipe` (toOne, deletionRule = Nullify) — so deleting a
recipe deletes its history.

## 2. Codable snapshot types

New file `Model/Recipes/RecipeSnapshot.swift`. None of the existing
`Ingredient`/`Recipe`/`Preferment` classes are `Codable` (they're
`NSObject`-based), so add small `Codable` mirror structs used only for
serialization/diffing:

```swift
struct RecipeSnapshot: Codable {
    let defaultWeight: Double
    let ingredients: [IngredientSnapshot]
    let instructions: [String]
    let preferment: PrefermentSnapshot?
}

struct IngredientSnapshot: Codable {
    let name: String
    let isFlour: Bool
    let defaultPercentage: Double
    let temperatureValue: Double?
    let temperatureMeasurement: String?   // Temperature.measurement.rawValue
    let extraAmount: Double?
    let extraUnit: String?
}

struct PrefermentSnapshot: Codable {
    let name: String
    let flourPercentage: Double
    let ingredients: [IngredientSnapshot]
}
```

Add:
- `RecipeSnapshot.init(from recipe: any RecipeProtocol)` — builds a snapshot
  from the live model (name/collection deliberately excluded — renames aren't
  tracked by this feature).
- A reconstruction path back to `Recipe`/`PrefermentRecipe` + `[Ingredient]`
  for restore (used by `HistoryWriter.restoreVersion`).

## 3. Diff/summary logic

New file `Model/Recipes/RecipeDiff.swift`:

```swift
enum RecipeDiff {
    /// Returns nil if there's no meaningful difference between `old` and `new`.
    static func summarize(from old: RecipeSnapshot, to new: RecipeSnapshot) -> String?
}
```

Behavior:
- Match ingredients by name (case-insensitive); for each match where
  `defaultPercentage` or `temperature` differs, emit a line via
  `PercentFormatter`/`TemperatureFormatter` (e.g. `"Salt: 2% → 2.4%"`,
  `"Water: 75°F → 78°F"`).
- Ingredients present only in `old` → `"- Removed <name>"`; only in `new` →
  `"+ Added <name>"`.
- Same matching for `preferment.ingredients` and
  `preferment.flourPercentage` (e.g. `"Poolish flour: 50% → 60%"`).
- `defaultWeight` change → `"Weight: 350g → 400g"` via `WeightFormatter`.
- Instructions: if the array differs at all, a single line
  `"Instructions updated"` (full text not diffed).
- Returns `nil` if no lines were produced (used to suppress no-op edit
  history entries).

This same function is reused for:
- The edit-save diff check (Section 5).
- The "Set as Default" confirmation text (Section 6) — diff between the
  current recipe snapshot and a snapshot built from the calculator overrides.
- The note pre-fill text on the results screen (Section 6) — diff between
  current recipe snapshot and the override snapshot, same as above.

## 4. Persistence layer additions

**`Data Store/Doughy.xcdatamodeld`**: add `XCHistoryEntry` + relationship
(Section 1).

**`ObjectFactory`**: add `createHistoryEntry() -> XCHistoryEntry`.

**`RecipeReader`**: add
`getHistoryEntries(for recipe: XCRecipe) -> [XCHistoryEntry]`, sorted by
`date` descending.

**New `HistoryEntryConverter`** (mirrors the existing converter pattern):
- Domain type:
  ```swift
  struct HistoryEntry: Identifiable {
      let id: UUID
      let date: Date
      let kind: Kind
      let text: String
      enum Kind { case note, version(RecipeSnapshot) }
  }
  ```
- `convertToExternal(_ entry: XCHistoryEntry) -> HistoryEntry` — decodes
  `snapshot` JSON when `kind == "version"`.

**New `HistoryWriter`** (mirrors `RecipeWriter`):
- `addNote(_ text: String, to recipe: XCRecipe)`
- `addVersion(snapshot: RecipeSnapshot, summary: String, to recipe: XCRecipe)`
- `deleteEntry(_ entry: XCHistoryEntry)`
- `restoreVersion(_ entry: XCHistoryEntry, recipe: XCRecipe) throws`:
  1. Build a `RecipeSnapshot` of `recipe`'s *current* state, compute
     `RecipeDiff.summarize(from: currentSnapshot, to: entry's snapshot)`
     (label e.g. `"Restored to version from <date>"` if the diff function
     returns nil because nothing textually differs, otherwise use the diff
     text), and `addVersion(...)` with that summary — this is the
     "rollback is itself reversible" entry.
  2. Decode `entry.snapshot` and overwrite `recipe` via
     `RecipeConverter.overWriteCoreData` (reconstruct `Recipe`/
     `PrefermentRecipe` from the snapshot first).

**`RecipeStore`** additions (wrapping `HistoryWriter`/`RecipeReader`):
- `historyEntries(for recipe: any RecipeProtocol) -> [HistoryEntry]`
- `addNote(_ text: String, to recipe: any RecipeProtocol)`
- `deleteHistoryEntry(_ entry: HistoryEntry, from recipe: any RecipeProtocol)`
- `restoreVersion(_ entry: HistoryEntry, for recipe: any RecipeProtocol) throws`
- `setAsDefault(recipe: any RecipeProtocol, overrides: CalculatorOverrides) throws`
  (Section 6) — snapshots current state via `addVersion`, then overwrites
  ingredient percentages/temps, preferment percentages/temps, and
  `defaultWeight` from `overrides`.

## 5. Edit-triggered version entries

Hook into `RecipeWriter.updateRecipe(recipe:existingName:existingCollection:)`:

1. (Existing) fetch the pre-edit `XCRecipe`.
2. **New**: `oldSnapshot = RecipeSnapshot(from: RecipeConverter.convertToExternal(existingXCRecipe))`,
   `newSnapshot = RecipeSnapshot(from: recipe)` (the incoming, post-edit recipe).
3. **New**: `if let summary = RecipeDiff.summarize(from: oldSnapshot, to: newSnapshot)`,
   call `historyWriter.addVersion(snapshot: oldSnapshot, summary: summary, to: existingXCRecipe)`
   *before* `overWriteCoreData` runs.
4. (Existing) `overWriteCoreData(...)`, save context.

New-recipe saves (`writeRecipe`) never create history entries.

## 6. Calculator → results screen plumbing

### `CalculatorOverrides` (new small struct, e.g. in `CalculatorView.swift`)

Bundles the calculator's adjustment state so it can be passed to
`CalculatedRecipeView`:

```swift
struct CalculatorOverrides {
    let ingredientPercents: [Int: Double]
    let ingredientTemps: [Int: Double]
    let prefermentIngredientPercents: [Int: Double]
    let prefermentTotalPercent: Double?
    let singleDoughWeight: Double?

    var hasAnyOverride: Bool {
        !ingredientPercents.isEmpty || !ingredientTemps.isEmpty
            || !prefermentIngredientPercents.isEmpty
            || prefermentTotalPercent != nil || singleDoughWeight != nil
    }

    /// Applies these overrides on top of `recipe` to produce the snapshot
    /// "Set as Default" would persist.
    func applied(to recipe: any RecipeProtocol) -> RecipeSnapshot { ... }
}
```

### `CalculatorView` changes

- Construct a `CalculatorOverrides` from existing `@State` (lines 16-19, 12)
  when navigating to results.
- Pass `recipe` and the `overrides` snapshot to `CalculatedRecipeView`
  alongside `calculatedRecipe` (extend the `CalculatedWrapper` /
  `navigationDestination` at lines 105-110).
- Add a toolbar button (e.g. `clock.arrow.circlepath`, accessibility id
  `"historyButton"`) navigating to `RecipeHistoryView(recipe: recipe)`.

### `CalculatedRecipeView` changes

New `@State`/`@Environment`:
- `@Environment(RecipeStore.self) private var store`
- `let recipe: any RecipeProtocol`
- `let overrides: CalculatorOverrides`
- `@State private var noteText: String = ""`
- `@State private var showingSetAsDefaultConfirmation = false`

New UI (new `Section`, placed after Instructions):
- **"+ Add Note"**: a `TextField`/`TextEditor` bound to `noteText`,
  initialized (in `.onAppear` or `init`) to
  `RecipeDiff.summarize(from: RecipeSnapshot(from: recipe), to: overrides.applied(to: recipe)) ?? ""`
  — pre-filled when overrides differ, empty (placeholder "Add a note about
  this batch...") otherwise. "Save Note" button (disabled when empty) calls
  `store.addNote(noteText, to: recipe)` and clears the field.
- **"Set as Default"**: shown only if `overrides.hasAnyOverride`. Tapping
  sets `showingSetAsDefaultConfirmation = true`; a confirmation
  `.alert`/`.confirmationDialog` shows the diff lines from
  `RecipeDiff.summarize(from: RecipeSnapshot(from: recipe), to: overrides.applied(to: recipe))`
  (falling back to a generic message if that's somehow nil) with
  Confirm/Cancel. Confirm calls `store.setAsDefault(recipe:, overrides:)`.

## 7. History screen

New file `Views/RecipeHistoryView.swift`:

```swift
struct RecipeHistoryView: View {
    let recipe: any RecipeProtocol
    @Environment(RecipeStore.self) private var store
    @State private var restoreTarget: HistoryEntry?
}
```

- `List` of `store.historyEntries(for: recipe)`, each row showing the
  formatted `date` and `text` (multi-line for version diffs).
- `.onDelete` / swipe action → `store.deleteHistoryEntry(entry, from: recipe)`.
- For `.version` entries, a trailing "Restore" swipe action sets
  `restoreTarget = entry`; a confirmation alert ("Restore recipe to this
  version? Current recipe state will be saved to history first.") calls
  `store.restoreVersion(entry, for: recipe)` and likely calls
  `store.refresh()` / dismisses back to the recipe list afterward (the open
  `CalculatorView`/`CreateRecipeView` would otherwise show stale data).
- Empty state: "No history yet" placeholder.

## 8. Tests

**Unit-style** (`RecipeDiff`, can live in the existing `Doughy Tests` target):
- No changes → `nil`.
- Percentage/temperature change on an existing ingredient → correct line(s).
- Added/removed ingredient → `"+ Added ..."` / `"- Removed ..."`.
- `defaultWeight` change, preferment change, instructions change.

**UI tests** (`Doughy UI Tests`, new `RecipeHistoryUITests.swift`):
- Edit a recipe with a real change → reopen History from the calculator →
  one version entry with the expected diff text; tap Restore → confirm →
  recipe reflects the old values again, and a *new* version entry exists
  recording the rollback.
- Edit a recipe with no changes → History stays empty.
- In the calculator, set an ingredient percent override and a custom single
  dough weight → "Set as Default" appears on the results screen → tap it →
  confirmation shows the expected diff lines → confirm → recipe's stored
  defaults update, and History gains a version entry for the pre-change state.
- Add a note with no overrides (placeholder/empty prefill) and a note with
  overrides (pre-filled diff) → both appear correctly in History.
- Delete a note entry and a version entry via swipe → both removed from the
  list; deleting a version entry doesn't affect the live recipe.

## Suggested implementation order

1. Section 1 (CoreData model) + Section 2 (`RecipeSnapshot`) — foundational,
   no UI impact yet.
2. Section 3 (`RecipeDiff`) + its unit tests — pure logic, easy to verify in
   isolation.
3. Section 4 (persistence layer: `HistoryWriter`/`HistoryEntryConverter`/
   `RecipeStore` additions) — still no UI.
4. Section 5 (edit-triggered version entries) — testable via existing
   `CreateRecipeView` edit flows + new UI test.
5. Section 7 (History screen) — can be built/tested against entries created
   manually via `RecipeStore` in tests even before Section 6 exists.
6. Section 6 (Calculator/results screen: overrides plumbing, "Add Note",
   "Set as Default") — ties everything together.
