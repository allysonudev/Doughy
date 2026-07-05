
# Test Cases

## Manual Testing Required

Top priority for hand testing. Two tiers: cases that can never be automated, and cases
that could be but aren't yet. Everything below this section has automated coverage (unit
and/or UI); see [AutomationCoverage.md](AutomationCoverage.md) for the case-by-case mapping.

### Cannot be automated

#### Recipe scanner (end-to-end with real photos + LLM)
- Import single image with just ingredients
  - Try photo version from book
- Import single image with ingredients and leaks of instructions
  - Try photo version from book
- Import entire set of recipe images from a website
  - Try photo version from book
- Recipe set should choose correct title (title selection is inlined in the live-LLM
  pipeline; needs a small refactor to become unit-testable)

#### Import recipe link
- NYT Cooking which might require subscription

#### Collection Appearance
- Pick a custom emoji via the emoji picker (system emoji keyboard isn't scriptable)

#### Sharing & Importing
- Confirm the share sheet lets you send the .doughy file via Messages/Mail/AirDrop/Save to Files
- Share from swipe / hold menu: actually complete a send (sheet presentation is automated)
- Open a shared .doughy file from AirDrop
- Open a shared .doughy file from a Mail attachment
- Open a shared .doughy file from Messages
- Open a shared .doughy file from the Files app
- Confirm the "Shared by X" banner and share note show up on the bake screen after import,
  and that it collapses/expands and remembers state
- Share Extension: from Safari (or another app), use the system share sheet to send a recipe
  website link directly into Doughy (not via in-app "Import from Link")
- Share Extension: share a non-recipe URL and confirm a helpful error/cancel path
- Share Extension: cancel out of the share extension before it opens the app

#### Settings
- Backup and restore a big library and verify everything is back (Files picker flow;
  the backup document round-trip itself is unit-tested)
- iCloud sync: change settings/ingredient conversions/collection appearance/deleted recipes
  on one device and confirm they sync to a second device signed into the same iCloud account
- Change the device region/locale and confirm temperature and weight units/number formatting
  follow the region automatically, not just the manual toggle

#### Bake Session
- Ingredient peek bar gesture physics: swipe around — ingredients should behave the same as
  normal; drag up is resisted, drag down resets close to normal or dismisses halfway down;
  tap away dismisses (tap-to-reveal is automated)
- (iPad) Tweak a session, tap "Set as Default", and verify *other open views/panes* reflect
  the new default (the flow itself is automated on iPhone)

#### Siri, Shortcuts & Quick Actions
- Siri: "Scan recipe in Doughy" with a recipe photo.
- Siri: "Share [recipe] in Doughy" with and without specifying a recipient.
- Siri: "Open [recipe] in Doughy".
- Build a Shortcuts app automation chaining Scan/Share/Open Recipe actions.
- Long-press the app icon on the Home Screen and use the Scan Recipe quick action.
- Long-press the app icon and use the Open Recipe quick action (from a recently opened recipe).

#### Welcome
- Real upgrade install: put a 1.0 build on device, update on top of it, and confirm the
  What's New screen and data migration (the screen logic is automated via launch flags;
  Core Data migration is unit-tested)

### Not yet automated (test by hand until covered)

#### Creating recipes
- Short name (trivial UI variant, never written)
- Move instructions around (drag-to-reorder in XCUITest is flaky; skipped deliberately)

#### Collection Appearance
- Pick a built-in icon for a new collection
- Pick a color
- Leave icon/color unset and confirm it falls back to a first-letter avatar with a
  name-derived color
- Edit the appearance on an existing collection and confirm it updates everywhere
  (Home Screen list, share/import previews) — store/export round-trips are unit-tested,
  the UI propagation is not

#### Settings — ingredient conversions
- Add an ingredient to a section (feature TODO)
- Test a new ingredient showing up in suggestion chip
- Test a new ingredient showing up in bake session and toggle
- Delete an ingredient and: toggles no longer happen; no longer in suggestion chips
- Add a conversion measured in fluid ounces and confirm the g/fl oz unit shows in the
  unit menu (depends on add-ingredient)

