# Test Automation Coverage Analysis

Maps every case in [TestCases.md](TestCases.md) against the automated suites and classifies
what can be automated. Originally written 2026-07-04; updated 2026-07-05 after two rounds of
gap-closure (see "Gap-closure history" at the bottom). The project now has:

- **Unit tests** (`Doughy Tests`, 12 files, ~165 test methods): recipe math, preferment tool
  (incl. percentage edge cases), scanner parsing/resolution, website importer (+ live corpus),
  export/import (incl. corrupted-file and duplicate-name handling), snapshots/diffs/overrides,
  settings, density-store reset, Core Data migration.
- **UI tests** (`Doughy UI Tests`, 10 files, ~65 test methods): recipe creation (both modes,
  preferments, multi-flour, error paths, chips, temps, instructions), calculator math and
  overrides, unit cycling, edit flows, data integrity, history, home screen, settings +
  ingredient conversions, collection appearance, welcome/what's-new, plus screenshots.
  `UITestSupport.swift` provides a helper layer over stable accessibility identifiers.

Legend:
- ✅ **Covered** — automated
- 🟡 **Partial** — core logic automated, a UI flow or edge is not
- ❌ **Manual** — not practically automatable (system UI, cross-device, camera/LLM, Siri);
  these are collected in the "Manual Testing Required" section of TestCases.md

## Creating Recipes

### By Percentage / By Weight (shared cases)

| Case | Status | Notes |
|---|---|---|
| New collection | ✅ | All creation UI tests |
| Existing collection | ✅ | `testCreateRecipeIntoExistingCollection` |
| Short name | ✅ | `testCreateRecipeWithShortNameSaves` (no min length; non-empty trimmed name required) |
| Existing name (error) | ✅ | `testSavingRecipeWithExistingNameShowsError` ("Save Error" alert) |
| With/Without preferment | ✅ | Both modes |
| Single/multiple flours | ✅ | Both modes |
| Duplicate ingredient names | ✅ | `testCreateRecipeWithDuplicateIngredientNamesSavesBothEntries` (no dedup by design) |
| Suggestion chips | ✅ | `testSuggestionChipFillsIngredientNameAndTypedNameAlsoWorks` |
| With temps | ✅ | `testIngredientTemperatureSurvivesToCalculator` + diff/math unit tests |

### By Weight extras

| Case | Status | Notes |
|---|---|---|
| Known volume ingredient → weight hint | ✅ | UI + resolver unit tests |
| Unknown volume ingredient → no hint | 🟡 | Unit-level covered; UI negative case not written |
| Egg/whites/yolks count → weight hint | 🟡 | Resolver unit tests; UI hint flow not written |
| Fluid-ounce extra ingredient displays correctly | 🟡 | Unit-covered; UI display not written |

### Preferment

| Case | Status | Notes |
|---|---|---|
| No matching ingredients in main dough | ✅ | `testCanAddPrefermentRequiresFlourWaterAndYeast` |
| All matches | ✅ | Poolish/sourdough/biga unit tests |
| Weird percentages that don't add up | ✅ | 0%/negative/>100%/yeast-overconsumption edge tests |
| Matching ingredients at 0g weight | ✅ | `testAddPrefermentWithZeroPercentMainDoughIngredientDoesNotGoNegative` |

### Import recipe link

| Case | Status | Notes |
|---|---|---|
| King Arthur branding cleanup | ✅ | Unit + live corpus |
| NYT Cooking (subscription) | ❌ | Paywall/account |
| YouTuber sites / sallysbakingaddiction | ✅ | Live corpus (100 URLs) |
| Sites from unit tests | ✅ | The corpus |
| Mess with ingredient names/amounts | 🟡 | Fixture-based unit tests |
| Poolish/preferment recipe | ✅ | Preferment-detection unit tests |
| In-app import UI flow | 🟡 | Not UI-tested (would need a network stub) |

### Recipe scanner

| Case | Status | Notes |
|---|---|---|
| Camera / photo-library imports | ❌ | Camera, PhotosUI, live LLM |
| Volume→weight hints, auto-convert, cleanup | ✅ | Parser/resolver unit tests + sample corpus |
| Recipe set chooses correct title | ❌ | Title selection inlined in live-LLM pipeline; needs a refactor to unit-test |

### Instructions

| Case | Status | Notes |
|---|---|---|
| Move instructions around | ✅ | `testMoveInstructionToPositionReordersAndPersists` via the context menu's "Move to position…" sheet (drag handles not exercised) |
| Add/delete instructions | ✅ | Add/delete + persistence |
| Whitespace-only instructions | ✅ | Add Step stays disabled for whitespace-only input |

### Preview

| Case | Status | Notes |
|---|---|---|
| Preview updates after going back | 🟡 | Data-integrity round-trips cover it indirectly |
| Duplicate recipe name save error | ✅ | See "Existing name" above |
| Save with duplicate ingredients | ✅ | See duplicate-ingredients above |

### Collection appearance

| Case | Status | Notes |
|---|---|---|
| Pick built-in icon | ✅ | `testPickingBuiltInIconShowsOnHomeScreenHeader` |
| Pick color | ✅ | `testPickingColorAppliesSelectionInEditorAndOnHomeScreen` |
| Custom emoji via system picker | ❌ | System emoji keyboard isn't scriptable |
| Unset → first-letter avatar fallback | ✅ | `testLeavingIconAndColorUnsetFallsBackToDefaultAvatar` |
| Edit propagates everywhere | ✅ | Home Screen via `testEditingExistingCollectionAppearanceUpdatesHomeScreen`; share/import previews via export/import unit tests |

## Home Screen

