# Test Automation Coverage Analysis

Maps every case in [TestCases.md](TestCases.md) against the existing automated suites and
classifies what can be automated. As of this analysis the project has:

- **Unit tests** (`Doughy Tests`, 12 files, ~150 test methods): recipe math, preferment tool,
  scanner parsing/resolution (54 tests), website importer (+ live corpus), export/import,
  snapshots/diffs/overrides, settings, Core Data migration.
- **UI tests** (`Doughy UI Tests`, 7 files, ~31 test methods): recipe creation (both modes,
  preferments, multi-flour), calculator math on screen, edit flows, data integrity round-trips,
  history, plus screenshot automation. `UITestSupport.swift` provides a rich helper layer over
  stable accessibility identifiers.

Legend:
- ✅ **Covered** — already automated
- 🟡 **Partial** — core logic automated (usually unit level), UI flow or an edge is not
- ⚪ **Gap** — automatable with current infrastructure, not yet written
- ❌ **Manual** — not practically automatable (system UI, cross-device, camera/LLM, Siri)

## Creating Recipes

### By Percentage / By Weight (shared cases)

| Case | Status | Notes |
|---|---|---|
| New collection | ✅ | All creation UI tests use `fillDetails` with a new collection |
| Existing collection | ⚪ | No test picks an existing collection from `collectionPicker` |
| Short name | ⚪ | Trivial UI variant |
| Existing name (error) | ⚪ | Duplicate-name save error never exercised |
| With/Without preferment | ✅ | `RecipeCreationUITests` covers both, in both modes |
| Single/multiple flours | ✅ | `testCreateRecipeBy{Percent,Weight}MultipleFloursAndIngredients` |
| Duplicate ingredient names | ⚪ | Also listed under Preview; not exercised anywhere |
| Suggestion chips | ⚪ | No test taps a chip or asserts chips appear |
| With temps | 🟡 | Unit: temp math + diffs covered; UI: `ingredientTempField_N` never touched |

### By Weight extras

| Case | Status | Notes |
|---|---|---|
| Known volume ingredient → weight hint | ✅ | `testVolumeIngredientShowsWeightConversionOption` + resolver unit tests |
| Unknown volume ingredient → no hint | 🟡 | Unit-level covered (`testUnknownConversionPromptSkipsCountUnits`); UI negative case absent |
| Egg/whites/yolks count → weight hint | 🟡 | Resolver unit tests cover conversion; UI hint flow untested |
| Fluid-ounce extra ingredient displays correctly | 🟡 | Unit: `testFluidOuncesParseAsFluidOunceVolume`, shared-constant test; UI display untested |

### Preferment

| Case | Status | Notes |
|---|---|---|
| No matching ingredients in main dough | 🟡 | `testCanAddPrefermentRequiresFlourWaterAndYeast` covers gating; creation-flow variant untested |
| All matches | ✅ | Poolish/sourdough/biga unit tests |
| Weird percentages that don't add up | ⚪ | Only hydration-exceeds-water is tested; over/under-100%, zero, negative untested |
| Matching ingredients at 0g weight | ⚪ | Unit-testable in `PrefermentToolTests` |

### Import recipe link

| Case | Status | Notes |
|---|---|---|
| King Arthur branding cleanup | ✅ | `testStripsBrandAndMarketingPrefixFromIngredientName` + live corpus |
| NYT Cooking (subscription) | ❌ | Requires account/paywall session |
| YouTuber sites / sallysbakingaddiction | ✅ | Live corpus (100 URLs) |
| Sites from unit tests | ✅ | That *is* the corpus |
| Mess with ingredient names/amounts | 🟡 | Fixture-based unit tests cover many mutations; fuzzing could expand |
| Poolish/preferment recipe | ✅ | Preferment-detection unit tests |
| In-app import UI flow | ⚪ | `websiteRecipeURLField` exists; no UI test drives it (would need a stub/local fixture to avoid network) |

### Recipe scanner