#### Bake Session
- Toggle ingredient amounts

## Creating recipes
### By Percentage
- New collection
- Existing collection
- Existing name
- With/Without preferment
- Single flour/multiple flours
- Duplicate ingredient names
- Use/Don't use suggestion chips
- With temps

### By Weight
- New collection
- Existing collection
- Existing name
- With/Without preferment
- Single flour/multiple flours
- Duplicate ingredient names
- Use/Don't use suggestion chips
- With temps
- Add known ingredient as volume to get hint to convert to weight
- Add unknown ingredients as volume and get no hint
- Add egg/eggs/whites/yolks as count to get hint to weight
- Add an extra ingredient measured in fluid ounces (imperial volume setting) and confirm it converts/displays correctly
### Preferment
- No matching ingredients in main dough
- All matches
- Try weird percentages that don't add up
- Try including matching ingredients in main dough with 0g weight.
### Import recipe link
- King arthur to clean branding
- Youtuber recipe sites
- Sallysbakingaddiction.com
- Run through the sites found in unit tests
- Mess with the ingredient names/amounts
- Test a preferment recipe like poolish baguette
### Recipe scanner (parser/resolver level)
- Including weird ingredients to get hint about volume to weight
- Including known ingredients in volume to auto-convert to weight
- Ingredients which need cleanup

### Instructions
- Add/delete instructions
- Instructions with just spaces

### Preview
- Updates when you go back and change things.
- Save recipe with the same name as existing one gives error.
- Save recipe with duplicate ingredients.

## Home Screen
Delete recipe
Delete last recipe in a collection
Delete last recipe in library.
Edit recipe from swipe
Share recipe from swipe (sheet presentation)
Delete recipe from hold menu
Edit recipe from hold menu
Share recipe from hold menu (sheet presentation)

## Sharing & Importing Recipes
### Sending
- Share a recipe with a "From" name filled in
- Share a recipe with the "From" name left blank
- Share a recipe with a personal note
- Share a recipe with no note

### Receiving a .doughy file
- Import when the recipe/collection name already exists locally
- Try opening a corrupted or non-recipe .doughy file

## Settings
- Temp toggles
- Volume toggles
- Ingredient conversions
  - change values for ingredients and test volume to weight conversions
  - Change units and test volume to weight conversions
  - Test changing default egg size and add an egg to see it converts correctly.
  - Change egg weights and create new recipe.
  - Reset all to defaults returns every single item to where it should be. Test by changing everything to 1.
- Restore a recently deleted recipe
- Delete all deleted recipes
  - Check that empty list hint is helpful.
- Links at bottom should work.

## Bake Session
- Tap a liquid ingredient's amount to cycle units and confirm fluid ounces appears in the cycle (imperial volume setting).
- Scan or link-import a recipe with fluid ounce amounts (e.g. 8 fl oz milk) and confirm it converts through density, not mass ounces.
- Scroll down to see ingredient bar
  - Tap ingredient bar to reveal
- Adjust screen
  - Add/Remove a preferment
  - Tweak number of doughs
  - Tweak weight of dough ball
  - Tweak all percentages in byPerc
  - Tweak all weights in byWeight
- Copy a recipe and confirm that on dismiss, it shows the new recipe.
- Edit a recipe and confirm that on dismiss, the changed ingredients, numbers, title, weight, and instructions are updated.
- Tweak a session (percentages/weights/preferment/doughs), tap "Set as Default", confirm the confirmation dialog, and verify the recipe list reflects the new default afterward.

### History
- Add a note during a bake session and confirm it shows up in History.
- History list shows both notes and saved versions.
- Restore an old version and confirm the current state is saved to history first.
- Delete a history entry.
- Empty state hint shows before any edits/notes exist.

## Welcome
- Install app for the first time to confirm welcome screen is shown
- Install update on top of 1.0 to confirm whats new screen is shown.
