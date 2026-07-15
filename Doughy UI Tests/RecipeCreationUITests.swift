//
//  RecipeCreationUITests.swift
//  Doughy UI Tests
//

import XCTest

final class RecipeCreationUITests: DoughyUITestCase {

    // MARK: - Volume to Weight Conversion

    func testVolumeIngredientShowsWeightConversionOption() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        app.fillDetails(name: "Conversion Sourdough", newCollection: "Conversion Tests", defaultWeight: "1000")

        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")

        // Add an extra (volume) ingredient: 1 cup water.
        let addButton = app.buttons["addIngredientButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        app.scrollToElement(addButton)
        addButton.tap()

        let volumeButton = app.buttons["Volume"]
        XCTAssertTrue(volumeButton.waitForExistence(timeout: 5), "Volume option not found")
        volumeButton.tap()

        let extraNameField = app.textFields["extraIngredientNameField_0"]
        XCTAssertTrue(extraNameField.waitForExistence(timeout: 5), "Extra ingredient name field not found")
        extraNameField.enterText("Water", app: app)

        let extraAmountField = app.textFields["extraIngredientAmountField_0"]
        XCTAssertTrue(extraAmountField.waitForExistence(timeout: 5), "Extra ingredient amount field not found")
        extraAmountField.replaceNumericValue("1", app: app)

        let unitMenu = app.buttons["extraIngredientUnitMenu_0"]
        XCTAssertTrue(unitMenu.waitForExistence(timeout: 5), "Extra ingredient unit menu not found")
        unitMenu.tap()
        let cupOption = app.buttons["cups"]
        XCTAssertTrue(cupOption.waitForExistence(timeout: 5), "Cups menu option not found")
        cupOption.tap()

        app.tapIngredientsNext()

        // The conversion sheet should appear, listing the candidate with its
        // suggested gram conversion and a toggle to opt in/out.
        let sheetTitle = app.navigationBars["Additional Ingredients"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "Conversion sheet should appear")
        XCTAssertTrue(app.staticTexts["Water"].waitForExistence(timeout: 5), "Candidate name should be shown")
        XCTAssertTrue(app.staticTexts["1 cup Water ≈ 236 g"].waitForExistence(timeout: 5),
                       "Candidate description should be shown")
        XCTAssertTrue(app.switches["Convert to weight"].waitForExistence(timeout: 5),
                       "Convert to weight toggle should be shown")

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        app.saveRecipe()

        let cell = app.staticTexts["Conversion Sourdough"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "New recipe should appear in the recipe list")
    }

    // MARK: - By Percent

    func testCreateRecipeByPercentNoPreferment() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        app.fillDetails(name: "Percent Sourdough", newCollection: "Percent Tests", defaultWeight: "1000")

        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.tapIngredientsNext()

        app.saveRecipe()

