# Plan: Collection Appearance (icon + color)

Status: proposed
Scope: iOS (phone) + Android now; iPad rail/sidebar avatars as a follow-up with the
tablet redesign. visionOS/Android XR out of scope.

Companion: [docs/design/tablet-design-proposals.md](docs/design/tablet-design-proposals.md)

## Core direction

Stop treating this as "a recipe icon that happens to be shown on the collection."
The durable model is:

- **Collection appearance = icon + color.** It belongs to the collection.
- **Recipe = belongs to a collection, no visual identity of its own.**

One concept, used everywhere: iPhone, iPad, Android phone, Android tablet,
import/export, and any future surface.

The stored icon is a **shared semantic key** (`pizza`, `bread`, `cake`, `coffee`),
not a platform-specific symbol name. Each platform maps that key to its own glyph
set (SF Symbols on iOS, Material icons on Android). Appearance stays **keyed by
collection name**, because collections are still name-based on every platform.

Explicit non-goal: do **not** ship more heuristic emoji/category guessing. The
existing iPad `collectionRailGlyph(...)` heuristic gets *deleted* once the model
exists, not extended.

## Codebase reality (three repos)

This work spans three checkouts. Per decision, **all iOS work happens on the
tablet branch** (`~/workspace/Doughy-tablet-design` @ `codex/tablet-design-proposals`),
and the phone-facing appearance ships for the phone + Android launch; the
iPad-specific surfacing is part of the deferred tablet redesign.

### iOS — phone (mainline) and tablet branch (same repo)

There is **no appearance data of any kind today.** No recipe icon, no recipe or
collection color.

- Collections are grouped at runtime from `recipe.collection` strings in
  `Settings.refreshRecipes()` → `[RecipeCollection]`
  ([Doughy/Utilities/Settings.swift:41](Doughy/Utilities/Settings.swift)).
- `RecipeCollection` holds only `name` + `recipes`
  ([Doughy/Model/Recipes/RecipeCollection.swift](Doughy/Model/Recipes/RecipeCollection.swift)).
- No collection metadata store exists.
- `Recipe`/`PrefermentRecipe` have no icon/color fields
  ([Doughy/Model/Recipes/Recipe.swift](Doughy/Model/Recipes/Recipe.swift)).
- Phone list section headers are plain text + a collapse chevron
  ([Doughy/Views/RecipeListView.swift](Doughy/Views/RecipeListView.swift)).
- The create/edit collection control is a `Picker` + "New Collection" toggle/field
  — no icon/color ([Doughy/Views/CreateRecipeView.swift](Doughy/Views/CreateRecipeView.swift),
  `detailsForm`).

The tablet branch additionally has the rail prototype already:

- `tabletRail` (78 pt) with per-collection buttons, and `tabletRecipeList`
  (`.listStyle(.sidebar)`), gated on `horizontalSizeClass == .regular`
  ([Doughy/Views/RecipeListView.swift](Doughy/Views/RecipeListView.swift)).
- **`collectionRailGlyph(for:)` is the heuristic to remove** — it hard-codes
  🍕🥯🍞🍰🍪 by name substring, falling back to the first letter
  ([Doughy/Views/RecipeListView.swift](Doughy/Views/RecipeListView.swift), ~L463).

### Android (`~/workspace/Doughy-Android`)

The color half is largely **done**; icon is the recipe-scoped piece to move.

- **Color is already collection-scoped**: `CollectionColorStore`
  (collection name → color key, SharedPreferences `collection_colors`)
  (`app/.../data/CollectionColorStore.kt`).
- Rendering infra exists: `CollectionAvatar` (icon + color, with a live-preview
  color override) and `LocalCollectionColors` composition local
  (`app/.../ui/theme/CollectionColor.kt`); list headers already use it
  (`app/.../ui/recipelist/RecipeListScreen.kt:261`).
- Color catalog: `recipeColorCatalog` / `recipeColorFor`
  (`app/.../ui/theme/RecipeColors.kt`).
- **Icon is recipe-scoped and stored as a Material key** (e.g. `"LocalPizza"`)
  on the recipe row (`app/.../data/db/Entities.kt` `val icon: String?`,
  mapped in `RecipeMappers.kt`). Picker + color swatches live inside
  `CreateRecipeScreen.kt` (recipe details).
- Icon catalog `RecipeIcons.kt` keys by Material name and carries a
  `legacyKeyAliases` map of old **slugs → Material keys** (`"pizza" → "LocalPizza"`).
  This is the seed for the shared catalog, but the direction must **flip**:
  store the semantic slug, resolve slug → Material at render.

### Shared file format

The `.doughy` file is **byte-for-byte identical** across platforms (both v2):
`{version, author?, note?, recipe:{name, collection, defaultWeight,
measurementMode, ingredients[], preferment?, instructions[]}}`
([Doughy/Model/Recipes/RecipeFile.swift](Doughy/Model/Recipes/RecipeFile.swift),
`app/.../data/RecipeFile.kt`). Any appearance field must be added **identically**
on both, backward-compatibly. iOS also has a separate library backup
(`.doughylibrary`, v1) with no Android counterpart yet.

