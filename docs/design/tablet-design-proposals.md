# Doughy Tablet Design Proposals

Status: exploratory
Scope: iPad and Android tablets first. visionOS and Android XR are noted only where today's choices should avoid boxing them out.
Emerging direction: Proposal B for the tablet main screen, paired with Proposal C for create/edit as a dedicated Recipe Studio.

Companion mockups: [tablet-design-mockups.html](tablet-design-mockups.html)

## Why This Exists

Doughy's current phone experience is well suited to linear work: choose a recipe, tune the batch, calculate, then read the result. On tablets, that same flow leaves a lot of empty potential. The better tablet version should make Doughy feel like a kitchen workbench: the recipe library stays nearby, the calculator and result can be compared without losing context, and editing can happen alongside preview rather than inside a full-screen interruption.

The 1.1 release does not need this redesign. This branch is for shaping the follow-up.

## Current Product Shape

iOS is built around `RecipeListView` as a single `NavigationStack`. The list pushes into `CalculatorView`; calculation pushes into `CalculatedRecipeView`; create, edit, copy, share, import, onboarding, and what's-new flows use sheets or covers.

Android mirrors the same mental model with a Compose `NavHost`: recipes, create, import, settings, calculator, result, edit, copy, history, and conversions are separate destinations. The list already has more visual structure than iOS, with collection cards, avatars, undo, and an extended add button.

Both apps have the same core pressure points on tablet:

- The recipe library disappears once the user opens a recipe.
- Calculator inputs and calculated output are separate screens, even though tablet width could show them together.
- Create/edit is a long vertical wizard or form, even when there is room for preview, section navigation, or source material.
- Share/import/scan flows are modal, but tablets need more careful popover anchoring and fewer giant sheets.

## Design Principles

1. Keep the phone flow intact.
   Tablet work should be adaptive shell work first, not a forked product. Existing forms, rows, calculation logic, import/export, and recipe-file behavior should stay shared.

2. Preserve the baker's flow state.
   A user who has selected a recipe should keep visual access to it while changing batch size, checking history, or reading the result.

3. Favor panels over pages on large screens.
   Navigation should feel like moving focus across a workspace, not repeatedly entering and backing out of full-screen destinations.

4. Keep kitchen readability.
   Tablet layouts should allow larger touch targets, strong section headers, and readable calculated quantities at arm's length. Dense is fine; cramped is not.

5. Make platform conventions rhyme, not clone.
   iPad should use SwiftUI adaptive navigation patterns. Android tablets should use Material adaptive navigation and panes. The information architecture should match even if the widgets differ.

## Proposal A: Recipe Library Workbench

This is the safest and most likely first redesign.

### Layout

Use a three-region adaptive layout:

- Sidebar: collections and recipes.
- Detail: selected recipe calculator.
- Result/secondary pane: calculated output, history, or contextual preview.

On medium-width tablets, collapse to two regions:

- Sidebar.
- Detail, where calculator and result replace each other.

On phones, keep the existing push navigation.

### Behavior

The selected recipe remains highlighted in the sidebar. Tapping another recipe changes the detail pane without resetting the whole navigation stack. "Calculate" opens the result in the secondary pane when there is room, or pushes it on compact width. History can use the same secondary pane, letting the user compare previous batches with the current calculator.

Create and edit should open as a large sheet or a dedicated detail pane depending on context:

- New recipe from sidebar: detail pane becomes create flow.
- Edit current recipe: detail pane becomes edit flow and keeps the sidebar visible.
- Copy recipe: prefilled create flow in detail pane.

### iPad Implementation Notes

Introduce an adaptive root view around the existing list/detail screens:

- Compact: keep `NavigationStack(path:)` as-is.
- Regular: use `NavigationSplitView` with explicit selection state.
- Add a selected recipe model separate from the phone navigation path.
- Let `CalculatorView` expose its calculated result through state that the adaptive root can route into a secondary pane.

The current `.sheet(item:)` pattern should stay for payload-driven flows. On iPad, confirmation dialogs and popovers should be attached to the triggering control so anchors land correctly.

### Android Tablet Implementation Notes

Introduce an adaptive app shell around the existing Compose destinations:

- Compact: keep the current `NavHost`.
- Medium/expanded: use Material adaptive list-detail behavior, with recipe selection state lifted above `RecipeListScreen`.
- The list pane can reuse `RecipeListScreen` content after extracting the list body from its `Scaffold`.
- The detail pane can host `CalculatorScreen`.
- A supporting pane can host `CalculatedRecipeScreen`, `RecipeHistoryScreen`, or import/share review when width allows.

This should be a shell-level refactor, not a rewrite of calculator math or persistence.

### Pros

- Directly addresses the main tablet pain: losing the library when opening a recipe.
- Low conceptual risk because it preserves the current screens.
- Best bridge to future spatial platforms, where persistent panels will matter.

### Risks

- Requires untangling screen-level scaffolds from content on Android.
- iOS will need careful state routing so app intents, imports, and shortcuts land in the correct pane.
- Deep links and UI tests need updates because there may be selection state instead of only navigation path state.

## Proposal B: Bake Session Focus

This is more opinionated: the tablet opens around the current batch, not the recipe list.

### Layout

The main surface is a bake-session dashboard:

- Left rail: recipe/library switcher, settings, recent recipes.
- Main pane: active recipe view with quantity, single batch size, total batch size, a compact ingredients column, longer instructions, and session note.

The recipe list is a slide-in or secondary view rather than the permanent dominant object.

### Behavior

Opening the app from a dead state should restore the last active recipe and show it immediately. The default tablet state is the recipe/bake view, not a calculator form.

