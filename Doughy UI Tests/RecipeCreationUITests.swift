//
//  RecipeCreationUITests.swift
//  Doughy UI Tests
//

import XCTest

final class RecipeCreationUITests: DoughyUITestCase {

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
}