## The shared model

### `CollectionAppearance`

```
CollectionAppearance {
  iconKey: CollectionIconKey?   // shared semantic slug, nil → first-letter avatar
  colorKey: CollectionColorKey? // shared color slug,    nil → derived/default
}
```

Stored per collection name. Both fields optional so an un-customized collection
falls back gracefully (first-letter avatar over a derived color, which is what
Android already does today).

### Shared semantic icon-key catalog

One canonical slug list, owned in lockstep by both platforms. Reuse Android's
existing 31 slugs as the seed (`bread, grain, pizza, cake, cookie, oven, egg,
burger, dinner, brunch, noodles, rice, meal, soup, tapas, icecream, restaurant,
flatware, coffee, tea, cocktail, wine, herb, plant, fridge, blender, microwave,
star, heart, home, bolt`).

Each platform owns a mapping table:

| slug | iOS (SF Symbol) | Android (Material key) |
|------|-----------------|------------------------|
| coffee | `cup.and.saucer` | `LocalCafe` |
| cake | `birthday.cake` | `Cake` |
| oven | `oven` | `LocalFireDepartment` |
| microwave | `microwave` | `Microwave` |
| fridge | `refrigerator` | `Kitchen` |
| wine | `wineglass` | `WineBar` |
| pizza / bread / bagel / cookie | *custom asset* | `LocalPizza` / `BakeryDining` / … |

**Constraint — size the catalog to the weaker platform.** SF Symbols has sparse
food coverage; several core baking glyphs (pizza, bread, bagel, cookie) have no
native symbol. For those, add custom vector assets (PDF/SVG in the asset catalog)
so the set is consistent cross-platform rather than dropping glyphs on iOS.
Verify each SF Symbol against the app's deployment target before committing the
table (some kitchen symbols are iOS 17+).

Android keeps its full Material picker, but the **persisted value becomes the
slug**; `RecipeIcons.kt` resolves slug → Material at render. The current
`legacyKeyAliases` (slug → Material) becomes the canonical forward map; add a
reverse map only where a migration needs Material → slug (see Migration).

### Shared color-key catalog

iOS has no color catalog yet; create one mirroring Android's `recipeColorCatalog`
**keys** so colors round-trip across platforms. Keep the actual rendered hues
platform-tuned (Android already tunes light/dark in `CollectionColor.kt`); only
the *key* is shared.

## Storage

### iOS — new `CollectionAppearanceStore`

A small `@Observable` store persisted **separately from recipes** (UserDefaults,
JSON `[collectionName: CollectionAppearance]`), mirroring the existing
UserDefaults stores in this codebase (recents, recently-deleted). Inject through
the environment like `RecipeStore`. Expose:

- `appearance(for: name) -> CollectionAppearance`
- `setIcon(_:for:)` / `setColor(_:for:)`
- lifecycle helpers: `rename(from:to:)`, `adopt(into:from:)`, `cleanupOrphans(validNames:)`

Add an `appearance` accessor on `RecipeCollection` (or look it up at the view
layer via the store) so list/rail rendering needs only the collection name.

### Android — collection appearance store

Color already lives in `CollectionColorStore`. Either rename/expand it to a
`CollectionAppearanceStore` (color + icon maps) or add a parallel
`CollectionIconStore` with the same shape. Prefer one store so the two stay
consistent under rename/merge. `CollectionAvatar` already takes both an icon and
a color, so the rendering change is mostly providing icon via a composition local
alongside `LocalCollectionColors`.

**Remove the recipe-level icon** from the editable recipe path: drop it from the
`CreateRecipeScreen` recipe form. Keep the DB `icon` column through the migration,
then stop writing it (a later cleanup migration can drop it).

## Collection lifecycle semantics

These rules apply on both platforms via the store helpers:

- **Rename** moves the appearance entry to the new name.
- **Move a recipe into an existing collection** → the recipe adopts that
  collection's appearance (no per-recipe appearance exists). New target
  collection created during a move → seed from the picker choice.
- **Merge** (renaming A to an existing B) → B's appearance wins; A's entry is
  cleaned up.
- **Delete / empty collection** → its appearance metadata is removed
  (`cleanupOrphans` runs on refresh against the live collection-name set).

## Create / edit / import flows

- The **collection picker previews the collection avatar** (icon + color) next to
  each name.
- **"New collection"** lets the user choose an icon and color at creation time
  (small inline icon grid + color swatch row, seeded with a sensible default).
- **iOS**: add these controls to `CreateRecipeView`'s `detailsForm` collection
  section, and to `ImportRecipeView` for a newly-created collection on import.
- **Android**: move the icon picker out of the recipe form. Editing a
  collection's icon/color becomes a **collection editor** (long-press a header or
  a dedicated entry), reusing the existing `recipeIconCatalog` /
  `recipeColorCatalog` pickers.

