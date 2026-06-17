# Doughy iOS and Android Feature Parity Comparison

Generated from static source review on 2026-06-17.

## Repos Reviewed

- iOS: `/Users/allyson/workspace/Doughy`
- Android: `/Users/allyson/workspace/Doughy-Android`

Both worktrees had existing uncommitted changes when this was reviewed, so this comparison reflects the current local files, not necessarily a released build.

## Executive Summary

The apps are broadly close on the core Doughy experience: recipe library, default recipes, calculator, preferments, create/edit flows, scanning, import/export, settings, history, and set-as-default all exist on both platforms.

The main parity gaps are not in the basic calculator. They are in platform-specific polish and a few workflow edges:

- iOS-only or stronger on iOS: SwiftUI document type integration and Apple App Intent entry points for scan/share.
- Android-only or stronger on Android: text share/process-text scanning, delete undo, Material You/dark theme, collection colors, and recipe icon selection.
- Both apps now persist true weight-mode recipes while preserving percentage-mode recipes and the shared `.doughy` JSON contract.
- Android now uses Room for private app storage. The `.doughy` sharing format remains the iOS-compatible JSON contract.

## Feature Matrix

| Area | Feature | iOS | Android | Parity Notes |
|---|---|---:|---:|---|
| Recipe library | Group recipes by collection | Yes | Yes | iOS uses list sections with persisted collapsed state. Android uses expandable section cards, default-collapses once the library is large. |
| Recipe library | Empty library state | Yes | Yes | Equivalent. |
| Recipe library | Create recipe entry point | Yes | Yes | iOS top-right plus. Android extended FAB. |
| Recipe library | Edit recipe from list | Yes | Yes | iOS trailing swipe. Android right-swipe. |
| Recipe library | Delete recipe from list | Yes | Yes | Android also has snackbar Undo. |
| Recipe library | Share recipe from list | Yes | Yes | iOS uses a leading swipe action. Android uses the row actions menu, also available by long-pressing a recipe row. |
| Recipe library | Copy recipe from list | Yes | Yes | Both open the create flow prefilled from the source recipe and save as a new recipe. iOS uses the long-press context menu; Android uses overflow/long-press row actions. |
| Recipe library | Collection collapse persistence | Yes | Yes | iOS persists collapsed collections in `UserDefaults`. Android persists explicit expanded/collapsed choices in `SharedPreferences`. |
| Defaults | Seed bundled recipes on first launch | Yes | Yes | Four default recipes are present on both: Neopolitan Pizza, New York Pizza, Bagels, Bagels With Poolish. |
| Defaults | Default recipe content parity | Yes | Yes | Android `DefaultRecipes.kt` says the iOS text/values are ported verbatim. |
| Calculator | Dough count scaling | Yes | Yes | Equivalent. |
| Calculator | Single dough weight override | Yes | Yes | Equivalent. |
| Calculator | Ingredient percentage overrides | Yes | Yes | Flour rows are read-only; non-flour percentage rows editable. |
| Calculator | Extra/additional ingredient amount overrides | Yes | Yes | Both support volume/count extras scaled separately. |
| Calculator | Ingredient temperature overrides | Yes | Yes | Both use the current preferred temperature unit. |
| Calculator | Preferment percentage overrides | Yes | Yes | Both support preferment flour share plus preferment ingredient percentage overrides. |
| Calculator | Calculation error handling for negative values | Yes | Yes | Equivalent user-facing alerts/dialogs. |
| Results | Preferment section | Yes | Yes | Equivalent. |
| Results | Final dough section | Yes | Yes | Equivalent, including preferment contribution split. |
| Results | Additional ingredients section | Yes | Yes | Equivalent concept. |
| Results | Instructions display | Yes | Yes | Equivalent. |
| Results | Tap/click ingredient weight to cycle volume units | Yes | Yes | iOS uses built-in density store plus user conversion entries. Android uses a density lookup passed into results; it cycles g/cup/tbsp/tsp/ml for known cup densities. |
| Results | Save note/history from result | Yes | Yes | Equivalent. |
| Results | Set calculator tweaks as default | Yes | Yes | Equivalent, with diff confirmation. |
| History | History screen from calculator | Yes | Yes | Equivalent. |
| History | Notes | Yes | Yes | Equivalent. |
| History | Version entries after edits/default updates | Yes | Yes | Equivalent concept. |
| History | Restore version | Yes | Yes | Equivalent. |
| History | Delete history entry | Yes | Yes | Equivalent. |
| Create/edit | Create by baker's percentage | Yes | Yes | Equivalent. |
| Create/edit | Create by weight | Yes | Yes | Equivalent. Weight-mode recipes keep per-ingredient gram values instead of only recalculating percentages. |
| Create/edit | Persist true weight-mode recipes | Yes | Yes | Both models store measurement mode and per-ingredient default weight values. Percentage recipes remain valid and default when the field is missing. |
| Create/edit | Edit existing recipes | Yes | Yes | Equivalent. Editing opens in the saved recipe mode. |
| Create/edit | Optional preferment | Yes | Yes | Equivalent. |
| Create/edit | Preferment entered separately from main dough | Yes | Yes | Equivalent. |
| Create/edit | Main-dough rows show totals with preferment | Yes | Yes | Equivalent idea. |
| Create/edit | Add/edit/delete flours and ingredients | Yes | Yes | Equivalent. |
| Create/edit | Add extra volume/count ingredients | Yes | Yes | Equivalent. |
| Create/edit | Add/edit/delete instructions | Yes | Yes | Equivalent. No reorder UI found in either current SwiftUI/Compose path. |
| Create/edit | Preview before save | Yes | Yes | Equivalent. |
| Create/edit | Discard unsaved changes confirmation | Yes | Yes | Equivalent. |
| Create/edit | Ingredient name suggestions from saved recipes | Yes | Yes | iOS shows focused-field suggestion chips ranked by saved recipes in the selected collection, with seeded/common names after. Android offers suggestions derived from saved recipe ingredients. |
| Create/edit | Recipe icons | No | Yes | Android can choose a Material icon or first-letter avatar. |
| Create/edit | Collection color customization | No | Yes | Android persists color per collection. |
| Create/edit | Name collision validation | Yes | Yes | Equivalent. |
| Scanning | Scan recipe from photo library | Yes | Yes | iOS uses PhotosPicker. Android uses Photo Picker. |
| Scanning | Scan recipe from camera | Yes | Yes | iOS has a `UIImagePickerController` camera path. Android uses `ActivityResultContracts.TakePicture` with a FileProvider cache URI, then runs the same OCR/scan pipeline. |
| Scanning | Scan image shared into app | Yes | Yes | iOS via App Intent notification path; Android via `ACTION_SEND image/*`. |
| Scanning | Scan selected/shared text | No | Yes | Android handles `ACTION_SEND text/plain` and `ACTION_PROCESS_TEXT`, skipping OCR. |
| Scanning | Shortcut/action to start scanning | Yes | Yes | iOS App Intent plus Home Screen quick action. Android static launcher/Assistant shortcut. |
| Scanning | On-device OCR | Yes | Yes | iOS Vision. Android ML Kit Text Recognition. |
| Scanning | On-device LLM parsing | Yes | Yes | iOS FoundationModels/Apple Intelligence. Android Gemini Nano via ML Kit GenAI, with debug fake parser fallback. |
| Scanning | Graceful disabled state when AI unavailable | Yes | Yes | Equivalent concept. |
| Scanning | Ingredient alternative prompt | Yes | Yes | Both prompt for "A or B" ingredient names. |
| Scanning | Unknown conversion prompt | Yes | Yes | Both let the user save a gram conversion or keep the original unit. |
| Scanning | Known conversion suggestions before preview | Yes | Yes | Both can convert known extra ingredients into weighted/percentage ingredients. |
| Scanning | Copy scan diagnostics | Yes | Yes | iOS appears always available after scans; Android gates diagnostics to debug builds. |
| Settings | Temperature unit setting | Yes | Yes | Equivalent. |
| Settings | Convert all stored recipe temperatures on unit change | Yes | Yes | Equivalent. |
| Settings | Ingredient conversion editor | Yes | Yes | Equivalent purpose. |
| Settings | Source code link | Yes | Yes | Links differ by repo: iOS still points to `georgie-codes/Doughy`; Android points to `allysonudev/Doughy-Android`. |
| Settings | Feedback email | Yes | Yes | Equivalent. |
| Settings | Food bank donation link | Yes | Yes | Equivalent. iOS uses `/find-your-local-foodbank`; Android uses the Feeding America root URL. |
| Settings | App version display | Yes | Yes | Equivalent. |
| Sharing/import | Export `.doughy` file | Yes | Yes | Equivalent JSON format intended. |
| Sharing/import | Optional author credit on share | Yes | Yes | Equivalent. |
| Sharing/import | Import `.doughy` file | Yes | Yes | Equivalent. |
| Sharing/import | Choose/enter destination collection on import | Yes | Yes | Equivalent. |
| Sharing/import | Save author as note on import | Yes | Yes | Equivalent. |
| Sharing/import | Native file type registration | Yes | Yes | iOS declares a UTI/document type. Android has `ACTION_VIEW` filters and a FileProvider. |
| Platform integration | OS-level per-recipe shortcut/open action | Yes | Yes | This refers to launcher/Siri/Assistant-style shortcuts, not in-app row long-press menus. Both apps keep the three most recently opened recipes in the app-icon long-press menu and reopen the recipe calculator from those shortcuts. iOS also exposes recipes as `RecipeAppEntity` values for `OpenRecipeIntent` and `ShareRecipeIntent`. |
| Platform integration | App-wide scan shortcut | Yes | Yes | iOS Home Screen quick action opens the create flow directly to scan source selection. Android static launcher shortcut opens the scan flow. |
| Platform integration | Dark mode/system dynamic color | System default | Yes | Android explicitly uses Material You dynamic color and dark theme. iOS uses SwiftUI system styling, so it should follow system colors where views use system components. |
| Platform integration | Edge-to-edge modern Android layout | N/A | Yes | Android calls `enableEdgeToEdge()`. |
| Persistence | Stored recipe database | Core Data | Room | Parity at the feature level; Android keeps `.doughy` JSON separate from its database schema. |
| Persistence | Settings store | UserDefaults | SharedPreferences/DataStore-like stores | Android uses SharedPreferences-backed stores in current code. |
| Tests | Domain/unit tests | Yes | Yes | Both have calculator/default/diff/scanner-related tests. |
| Tests | UI tests | Yes | Yes | iOS XCTest UI tests and Android Compose/instrumented tests exist. |
| Tests | Import/export tests | Yes | Yes | Both have current uncommitted edits in this area. |