| Case | Status | Notes |
|---|---|---|
| Delete recipe / last in collection / last in library | ✅ | `HomeScreenUITests` |
| Edit from swipe / hold menu | ✅ | `HomeScreenUITests` + edit suites |
| Share from swipe / hold menu | 🟡 | Sheet presentation automated; completing the send is manual |

## Sharing & Importing Recipes

| Case | Status | Notes |
|---|---|---|
| Share with/without "From" name and note | 🟡 | Payload round-trips unit-tested; visual composition manual |
| Send/receive via Messages/Mail/AirDrop/Files | ❌ | Cross-app system UI |
| Import when name/collection already exists | ✅ | `testImportingDuplicateNamedRecipeThrowsRecipeExistsError` (behavior: throws) |
| Corrupted / non-recipe .doughy file | ✅ | Malformed/empty/wrong-schema decode tests + `RecipeFile.load` returning nil |
| "Shared by X" banner + collapse state | ❌ | Needs cross-app import to trigger |
| Share extension | ❌ | Out-of-process; parsing logic shared and unit-covered |

## Settings

| Case | Status | Notes |
|---|---|---|
| Temp / volume toggles | ✅ | `SettingsTests` persistence + `SettingsUITests` pickers |
| Change conversion values/units | ✅ | Persistence + unit-menu UI tests |
| Add ingredient to a section | ✅ | `testAddCustomIngredientAppearsAndPersistsAfterReopening` |
| New ingredient in suggestion chips | ✅ | `testAddCustomIngredientAppearsAsSuggestionChipInCreateFlow` |
| New ingredient in bake session + toggle | ✅ | `testAddCustomIngredientCyclesToConfiguredUnitInBakeSession` |
| Delete ingredient → no toggles, no chips | ✅ | `testDeletingCustomIngredientRemovesChipAndStopsCycling` |
| Egg size default + egg weights | ✅ | Pickers/fields UI + resolver unit tests |
| Fluid-ounce conversion shows g/fl oz | ✅ | `testFluidOunceConversionAppearsInUnitMenu` |
| Reset all to defaults | ✅ | Store unit test + `testResetAllToDefaultsRestoresChangedValues` |
| Recently deleted: restore / delete all / empty hint | ✅ | `SettingsUITests` |
| Backup & restore big library | 🟡 | Document round-trip unit-tested; Files-picker flow manual |
| Links at bottom | ✅ | Existence/hittable asserts |
| iCloud sync across two devices | ❌ | Two-device; cloud-mirror store logic unit-tested |
| Region/locale drives units | 🟡 | Region-fallback unit test; full locale sweep manual |

## Bake Session

| Case | Status | Notes |
|---|---|---|
| Toggle ingredient amounts | ✅ | Dry + liquid cycling tests, plus unknown-ingredient negative case |
| Fl oz in the unit cycle | ✅ | `testTappingLiquidIngredientCyclesDisplayUnit` |
| fl oz import converts via density | ✅ | Importer/scanner unit tests |
| Peek bar: tap to reveal | ✅ | `expandIngredients()` everywhere |
| Peek bar drag physics | ❌ | Gesture physics too flaky |
| Adjust: add/remove preferment | ✅ | Add + remove UI tests, override unit tests |
| Tweak doughs / weights / percentages (both modes) | ✅ | `RecipeCalculatorUITests` |
| Copy recipe | ✅ | `testCopyRecipeAppearsInList` |
| Edit → dismiss reflects changes | ✅ | Edit + data-integrity suites |
| Set as Default | ✅/❌ | Flow automated on iPhone; iPad multi-pane propagation manual |

## History

All ✅ — `RecipeHistoryUITests`.

## Siri, Shortcuts & Quick Actions

All ❌ — not drivable by XCUITest. Intent handler logic could be unit-tested behind a seam
(future work).

## Welcome

| Case | Status | Notes |
|---|---|---|
| First install shows welcome | ✅ | `-ForceNewUserOnboarding` launch flag |
| Update over 1.0 shows What's New | ✅/❌ | Screen automated via `-ForceWhatsNew`; a real upgrade install (with data migration) stays manual, though migration itself is unit-tested |

## Summary

| | Count (approx.) |
|---|---|
| Automated (✅) | ~75 cases |
| Partially automated (🟡) | ~12 cases |
| Manual only (❌) | ~18 cases |

Manual-only core: anything crossing the app sandbox (share delivery, AirDrop/Mail/Messages,
share extension, Files picker), two-device iCloud sync, camera/photo + live LLM scanning,
scanner title selection (pending refactor), Siri/Shortcuts, gesture physics, system emoji
keyboard, and iPad multi-pane propagation.

## Gap-closure history

**Round 1 (2026-07-04):** ~41 tests. Unit: preferment percentage/0g edge cases, corrupted
`.doughy`, duplicate-name import, density-store reset. UI (existing suites): existing
collection, duplicate-name error, duplicate ingredients, chips, temps, instructions
add/delete/whitespace, copy recipe, by-weight adjust, liquid unit cycling, remove preferment.
New suites: `HomeScreenUITests`, `SettingsUITests`, `WelcomeUITests` (+ launch-flag reorder in
`RecipeListView.checkOnboarding` so `-ForceNewUserOnboarding`/`-ForceWhatsNew` work under
`-UITesting`).

**Round 2 (2026-07-05):** ~13 tests. Short name, instruction reorder (via "Move to position…"
sheet), dry/unknown ingredient cycling, the full add/delete custom-ingredient conversion
cluster incl. g/fl oz, and the new `CollectionAppearanceUITests` (icon, color, fallback
avatar, edit propagation — asserted via an additive `accessibilityValue` on the collection
header, preserving the label-derived identifiers `HomeScreenUITests` relies on).