## Browsing surfaces

### Phone — launch scope

- **iOS**: render a `CollectionAvatar` (new view) in `RecipeListView` section
  headers and in the create/import collection picker.
- **Android**: already renders collection avatars in list headers; switch the
  icon source from recipe-level to the collection appearance store.

### iPad rail + sidebar — follow-up (with tablet redesign)

- Replace `collectionRailGlyph(for:)` entirely with the collection avatar
  (icon + color). **Delete the emoji heuristic.**
- Use the same avatar in the `tabletRecipeList` sidebar section headers.
- This lands on the tablet branch but is gated behind the broader tablet redesign,
  so it does not block the phone + Android launch.

### Android tablet — follow-up

Mirror the iPad rail: collection avatars in the adaptive rail and list/group
headers, once the Android adaptive shell exists.

## Import / export

Add an **optional** `collectionAppearance` object to the shared `.doughy`
envelope, written identically on both platforms. Because it is optional, readers
on older builds simply ignore it — no reader-breaking change, so the format
version can stay v2 (or bump to 3 if you prefer an explicit signal; not required
for back-compat).

- Single recipe export: attach the source collection's appearance (so a shared
  recipe can seed a brand-new collection on the recipient's device).
- iOS library backup (`.doughylibrary`): add a top-level
  `collections: { name: CollectionAppearance }` map. (Android has no library
  backup yet; add one only if/when needed.)

**Import behavior (both platforms):**

- If the target collection **already exists locally** → keep the **local**
  appearance (never overwrite the user's choice).
- If it's a **new** collection → seed appearance from the imported metadata
  (icon slug resolves per platform; unknown slug → first-letter fallback).
- Parser is backward compatible: missing field → no appearance seeded.

## Migration

- **iOS**: no data migration needed — there's no prior appearance. Only introduce
  sensible defaults (un-customized collections render the first-letter avatar over
  a derived color, matching Android's current behavior).
- **Android**: migrate **recipe icon → collection icon**.
  - Read each collection's recipe icons (Material keys / legacy slugs).
  - If all recipes in a collection share one icon → use it.
  - If mixed → pick the **most common**; the rest are dropped implicitly.
  - Convert the chosen Material key → **slug** (reverse of `legacyKeyAliases`)
    and write it to the appearance store, keyed by collection name.
  - Color is already collection-scoped — leave it as-is.
  - Run once, guarded by a migration flag; keep the DB `icon` column readable
    until the migration has run, then stop writing it.

## Testing

- **Android migration**: all-same / mixed / none, Material-key and legacy-slug
  inputs, most-common tie-breaking.
- **Lifecycle (both)**: rename moves appearance; move-into-existing adopts target;
  merge keeps target; delete/empty cleans up orphans.
- **Import/export round-trip (both)**: existing-collection keeps local appearance;
  new-collection seeds from import; missing field is a clean no-op; unknown icon
  slug falls back to first letter.
- **Catalog mapping**: every shared slug resolves to a glyph on both platforms
  (guards against an iOS gap with no custom asset).
- **UI checks**: iPhone headers + picker, Android phone headers + collection
  editor; iPad rail/sidebar and Android tablet deferred with the redesign.

## Implementation order

1. **Shared catalogs.** Define the canonical icon-slug set + color-key set;
   author the iOS SF-Symbol/custom-asset table and flip Android to store slugs
   (slug → Material at render).
2. **Android storage + migration.** Expand to a collection appearance store;
   migrate recipe icon → collection icon; switch `CollectionAvatar` icon source.
3. **iOS appearance store + avatar.** Add `CollectionAppearanceStore`, a
   `CollectionAvatar` view, and the color catalog.
4. **Create/edit/import flows (both).** Avatar preview in the picker;
   icon+color on new-collection; Android collection editor.
5. **Phone browsing surfaces (both).** Section-header avatars. *(launch)*
6. **Import/export.** Optional `collectionAppearance` field + backward-compatible
   parser on both; iOS library-backup `collections` map.
7. **Cleanup + tests.** Drop the Android recipe `icon` column; full test pass.
8. **(Follow-up) iPad + Android tablet rail.** Replace `collectionRailGlyph`
   with avatars; mirror on the Android adaptive shell.

## Open coordination questions

- **Merge path to the phone build.** iOS work lives on the tablet branch, but the
  phone appearance ships at launch. Confirm how steps 3–6 reach phone users —
  merge the tablet branch to mainline, or cherry-pick the phone-facing commits.
  Structure commits so the shared model + phone surfaces are independently
  landable from the iPad rail work.
- **Default appearance for the seeded default recipes.** Decide whether the
  built-in collections (Pizza, Bagels, etc.) ship with curated icon+color
  defaults or start as first-letter avatars. Curated defaults are a nice first
  impression but add a small seed table per platform.
- **Format version.** Keep `.doughy` at v2 with an optional field (recommended,
  fully back-compatible) vs. bump to v3 as an explicit signal.