## Highest-Value Parity Work

1. Pick a direction for scan entry parity.
   - Add iOS shared-text/process-text equivalent only if that workflow matters on Apple platforms.

2. Decide whether Android-only recipe icons and collection colors should come to iOS.
   - They are user-visible features, so they either need iOS equivalents or should be accepted as Android-specific platform polish.

3. Decide whether iOS should get delete undo.
   - Android has undo for recipe deletion; iOS deletes immediately from the row swipe.

4. Align settings links.
   - Source code and food bank URLs differ slightly.

## Evidence Files

iOS:

- `Doughy/Views/RecipeListView.swift`
- `Doughy/Views/CalculatorView.swift`
- `Doughy/Views/CalculatedRecipeView.swift`
- `Doughy/Views/CreateRecipeView.swift`
- `Doughy/Views/RecipeHistoryView.swift`
- `Doughy/Views/RecipeShareView.swift`
- `Doughy/Views/ImportRecipeView.swift`
- `Doughy/Views/SettingsView.swift`
- `Doughy/RecipeStore.swift`
- `Doughy/Utilities/RecipeScanner.swift`
- `Doughy/Utilities/ShareRecipeIntent.swift`
- `Doughy/Utilities/ScanRecipeIntent.swift`
- `Doughy/Model/Recipes/Recipe.swift`
- `Doughy/Model/Recipes/RecipeFile.swift`
- `Doughy/Utilities/DefaultRecipeFactory.swift`
- `Doughy/Info.plist`
- `Doughy/SceneDelegate.swift`