        let cell = app.staticTexts["Percent Sourdough"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "New recipe should appear in the recipe list")
    }

    func testCreateRecipeByPercentWithPreferment() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        app.fillDetails(name: "Percent Biga Loaf", newCollection: "Percent Preferment Tests",
                        defaultWeight: "1000", includePreferment: true)

        // Preferment: 50% of total flour, 100% of the preferment's own flour.
        app.fillPrefermentDetails(name: "Biga", flourPercent: "50")
        app.fillPrefermentFlour(at: 0, name: "Bread Flour", value: "100")
        app.tapPrefermentNext()

        // Main dough: the remaining 50% of flour, plus the rest of the water.
        app.fillFlour(at: 0, name: "Bread Flour", value: "50")
        app.fillIngredient(at: 0, name: "Water", value: "10")
        app.tapIngredientsNext()

        app.saveRecipe()

        let cell = app.staticTexts["Percent Biga Loaf"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "New recipe should appear in the recipe list")
    }

    func testCreateRecipeByPercentMultipleFloursAndIngredients() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        app.fillDetails(name: "Percent Multi-Flour Loaf", newCollection: "Percent Multi Tests", defaultWeight: "1000")

        app.fillFlour(at: 0, name: "Bread Flour", value: "80")
        app.addFlour()
        app.fillFlour(at: 1, name: "Whole Wheat Flour", value: "20")

        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Salt", value: "2")
        app.addIngredient()
        app.fillIngredient(at: 2, name: "Yeast", value: "1")
        app.addIngredient()
        app.fillIngredient(at: 3, name: "Olive Oil", value: "3")
        app.addIngredient()
        app.fillIngredient(at: 4, name: "Sugar", value: "2")

        app.tapIngredientsNext()
        app.saveRecipe()

        let cell = app.staticTexts["Percent Multi-Flour Loaf"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "New recipe should appear in the recipe list")
    }

    // MARK: - By Weight

    func testCreateRecipeByWeightNoPreferment() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)

        app.fillDetails(name: "Weight Sourdough", newCollection: "Weight Tests")

        app.fillFlour(at: 0, name: "Bread Flour", value: "500")
        app.fillIngredient(at: 0, name: "Water", value: "350")
        app.tapIngredientsNext()

        app.saveRecipe()

        let cell = app.staticTexts["Weight Sourdough"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "New recipe should appear in the recipe list")
    }

    func testCreateRecipeByWeightWithPreferment() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)

        app.fillDetails(name: "Weight Poolish Loaf", newCollection: "Weight Preferment Tests",
                        includePreferment: true)

        app.fillPrefermentDetails(name: "Poolish")
        app.fillPrefermentFlour(at: 0, name: "Bread Flour", value: "200")
        app.tapPrefermentNext()

        app.fillFlour(at: 0, name: "Bread Flour", value: "300")
        app.fillIngredient(at: 0, name: "Water", value: "350")
        app.tapIngredientsNext()

        app.saveRecipe()

        let cell = app.staticTexts["Weight Poolish Loaf"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "New recipe should appear in the recipe list")
    }

    func testCreateRecipeByWeightMultipleFloursAndIngredients() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)

        app.fillDetails(name: "Weight Multi-Flour Loaf", newCollection: "Weight Multi Tests")

        app.fillFlour(at: 0, name: "Bread Flour", value: "400")
        app.addFlour()
        app.fillFlour(at: 1, name: "Whole Wheat Flour", value: "100")

        app.fillIngredient(at: 0, name: "Water", value: "350")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Salt", value: "10")
        app.addIngredient()
        app.fillIngredient(at: 2, name: "Yeast", value: "5")
        app.addIngredient()
        app.fillIngredient(at: 3, name: "Olive Oil", value: "15")
        app.addIngredient()
        app.fillIngredient(at: 4, name: "Sugar", value: "10")

        app.tapIngredientsNext()
        app.saveRecipe()

        let cell = app.staticTexts["Weight Multi-Flour Loaf"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "New recipe should appear in the recipe list")
    }

    // MARK: - Cancel

    func testCancelFromModeSelectionDismissesWithoutConfirmation() throws {
        app.startCreateRecipe()

        let cancelButton = app.buttons["modeSelectionCancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // No discard confirmation should appear since nothing has been entered yet.
        XCTAssertFalse(app.buttons["discardChangesButton"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["addRecipeButton"].waitForExistence(timeout: 5))
    }

    func testCancelAfterEnteringDetailsPromptsDiscard() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.enterText("Unsaved Recipe", app: app)

        // Cancel only lives on the mode-selection page, so navigate back to it.
        // The entered name is preserved in view state across the pop.
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let cancelButton = app.buttons["modeSelectionCancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        let discardButton = app.buttons["discardChangesButton"].firstMatch
        XCTAssertTrue(discardButton.waitForExistence(timeout: 5), "Discard confirmation should appear after edits")

        // Dismissing the confirmation (equivalent to "Keep Editing") returns to
        // the mode-selection page; re-enter details to confirm the name was preserved.
        app.dismissDiscardConfirmation()
        app.chooseMode(byPercent: true)
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "Unsaved Recipe")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()
        XCTAssertTrue(discardButton.waitForExistence(timeout: 5))
        discardButton.tap()

        XCTAssertTrue(app.buttons["addRecipeButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Unsaved Recipe"].exists)
    }

    // MARK: - Existing collection

    /// Creates a recipe into a brand-new collection, then creates a second recipe
    /// choosing that same collection from `collectionPicker` (rather than creating
    /// another new one), and verifies both recipes appear in the home list.
    func testCreateRecipeIntoExistingCollection() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)
        app.fillDetails(name: "First In Collection", newCollection: "Shared Collection", defaultWeight: "1000")
        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.tapIngredientsNext()
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts["First In Collection"].waitForExistence(timeout: 5))

        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.enterText("Second In Collection", app: app)

        // Leave "New Collection" off and pick the existing collection from the picker.
        app.selectExistingCollection("Shared Collection")

        app.tapDetailsNext()
        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "65")
        app.tapIngredientsNext()
        app.saveRecipe()

        // Saving dismisses the create sheet back to the recipe list, where both
        // recipes in the shared collection should now be visible.
        XCTAssertTrue(app.staticTexts["Second In Collection"].waitForExistence(timeout: 5))
        let firstCell = app.staticTexts["First In Collection"]
        app.scrollUntilExists(firstCell)
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5), "First recipe should still be listed in the shared collection")
    }

    // MARK: - Duplicate name

    /// Saving a recipe whose name already exists in the same collection surfaces
    /// `RecipeWritingError.recipeExistsDuringWrite`'s message in a "Save Error" alert,
    /// and the create sheet stays open (the recipe is not saved a second time).
    func testSavingRecipeWithExistingNameShowsError() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)
        app.fillDetails(name: "Duplicate Name Loaf", newCollection: "Duplicate Name Tests", defaultWeight: "1000")
        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.tapIngredientsNext()
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts["Duplicate Name Loaf"].waitForExistence(timeout: 5))

        // Attempt to create a second recipe with the identical name in the same collection.
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.enterText("Duplicate Name Loaf", app: app)

        // Only one collection exists at this point ("Duplicate Name Tests"), and
        // `detailsFormContent`'s picker `.onAppear` auto-selects the first (only)
        // collection when none has been chosen yet, so no picker interaction is needed.
        app.tapDetailsNext()
        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.tapIngredientsNext()
        app.saveRecipe()

        let alert = app.alerts["Save Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "A Save Error alert should appear for a duplicate recipe name")
        XCTAssertTrue(alert.staticTexts["A recipe with that name already exists in this collection. Please choose a different name."].waitForExistence(timeout: 5),
                      "Save Error alert should explain the name conflict")
        alert.buttons["OK"].tap()

        // The create sheet should still be open on the preview step (save did not go through).
        XCTAssertTrue(app.buttons["saveRecipeButton"].waitForExistence(timeout: 5), "Create sheet should remain open after the error")
    }

    // MARK: - Duplicate ingredient names

    /// The app has no duplicate-ingredient validation anywhere in `RecipeBuilder`, so
    /// entering the same ingredient name twice is accepted: both rows appear on the
    /// preview screen and the recipe saves successfully with two separate ingredient
    /// entries under that name.
    func testCreateRecipeWithDuplicateIngredientNamesSavesBothEntries() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)
        app.fillDetails(name: "Duplicate Ingredient Loaf", newCollection: "Duplicate Ingredient Tests", defaultWeight: "1000")

        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "40")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Water", value: "30")

        app.tapIngredientsNext()

        // Preview should show two "Water" rows (LabeledContent iterates the raw list).
        let waterLabels = app.staticTexts.matching(NSPredicate(format: "label == %@", "Water"))
        XCTAssertEqual(waterLabels.count, 2, "Preview should list both duplicate-named ingredients")

        app.saveRecipe()
        XCTAssertTrue(app.staticTexts["Duplicate Ingredient Loaf"].waitForExistence(timeout: 5), "Recipe with duplicate ingredient names should still save")
    }

    // MARK: - Suggestion chips

    /// Tapping a suggestion chip fills the ingredient name field and advances focus to
    /// the value field (via `pendingValueRowID`); typed-only ingredients (no chip tap)
    /// work the same as before.
    func testSuggestionChipFillsIngredientNameAndTypedNameAlsoWorks() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)
        app.fillDetails(name: "Suggestion Chip Loaf", newCollection: "Suggestion Chip Tests", defaultWeight: "1000")

        // Flour name field is focused by default on appear; "Bread Flour" is a seeded
        // suggestion, so its chip should be visible without typing anything.
        app.tapSuggestionChip(named: "Bread Flour")
        let flourNameField = app.textFields["flourNameField_0"]
        XCTAssertTrue(flourNameField.waitForExistence(timeout: 5))
        XCTAssertEqual(flourNameField.value as? String, "Bread Flour", "Tapping the chip should fill the flour name")

        let flourValueField = app.textFields["flourValueField_0"]
        XCTAssertTrue(flourValueField.waitForExistence(timeout: 5))
        flourValueField.enterText("100", app: app)

        // First ingredient row: type a name that has no matching suggestion chip.
        app.fillIngredient(at: 0, name: "Zzzz Homemade Starter Water", value: "70")
        app.assertIngredient(at: 0, name: "Zzzz Homemade Starter Water", value: "70")

        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Suggestion Chip Loaf"].waitForExistence(timeout: 5))
    }

    // MARK: - Ingredient temperatures

    /// A temperature entered on an ingredient (`ingredientTempField_N`) survives to the
    /// preview screen and then to the calculator's results screen.
    func testIngredientTemperatureSurvivesToCalculator() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)
        app.fillDetails(name: "Temp Loaf", newCollection: "Temp Tests", defaultWeight: "1000")

        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")

        let tempField = app.textFields["ingredientTempField_0"]
        XCTAssertTrue(tempField.waitForExistence(timeout: 5), "Ingredient temperature field not found")
        tempField.enterText("90", app: app)

        app.tapIngredientsNext()

        // Preview doesn't render temperature directly on the ingredient LabeledContent,
        // but saving should carry it through without error.
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts["Temp Loaf"].waitForExistence(timeout: 5))

        app.openCalculator(for: "Temp Loaf")
        app.tapCalculate()
        app.expandIngredients()

        // The calculator results row shows the ingredient's temperature under its name
        // (see `finalDoughRow` in CalculatorView+RecipeMode.swift).
        let tempText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "90")).firstMatch
        XCTAssertTrue(tempText.waitForExistence(timeout: 5), "Water's temperature should be shown on the results screen")
    }

    // MARK: - Instructions

    /// Adds multiple instructions, deletes one, and confirms a whitespace-only
    /// instruction can't be added: `CreateRecipeView+StepsPreferment.swift`'s "Add Step"
    /// button is disabled whenever the trimmed text is empty, so entering only spaces
    /// never creates a new instruction row.
    func testInstructionsAddDeleteAndRejectWhitespaceOnly() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)
        app.fillDetails(name: "Instructions Loaf", newCollection: "Instructions Tests", defaultWeight: "1000")
        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.tapIngredientsNext()

        // Now on the preview/instructions step.
        let stepField = app.textFields["Step description"]
        XCTAssertTrue(stepField.waitForExistence(timeout: 5), "Step description field not found")
        let addStepButton = app.buttons["Add Step"]
        XCTAssertTrue(addStepButton.waitForExistence(timeout: 5))

        // Whitespace-only text should never enable "Add Step".
        stepField.enterText("   ", app: app)
        XCTAssertFalse(addStepButton.isEnabled, "Add Step should stay disabled for whitespace-only text")

        stepField.clearAndType("Mix flour and water", app: app)
        XCTAssertTrue(addStepButton.isEnabled)
        addStepButton.tap()
        XCTAssertTrue(app.staticTexts["1."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mix flour and water"].waitForExistence(timeout: 5))

        stepField.clearAndType("Rest for 30 minutes", app: app)
        addStepButton.tap()
        XCTAssertTrue(app.staticTexts["2."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rest for 30 minutes"].waitForExistence(timeout: 5))

        stepField.clearAndType("Bake at 450F", app: app)
        addStepButton.tap()
        XCTAssertTrue(app.staticTexts["3."].waitForExistence(timeout: 5))

        // Delete the middle instruction via its context menu.
        let middleStep = app.staticTexts["Rest for 30 minutes"]
        XCTAssertTrue(middleStep.waitForExistence(timeout: 5))
        middleStep.press(forDuration: 1.0)
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete option not found in instruction context menu")
        deleteButton.tap()

        XCTAssertFalse(app.staticTexts["Rest for 30 minutes"].exists, "Deleted instruction should be gone")
        XCTAssertTrue(app.staticTexts["Mix flour and water"].exists)
        XCTAssertTrue(app.staticTexts["Bake at 450F"].exists)

        app.saveRecipe()
        XCTAssertTrue(app.staticTexts["Instructions Loaf"].waitForExistence(timeout: 5))
    }

    /// `CreateRecipeView+StepsPreferment.swift`'s instruction rows expose a "Move to
    /// position…" context-menu action (`MoveStepSheet` in `CreateRecipeTypes.swift`) that
    /// reorders via numeric entry rather than a drag gesture. A real press-and-drag on
    /// SwiftUI's `onMove` reorder handles is flaky/undriveable in XCUITest, so this test
    /// exercises the app's actual (non-drag) reorder affordance instead and confirms the
    /// new order persists to the saved recipe's instructions.
    func testMoveInstructionToPositionReordersAndPersists() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)
        app.fillDetails(name: "Reorder Instructions Loaf", newCollection: "Reorder Instructions Tests", defaultWeight: "1000")
        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.tapIngredientsNext()

        let stepField = app.textFields["Step description"]
        XCTAssertTrue(stepField.waitForExistence(timeout: 5), "Step description field not found")
        let addStepButton = app.buttons["Add Step"]
        XCTAssertTrue(addStepButton.waitForExistence(timeout: 5))

        stepField.enterText("Mix flour and water", app: app)
        addStepButton.tap()
        XCTAssertTrue(app.staticTexts["Mix flour and water"].waitForExistence(timeout: 5))

        stepField.clearAndType("Rest for 30 minutes", app: app)
        addStepButton.tap()
        XCTAssertTrue(app.staticTexts["Rest for 30 minutes"].waitForExistence(timeout: 5))

        stepField.clearAndType("Bake at 450F", app: app)
        addStepButton.tap()
        XCTAssertTrue(app.staticTexts["Bake at 450F"].waitForExistence(timeout: 5))

        // Starting order: 1. Mix flour and water, 2. Rest for 30 minutes, 3. Bake at 450F.
        // Move the last step ("Bake at 450F") to position 1.
        app.moveInstruction(containing: "Bake at 450F", toPosition: 1)

        // New order should be: 1. Bake at 450F, 2. Mix flour and water, 3. Rest for 30 minutes.
        let firstNumber = app.staticTexts["1."]
        XCTAssertTrue(firstNumber.waitForExistence(timeout: 5))
        // Verify ordering via each row's position rather than relying on label text alone:
        // the numbered prefixes are reused across rows, so compare frame positions of the
        // instruction text elements themselves.
        let bakeText = app.staticTexts["Bake at 450F"]
        let mixText = app.staticTexts["Mix flour and water"]
        let restText = app.staticTexts["Rest for 30 minutes"]
        XCTAssertTrue(bakeText.waitForExistence(timeout: 5))
        XCTAssertTrue(mixText.waitForExistence(timeout: 5))
        XCTAssertTrue(restText.waitForExistence(timeout: 5))
        XCTAssertLessThan(bakeText.frame.minY, mixText.frame.minY, "Bake step should now be listed before Mix step")
        XCTAssertLessThan(mixText.frame.minY, restText.frame.minY, "Mix step should now be listed before Rest step")

        app.saveRecipe()
        XCTAssertTrue(app.staticTexts["Reorder Instructions Loaf"].waitForExistence(timeout: 5))

        // Re-enter edit mode and confirm the new order was actually persisted (not just
        // reflected transiently in view state before save).
        app.editRecipe(named: "Reorder Instructions Loaf")
        app.tapDetailsNext()
        app.tapIngredientsNext()

        let bakeTextAfterReopen = app.staticTexts["Bake at 450F"]
        let mixTextAfterReopen = app.staticTexts["Mix flour and water"]
        let restTextAfterReopen = app.staticTexts["Rest for 30 minutes"]
        XCTAssertTrue(bakeTextAfterReopen.waitForExistence(timeout: 5))
        XCTAssertTrue(mixTextAfterReopen.waitForExistence(timeout: 5))
        XCTAssertTrue(restTextAfterReopen.waitForExistence(timeout: 5))
        XCTAssertLessThan(bakeTextAfterReopen.frame.minY, mixTextAfterReopen.frame.minY, "Persisted order should still show Bake before Mix")
        XCTAssertLessThan(mixTextAfterReopen.frame.minY, restTextAfterReopen.frame.minY, "Persisted order should still show Mix before Rest")

        app.saveRecipe()
    }

    // MARK: - Short name

    /// `detailsReady` (`CreateRecipeView+StepsIngredients.swift`) only requires the trimmed
    /// recipe name to be non-empty - there's no minimum length - so a 1-character name should
    /// save and list normally like any other recipe.
    func testCreateRecipeWithShortNameSaves() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        app.fillDetails(name: "A", newCollection: "Short Name Tests", defaultWeight: "1000")

        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.tapIngredientsNext()

        app.saveRecipe()

        let cell = app.staticTexts["A"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Recipe with a 1-character name should save and appear in the recipe list")
    }
}
