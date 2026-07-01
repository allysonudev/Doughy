//
//  AddPrefermentUITests.swift
//  Doughy UI Tests
//

import XCTest

/// Exercises the Adjust tab's Add/Remove Preferment tool end to end against a
/// recipe with flour, water, salt, and yeast (defaultWeight 1000g):
///
///   Bread Flour: 100%, Water: 70%, Salt: 2%, Instant Yeast: 1%
final class AddPrefermentUITests: DoughyUITestCase {

    private let recipeName = "Preferment Tool Test Loaf"

    private func createTestRecipe() {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        app.fillDetails(name: recipeName, newCollection: "Preferment Tool Tests", defaultWeight: "1000")

        app.fillFlour(at: 0, name: "Bread Flour", value: "100")

        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Salt", value: "2")
        app.addIngredient()
        app.fillIngredient(at: 2, name: "Instant Yeast", value: "1")

        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts[recipeName].waitForExistence(timeout: 5))
    }

    func testAddingPoolishPresetShowsPrefermentPanelWithRemoveOption() {
        createTestRecipe()
        app.openCalculator(for: recipeName)
        app.showAdjustMode()

        let addButton = app.buttons["addPrefermentButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add Preferment button not found")
        addButton.tap()

        let nameField = app.textFields["addPrefermentNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Add preferment name field not found")
        nameField.tap()

        let poolishChip = app.buttons["Poolish"].firstMatch
        XCTAssertTrue(poolishChip.waitForExistence(timeout: 5), "Poolish suggestion chip not found")
        poolishChip.tap()

        let confirmButton = app.buttons["addPrefermentConfirmButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Add preferment confirm button not found")
        XCTAssertTrue(confirmButton.isEnabled, "Add button should be enabled once the Poolish preset is applied")
        confirmButton.tap()

        XCTAssertTrue(app.staticTexts["Preferment: Poolish"].waitForExistence(timeout: 5), "Preferment panel title not found after adding")

        let removeButton = app.buttons["removePrefermentButton"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5), "Remove preferment button not found")

        removeButton.tap()
        let removeConfirm = app.alerts.buttons["Remove"]
        XCTAssertTrue(removeConfirm.waitForExistence(timeout: 5), "Remove confirmation alert not found")
        removeConfirm.tap()

        XCTAssertTrue(app.buttons["addPrefermentButton"].waitForExistence(timeout: 5), "Add Preferment button should return after removing the preferment")
        XCTAssertFalse(app.staticTexts["Preferment: Poolish"].exists, "Preferment panel should be gone after removing")
    }
}