Android:

- `app/src/main/kotlin/app/doughy/ui/DoughyApp.kt`
- `app/src/main/kotlin/app/doughy/ui/recipelist/RecipeListScreen.kt`
- `app/src/main/kotlin/app/doughy/ui/calculator/CalculatorScreen.kt`
- `app/src/main/kotlin/app/doughy/ui/calculator/CalculatedRecipeScreen.kt`
- `app/src/main/kotlin/app/doughy/ui/create/CreateRecipeScreen.kt`
- `app/src/main/kotlin/app/doughy/ui/history/RecipeHistoryScreen.kt`
- `app/src/main/kotlin/app/doughy/ui/imports/ImportRecipeScreen.kt`
- `app/src/main/kotlin/app/doughy/ui/settings/SettingsScreen.kt`
- `app/src/main/kotlin/app/doughy/ui/settings/IngredientConversionsScreen.kt`
- `app/src/main/kotlin/app/doughy/scan/RecipeScanner.kt`
- `app/src/main/kotlin/app/doughy/scan/NanoRecipeParser.kt`
- `app/src/main/kotlin/app/doughy/SharedRecipeInput.kt`
- `app/src/main/kotlin/app/doughy/RecipeShortcuts.kt`
- `app/src/main/kotlin/app/doughy/data/RecipeStore.kt`
- `app/src/main/kotlin/app/doughy/data/RecipeFile.kt`
- `app/src/main/kotlin/app/doughy/data/RecipeShare.kt`
- `app/src/main/kotlin/app/doughy/data/CollectionColorStore.kt`
- `app/src/main/kotlin/app/doughy/ui/theme/Theme.kt`
- `app/src/main/kotlin/app/doughy/ui/theme/RecipeIcons.kt`
- `domain/src/main/kotlin/app/doughy/domain/Model.kt`
- `domain/src/main/kotlin/app/doughy/domain/DefaultRecipes.kt`
- `app/src/main/AndroidManifest.xml`
- `app/src/main/res/xml/shortcuts.xml`