The app should remember the last-used batch settings for each repeat recipe, especially quantity and single batch size. When the user reopens that recipe, Doughy can jump straight to the familiar calculated recipe instead of asking them to re-enter routine values.

If the user wants to change the batch, they switch from Recipe to Adjust in the top mode control. The recipe view is replaced by the calculator/adjustment screen, they tweak the details, then return to the recipe view with updated calculated amounts. This keeps the counter-facing state calm and readable while preserving access to the full calculator. The default recipe pane should not need a separate summary pane; the essential calculated ingredients, instructions, and note entry all belong in the one recipe focus.

Because instructions are likely to be longer than the ingredient list, the recipe focus should give instructions the larger area. Ingredients should sit in a compact column that remains easy to glance at while the user reads later steps.

### Pros

- Best kitchen-counter experience.
- Makes "what do I need right now?" the central product promise.
- Naturally supports history notes and set-as-default after baking.

### Risks

- Larger redesign than Proposal A.
- The recipe library becomes less prominent.
- More custom layout work across iPad and Android tablet.

## Proposal C: Recipe Studio

This emphasizes creation, scanning, and editing.

This is not intended to replace the main screen. It is the tablet version of the create/edit flow: a better workspace for building, scanning, reviewing, and revising recipes once the user has chosen to create, edit, or copy.

### Layout

Use a two-pane or three-pane editor:

- Left: recipe structure and sections.
- Center: active editor fields.
- Right: live preview, scan source, conversion suggestions, or validation.

For scanned recipes, the source photo/text can remain visible while the user reviews alternatives and conversions.

### Behavior

The create/edit flow becomes less wizard-like on tablets. Steps remain available, but the user can jump between details, preferment, ingredients, instructions, and preview from a persistent section navigator.

Import should use this same studio flow when possible. Importing a `.doughy` file or scanned recipe should land in the Recipe Studio for review and confirmation rather than introducing a separate tablet-only import pattern.

### Pros

- Strong upgrade for the most complex flow in the app.
- Especially useful for recipe scanning and ingredient conversion review.
- Helps future desktop/spatial form factors.

### Risks

- Highest implementation cost.
- More opportunity for validation and focus bugs.
- Does less for the everyday "open recipe and calculate" path unless paired with Proposal A.

## Recommended Path

The strongest direction is Proposal B for the tablet main screen, paired with Proposal C for create/edit.

That gives Doughy two clear tablet modes:

- Bake Session: the everyday counter-friendly main screen for choosing a recipe, tuning a batch, reading calculated weights, and saving notes.
- Recipe Studio: the creation/editing workspace for scanning, building, reviewing, and refining a recipe without forcing everything through a tall phone-style wizard.

Proposal A remains useful as the conservative fallback and as a technical stepping stone, but it is less distinctive than the B + C combination.

Suggested phases:

1. Bake Session shell spike
   Build a branch-only prototype that keeps phone navigation untouched and adds the tablet session layout: navigation rail/library access, last-active recipe restoration, and a readable recipe focus pane.

2. Result and note workflow
   Let calculation output, instructions, history, and bake notes stay visible in the default recipe view. Save per-recipe batch settings so repeat recipes reopen with useful defaults.

3. Recipe Studio spike
   Recompose create/edit/import into section navigation, editor fields, and preview/source panes while keeping existing validation and recipe-building logic.

4. Visual polish
   Tune spacing, typography, selected states, empty states, and toolbar placement for arm's-length kitchen use.

5. Cross-platform parity review
   Compare iPad and Android tablet behavior side by side. Align information architecture, not every platform widget.

### Prototype Status

Initial iOS slice started in `RecipeListView.swift`:

- Phone navigation remains the existing `NavigationStack`.
- Regular-width iPad uses a tablet shell with a navigation rail, optional recipe library, and a Bake Session focus.
- The last active recipe is restored from app launch when possible.
- Quantity and single batch size are persisted per recipe.
- Recipe mode shows batch metrics, a compact pinned ingredients column, longer scrollable instructions, and session notes.
- Adjust mode currently edits only the batch-level quantity and single batch size.

Still to do:

- Add full ingredient/preferment adjustment controls to tablet Adjust mode.
- Move create/edit/import into Recipe Studio.
- Bring the adaptive shell to Android tablets.
- Add UI-test coverage for last-active recipe restore and batch-setting persistence.

## Resolved Decisions

- The tablet home should restore the last active recipe from a dead app launch.
- The default Bake Session surface should use one recipe focus pane with quantity, single batch size, total batch size, a compact ingredients column, longer instructions, and notes. Adjustment should be an explicit top-level mode that temporarily replaces the recipe view with the calculator, then returns to the readable recipe state.
- Doughy should remember per-recipe batch defaults, especially last-entered quantity and single batch size, to reduce friction for repeat recipes.
- Import should use the Recipe Studio flow when possible, matching edit/review instead of becoming a separate tablet pattern.
- Tablets should use a navigation rail for library, create/import, settings, and other high-level destinations.
- The exact width thresholds for showing or collapsing panes can be chosen during implementation. The guiding rule is to preserve readability first, especially on iPad mini landscape and smaller Android tablets.

## Future Spatial Notes

Do not design visionOS or Android XR now. Still, Proposal A keeps the right doors open:

- Persistent library, calculator, and result panes can become separate windows or ornaments later.
- The calculated result can become a large readable surface without changing calculation logic.
- Create/edit source material can become a separate reference surface.

Avoid hard-coding tablet-only assumptions into domain logic. Keep adaptive behavior at the presentation shell and view-composition layers.
