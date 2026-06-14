# Plan: Persist recipes "by weight" (unlock flour-free recipes)

## Background

Today, every recipe is stored as baker's percentages: `XCIngredient.defaultPercentage`
(percent of total flour weight) is the *only* persisted amount, and
`Calculator` scales everything off that + `recipe.defaultWeight`. `CreateRecipeView`
lets you *enter* ingredients "by weight" at creation, but `IngredientBuilder.build()`
immediately converts those grams to `defaultPercentage = weight / totalFlourWeight * 100`
before saving (see `Model/IngredientsBuilder.swift` lines ~191-224). On edit, the view
always reopens in `.byPercent` mode (`CreateRecipeView.swift:213`), showing those
converted percentages — this is what `RecipeDataIntegrityUITests` now documents.

Goal: let a recipe be persisted with absolute gram weights per ingredient, scaled
by `newTotalWeight / originalTotalWeight` at calculation time, instead of baker's
percentages. This removes the requirement that a recipe contain flour, and makes
"by weight" edits round-trip exactly.

Baker's-percentage recipes (the common case for bread/pizza/etc.) keep working
exactly as they do today — this is purely additive.

## Phase 1 — Data model & persistence

- `Doughy.xcdatamodeld`: new model version.
  - `XCRecipe`: add `measurementMode` (String, optional, default `"percent"`) —
    values `"percent"` / `"weight"`.
  - `XCIngredient`: add `defaultWeight` (Double, optional).
  - Lightweight migration only (new optional attrs with defaults) — no mapping
    model needed. Update `.xccurrentversion`.
- `Model/Recipes/Ingredient.swift`: add `defaultWeight: Double?`.
- `Model/Recipes/Recipe.swift` / `RecipeProtocol`: add a
  `RecipeMeasurementMode { case percent, weight }` and a
  `measurementMode: RecipeMeasurementMode` property (default `.percent`).
- `Data Store/IngredientConverter.swift` and `RecipeConverter.swift`: read/write
  the two new fields both directions.

## Phase 2 — Builders (`Model/IngredientsBuilder.swift`, `RecipeBuilder.swift`)

- `RecipeBuilder` gains `measurementMode`.
- When `measurementMode == .weight`:
  - `IngredientBuilder.build()` stores `defaultWeight = weight` directly —
    **no** conversion to `defaultPercentage`. `defaultPercentage` is left `nil`
    unless the ingredient `isFlour` and a total flour weight exists (kept around
    only for any UI that still wants a percent display).
  - `RecipeBuilder.defaultWeight` = sum of all ingredient `defaultWeight`s (this
    matches existing behavior at `CreateRecipeView.swift:1320-1352`, just without
    the percent round-trip).
  - Skip `calculateDefaultFlourWeight()` (lines ~124-136) entirely — it's
    percent-specific.
- Preferment stays percent-of-flour based (it's inherently a flour concept). In
  `.weight` mode, only allow/keep the preferment toggle when the recipe contains
  at least one flour ingredient; otherwise hide it. No change to preferment
  builder logic itself.

## Phase 3 — Calculator (`Utilities/Calculator.swift`)

- Add a `.weight`-mode path to both `calculate(...)` overloads:
  - `ratio = totalWeight / recipe.defaultWeight` (or sum of input
    `MeasuredIngredient` weights, for the "adjust ingredients" calculator screen).
  - `weight_i = ingredient.defaultWeight * ratio`.
  - `percentage_i` / `totalPercentage`: only compute when `totalFlourWeight > 0`;
    otherwise leave `nil`.
- `CalculatedIngredient.percentage` / `.totalPercentage` become `Double?`.
- `Views/CalculatedRecipeView.swift`: hide the percent line (`ingredientPercent_*`)
  when `percentage == nil` (i.e. flour-free weight-mode recipes).
- `Views/CalculatorView.swift`: the "Adjust Dough Ingredients" percent-editing UI
  is meaningless without flour — for `.weight`-mode, flour-free recipes, either
  hide that toggle/section or adapt it to edit weights directly (decide during
  implementation; smallest change is to hide it when there's no flour).

## Phase 4 — `CreateRecipeView.swift` edit flow

- `init(editingRecipe:)` (currently line 213 hardcodes
  `_inputMode = State(initialValue: .byPercent)`):
  - Initialize `inputMode` from `recipe.measurementMode`.
  - When `.byWeight`, populate `FlourRow`/`IngredientRow` values from
    `ingredient.defaultWeight` instead of `defaultPercentage` (lines ~220-222 and
    the preferment equivalents ~239/243/256/259).
- `ingredientsReady` (line ~756): the `abs(sum - 100) < 0.001` flour-percent
  constraint already only applies to `.byPercent` — confirm `.byWeight` validation
  doesn't require any flour at all when there's no preferment.
- Mode picker (lines ~456-502): no UI change needed, just make sure the chosen
  mode is what gets persisted via `measurementMode`.

## Phase 5 — Default recipes & tests

- `Utilities/DefaultRecipeFactory.swift`: explicitly set
  `measurementMode = .percent` on the 4 seeded recipes (no behavior change, just
  explicit).
- Optional/stretch: add a seeded or sample flour-free "by weight" recipe (e.g. a
  simple syrup, brine, or sauce) to exercise the new path end-to-end.
- UI tests:
  - Extend `RecipeDataIntegrityUITests` byWeight tests so that, post-fix, editing
    a byWeight recipe shows the *original gram values* again (reverting the
    percent-based expectations from this session) and reopens in "by weight" mode.
  - Add a new UI test creating a flour-free byWeight recipe (e.g. two ingredients,
    no flour) and running it through the calculator, asserting weights scale by
    the simple ratio and no percent labels are shown.
  - `RecipeCalculatorUITests`: add a byWeight-recipe calculator test (with flour)
    to confirm weight-mode scaling matches percent-mode for an equivalent recipe.

## Open questions to confirm during implementation

1. Should `.weight`-mode recipes with flour still expose `defaultPercentage` for
   display (e.g. baker's-percentage info box), or only show grams? (Plan above
   computes it opportunistically when flour is present.)
2. Preferment + flour-free `.weight` recipes: confirmed out of scope — preferment
   requires flour, so the toggle is hidden when there's no flour, regardless of mode.
3. CloudKit sync (`CoreDataGateway` uses `NSPersistentCloudKitContainer`) — new
   optional attributes with defaults should sync fine, but worth a quick manual
   check after the schema change.

## Suggested implementation order

1. Phase 1 (model + converters) — small, mechanical, unblocks everything else.
2. Phase 2 (builders) — byWeight recipes now persist real weights.
3. Phase 4 (CreateRecipeView edit) — byWeight recipes round-trip correctly; update
   the 3 `RecipeDataIntegrityUITests` back to gram-based expectations.
4. Phase 3 (Calculator + views) — scaling works for flour-free recipes.
5. Phase 5 (default recipes + new tests) — polish and regression coverage.
