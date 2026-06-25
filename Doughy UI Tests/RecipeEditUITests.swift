//
//  RecipeEditUITests.swift
//  Doughy UI Tests
//

import XCTest

final class RecipeEditUITests: DoughyUITestCase {

    func testEditRecipeNameAndSave() throws {
        app.editRecipe(named: "Neapolitan Pizza")

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.clearAndType("Neapolitan Pizza Updated", app: app)

        app.tapDetailsNext()
        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Neapolitan Pizza Updated"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Neapolitan Pizza"].exists)
    }

    func testEditRecipeWithPrefermentAndSave() throws {
        app.editRecipe(named: "Bagels With Poolish")

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.clearAndType("Bagels With Poolish Updated", app: app)

        app.tapDetailsNext()
        app.tapPrefermentNext()
        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Bagels With Poolish Updated"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Bagels With Poolish"].exists)
    }

    func testCancelWithoutChangesDismissesImmediately() throws {
        app.editRecipe(named: "New York Pizza")

        let cancelButton = app.buttons["detailsCancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // No discard confirmation should appear since nothing was changed.
        XCTAssertFalse(app.buttons["discardChangesButton"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["New York Pizza"].waitForExistence(timeout: 5))
    }

    func testCancelAfterEditPromptsDiscard() throws {
        app.editRecipe(named: "New York Pizza")

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.clearAndType("Edited But Not Saved", app: app)

        let cancelButton = app.buttons["detailsCancelButton"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        let discardButton = app.buttons["discardChangesButton"].firstMatch
        XCTAssertTrue(discardButton.waitForExistence(timeout: 5))

        // Dismissing the confirmation (equivalent to "Keep Editing") returns to
        // the form with the edit preserved.
        app.dismissDiscardConfirmation()
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "Edited But Not Saved")

        // "Discard" dismisses without saving the change.
        cancelButton.tap()
        XCTAssertTrue(discardButton.waitForExistence(timeout: 5))
        discardButton.tap()

        XCTAssertTrue(app.staticTexts["New York Pizza"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Edited But Not Saved"].exists)
    }
}