| Case | Status | Notes |
|---|---|---|
| Camera / photo-library imports (all variants) | ❌ | Camera, PhotosUI picker, and live LLM calls — manual |
| Volume→weight hints, auto-convert, cleanup | ✅ | 54 parser/resolver unit tests incl. sample corpus |
| Recipe set chooses correct title | ⚪ | Title-selection logic is unit-testable if exposed; verify in `RecipeScannerTypes`/`RecipeScanner` |

### Instructions

| Case | Status | Notes |
|---|---|---|
| Move instructions around | ⚪ | Drag-reorder in XCUITest is possible but flaky; attempt, fall back to manual |
| Add/delete instructions | ⚪ | Straightforward UI test |
| Whitespace-only instructions | ⚪ | Should assert trim/reject behavior |

### Preview

| Case | Status | Notes |
|---|---|---|
| Preview updates after going back | 🟡 | `RecipeDataIntegrityUITests` round-trips edits; explicit preview-refresh assert absent |
| Duplicate recipe name save error | ⚪ | Gap (same as "Existing name" above) |
| Save with duplicate ingredients | ⚪ | Gap |

### Collection appearance

| Case | Status | Notes |
|---|---|---|
| Pick built-in icon / color | ⚪ | Editor has identifiers (`collectionUseEmojiButton`, `collectionEmojiField`); no UI test |
| Custom emoji via system picker | ❌ | System emoji keyboard isn't scriptable; `collectionEmojiField` typing is a partial proxy |
| Unset → first-letter avatar fallback | ⚪ | UI-assertable |
| Edit propagates everywhere | 🟡 | Export/import + store round-trips unit-tested; list/preview UI propagation untested |

## Home Screen

| Case | Status | Notes |
|---|---|---|
| Delete recipe | ⚪ | Swipe-delete easily automatable |
| Delete last recipe in collection / in library | ⚪ | Assert collection disappears / empty state |
| Edit from swipe | ✅ | `editRecipe(named:)` used by edit suites |
| Share from swipe / hold menu | 🟡 | Can assert share sheet presents; can't complete the send (system UI) |
| Delete / edit from hold (context) menu | ⚪ | Context menus are scriptable via `press(forDuration:)` |

## Sharing & Importing Recipes

| Case | Status | Notes |
|---|---|---|
| Share with/without "From" name and note | 🟡 | `.doughy` payload round-trips unit-tested incl. metadata; share-sheet composition manual |
| Send via Messages/Mail/AirDrop/Files | ❌ | Cross-app system UI |
| Receive from AirDrop/Mail/Messages/Files | ❌ | Cross-app; the *handling* code is unit-tested via import round-trips |
| Import when name/collection already exists | ⚪ | Unit-testable against the import path |
| Corrupted / non-recipe .doughy file | ⚪ | Unit-testable: malformed JSON, wrong schema, empty file |
| "Shared by X" banner + collapse state | ⚪/❌ | UI-testable only if a shared recipe can be seeded via launch argument; otherwise manual |
| Share extension (Safari → Doughy) | ❌ | Extension UI runs out-of-process; keep manual (extension's parsing logic is shared, unit-covered) |

## Settings

| Case | Status | Notes |
|---|---|---|
| Temp / volume toggles | 🟡 | `SettingsTests` cover persistence + region fallback; UI toggle flow untested |
| Change conversion values/units → conversions follow | 🟡 | Store + resolver unit-tested; UI edit flow untested (`gramsPerCupField_*`, `unitMenu_*`) |
| Add ingredient to a section | ⚪ | UI gap (also the standing feature TODO) |
| New ingredient appears in chips / bake session | ⚪ | UI gap |
| Delete ingredient → no toggles, no chips | ⚪ | UI gap |
| Egg size default + egg weights | 🟡 | Resolver unit tests cover egg math; UI (`defaultEggSizePicker`, `eggGramsField_*`) untested |
| Fluid-ounce conversion shows g/fl oz in unit menu | 🟡 | Unit conversion covered; menu contents untested |
| Reset all to defaults (after changing everything) | ⚪ | Unit-testable on the stores + UI smoke via `resetAllConversionsButton` |
| Restore recently deleted / delete all / empty hint | ⚪ | `recentlyDeletedLink` exists; no tests |
| Backup & restore big library | 🟡 | `testLibraryBackupRoundTrips*` cover the document; Files-picker UI flow manual |
| Links at bottom work | ⚪ | Existence/hittable assert only (can't verify Safari) |
| iCloud sync across two devices | ❌ | Two-device; cloud-mirror store logic already unit-tested (`*RestoresFromCloudAfterReinstall`) |
| Region/locale drives units | 🟡 | `testVolumeSystemFallsBackToRegionDefaultWhenUnset`; full locale-format sweep manual or locale-injected unit tests |

## Bake Session

| Case | Status | Notes |
|---|---|---|
| Toggle ingredient amounts | ⚪ | UI gap |
| Tap amount to cycle units, fl oz in cycle | 🟡 | Conversion unit-tested; cycling UI untested |
| fl oz import converts via density | ✅ | `testFluidOuncesResolveAsVolumeNotMass` + scanner tests |
| Ingredient peek bar: tap to reveal | ✅ | `expandIngredients()` exercised by every calculator test |
| Peek bar drag physics (resist/dismiss) | ❌ | Gesture-physics assertions too flaky |
| Adjust: add preferment | ✅ | `AddPrefermentUITests` + `CalculatorOverridesTests` |
| Adjust: remove preferment | 🟡 | Unit-covered (`testApplyingPrefermentRemovedDropsExistingPreferment`); UI remove untested |
| Tweak doughs / ball weight / byPercent percentages | ✅ | `RecipeCalculatorUITests` |
| Tweak all weights in byWeight | 🟡 | Unit-covered; UI variant untested |
| Copy recipe → dismiss shows new recipe | ⚪ | `calculatorCopyButton` exists; no test |
| Edit → dismiss reflects changes | ✅ | `RecipeEditUITests` + `RecipeDataIntegrityUITests` |
| iPad: tweak + Set as Default + propagation | 🟡 | iPhone flow covered (`testSetAsDefaultFromCalculatorOverride`); needs an iPad destination run + multi-pane assert |

## History

All five cases ✅ — `RecipeHistoryUITests` covers notes, mixed list, restore (with
current-state-saved-first), delete, and the empty state.

## Siri, Shortcuts & Quick Actions

All ❌ — Siri and the Shortcuts app cannot be driven by XCUITest, and Home Screen quick
actions via Springboard automation are too fragile to keep green. Intent handler logic could
be unit-tested if refactored behind a testable seam (future work).

## Welcome

| Case | Status | Notes |
|---|---|---|
| First install shows welcome | ⚪ | Automatable with a launch argument that clears `lastOnboardingVersion` |
| Update over 1.0 shows What's New | 🟡 | Version bookkeeping unit-tested (`testLastOnboardingVersionRoundTrips`); UI variant needs a launch argument seeding an old version |

## Summary

| | Count (approx.) |
|---|---|
| Already automated (✅) | ~30 cases |
| Partially automated (🟡) | ~25 cases |
| Automatable gaps (⚪) | ~35 cases |
| Manual only (❌) | ~15 cases |

The manual-only core: anything crossing the app sandbox (share sheet delivery, AirDrop/Mail/
Messages, share extension, Files picker), two-device iCloud sync, camera/photo + live LLM
scanning, Siri/Shortcuts, and gesture physics. Everything else is reachable with the existing
accessibility-identifier + `UITestSupport` infrastructure or plain unit tests.

## Gap-closure work packages

1. **Unit-test gaps** (existing files only, no pbxproj changes):
   preferment weird-percentage/0g edge cases, corrupted `.doughy` handling, import-with-
   existing-name, scanner recipe-set title selection, reset-all-conversions store behavior.
2. **UI tests in existing files** (no pbxproj changes):
   creation edge cases (existing collection, duplicate names, chips, temps), instructions
   add/delete/whitespace, preview error paths, byWeight adjust tweaks, unit cycling,
   ingredient toggle, copy recipe, remove preferment.
3. **New UI test files** (single owner for `project.pbxproj` edits):
   `HomeScreenUITests`, `SettingsUITests` (conversions/recently deleted/links),
   `WelcomeUITests` (launch-argument seeded).
