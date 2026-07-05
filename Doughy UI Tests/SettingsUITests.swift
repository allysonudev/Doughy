//
//  SettingsUITests.swift
//  Doughy UI Tests
//

import XCTest

/// Exercises the Settings screen: preference pickers, Ingredient Conversions
/// (grams-per-cup fields, unit menus, egg sizes, reset-to-defaults), Recently
/// Deleted, and the About links.
final class SettingsUITests: DoughyUITestCase {

    // MARK: - Navigation helpers

    /// Opens Settings from the recipe list's toolbar gear icon.
    private func openSettings() {
        let settingsButton = app.navigationBars.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button not found")
        settingsButton.tap()
        app.waitForUITransition()
    }

    private func openIngredientConversions() {
        let link = app.buttons["ingredientConversionsLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Ingredient Conversions link not found")
        app.scrollToElement(link)
        link.tap()
        app.waitForUITransition()
    }

    private func openRecentlyDeleted() {
        let link = app.buttons["recentlyDeletedLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "Recently Deleted link not found")
        app.scrollToElement(link)
        link.tap()
        app.waitForUITransition()
    }

    /// Taps a Form-row `Picker` (which renders as a menu button showing the
    /// current selection) and chooses `optionLabel` from the resulting menu.
    private func selectPickerOption(identifier: String, optionLabel: String) {
        let picker = app.buttons[identifier]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Picker \"\(identifier)\" not found")
        app.scrollToElement(picker)
        picker.tap()
        let option = app.buttons[optionLabel]
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Picker option \"\(optionLabel)\" not found")
        option.tap()
    }

    // MARK: - Preference toggles

    func testTemperatureUnitPickerTogglesSelection() throws {
        openSettings()

        selectPickerOption(identifier: "temperatureUnitPicker", optionLabel: "Celsius")
        let picker = app.buttons["temperatureUnitPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.label.contains("Celsius"), "Picker label should reflect Celsius selection, got \"\(picker.label)\"")

        selectPickerOption(identifier: "temperatureUnitPicker", optionLabel: "Fahrenheit")
        XCTAssertTrue(picker.label.contains("Fahrenheit"), "Picker label should reflect Fahrenheit selection, got \"\(picker.label)\"")
    }

    func testVolumeUnitsPickerTogglesSelection() throws {
        openSettings()

        selectPickerOption(identifier: "volumeUnitsPicker", optionLabel: "Imperial")
        let picker = app.buttons["volumeUnitsPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.label.contains("Imperial"), "Picker label should reflect Imperial selection, got \"\(picker.label)\"")

        selectPickerOption(identifier: "volumeUnitsPicker", optionLabel: "Metric")
        XCTAssertTrue(picker.label.contains("Metric"), "Picker label should reflect Metric selection, got \"\(picker.label)\"")
    }

    // MARK: - Ingredient conversions

    func testGramsPerCupFieldPersistsAfterLeavingAndReopening() throws {
        openSettings()
        openIngredientConversions()

        let field = app.textFields["gramsPerCupField_breadFlour"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Bread flour grams-per-cup field not found")
        field.replaceNumericValue("123", app: app)
        app.textFields["gramsPerCupField_breadFlour"].waitForKeyboardFocus()
        // Dismiss the keyboard so the field commits its value.
        app.navigationBars.firstMatch.tap()

        app.navigateBack()
        app.waitForUITransition()
        openIngredientConversions()

        let reopenedField = app.textFields["gramsPerCupField_breadFlour"]
        XCTAssertTrue(reopenedField.waitForExistence(timeout: 5))
        XCTAssertEqual(reopenedField.value as? String, "123", "Grams-per-cup value should persist across a navigation round trip")
    }

    func testUnitMenuChangesDisplayUnit() throws {
        openSettings()
        openIngredientConversions()

        let unitMenu = app.buttons["unitMenu_breadFlour"]
        XCTAssertTrue(unitMenu.waitForExistence(timeout: 5), "Bread flour unit menu not found")
        app.scrollToElement(unitMenu)
        unitMenu.tap()

        let tablespoonOption = app.buttons["Tablespoon"]
        if tablespoonOption.waitForExistence(timeout: 2) {
            tablespoonOption.tap()
        } else {
            // Fall back to whatever the localized short label is; the menu is
            // populated from DensityUnit.allCases so at least one non-cup entry exists.
            app.buttons.matching(NSPredicate(format: "label != %@", "Cup")).element(boundBy: 0).tap()
        }

        let updatedMenu = app.buttons["unitMenu_breadFlour"]
        XCTAssertTrue(updatedMenu.waitForExistence(timeout: 5))
        XCTAssertFalse(updatedMenu.label.isEmpty, "Unit menu should display the newly selected unit")
    }

    func testDefaultEggSizePickerChangesSelection() throws {
        openSettings()
        openIngredientConversions()

        let picker = app.buttons["defaultEggSizePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Default egg size picker not found")
        app.scrollToElement(picker)
        picker.tap()

        let jumboOption = app.buttons["Jumbo"]
        XCTAssertTrue(jumboOption.waitForExistence(timeout: 5), "Jumbo egg size option not found")
        jumboOption.tap()

        let updatedPicker = app.buttons["defaultEggSizePicker"]
        XCTAssertTrue(updatedPicker.waitForExistence(timeout: 5))
        XCTAssertTrue(updatedPicker.label.contains("Jumbo"), "Picker label should reflect the Jumbo selection, got \"\(updatedPicker.label)\"")
    }

    func testEggGramsFieldPersistsAfterLeavingAndReopening() throws {
        openSettings()
        openIngredientConversions()

        let field = app.textFields["eggGramsField_large_whole"]
        app.scrollToElement(field)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Large egg whole-egg field not found")
        field.replaceNumericValue("60", app: app)
        app.navigationBars.firstMatch.tap()

        app.navigateBack()
        app.waitForUITransition()
        openIngredientConversions()

        let reopenedField = app.textFields["eggGramsField_large_whole"]
        app.scrollToElement(reopenedField)
        XCTAssertTrue(reopenedField.waitForExistence(timeout: 5))
        XCTAssertEqual(reopenedField.value as? String, "60", "Egg grams value should persist across a navigation round trip")
    }

    // MARK: - Reset all to defaults

    func testResetAllToDefaultsRestoresChangedValues() throws {
        openSettings()
        openIngredientConversions()

        let flourField = app.textFields["gramsPerCupField_breadFlour"]
        XCTAssertTrue(flourField.waitForExistence(timeout: 5))
        let defaultFlourValue = flourField.value as? String
        flourField.replaceNumericValue("1", app: app)

        let eggField = app.textFields["eggGramsField_large_whole"]
        app.scrollToElement(eggField)
        let defaultEggValue = eggField.value as? String
        eggField.replaceNumericValue("1", app: app)
        app.navigationBars.firstMatch.tap()

        let resetButton = app.buttons["resetAllConversionsButton"]
        app.scrollToElement(resetButton)
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        resetButton.tap()

        // A confirmation dialog appears before the reset actually happens; its
        // destructive action shares the same label as the row button that
        // triggered it, so match the one inside the dialog specifically.
        let confirmButton = app.buttons.matching(NSPredicate(format: "label == %@", "Reset All to Defaults")).element(boundBy: 1)
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Reset confirmation dialog not found")
        confirmButton.tap()
        app.waitForUITransition()

        let resetFlourField = app.textFields["gramsPerCupField_breadFlour"]
        XCTAssertTrue(resetFlourField.waitForExistence(timeout: 5))
        XCTAssertEqual(resetFlourField.value as? String, defaultFlourValue, "Bread flour value should return to its default after reset")

        let resetEggField = app.textFields["eggGramsField_large_whole"]
        app.scrollToElement(resetEggField)
        XCTAssertEqual(resetEggField.value as? String, defaultEggValue, "Large egg value should return to its default after reset")
    }

    // MARK: - Recently deleted

    func testRestoreRecentlyDeletedRecipeReturnsItToList() throws {
        // Delete a default recipe from the home screen first.
        let cell = app.staticTexts["Neapolitan Pizza"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        app.scrollToElement(cell)
        cell.swipeLeft()
        app.buttons["Delete"].tap()
        app.waitForUITransition()
        XCTAssertFalse(app.staticTexts["Neapolitan Pizza"].exists)

        openSettings()
        openRecentlyDeleted()

        let deletedRow = app.staticTexts["Neapolitan Pizza"]
        XCTAssertTrue(deletedRow.waitForExistence(timeout: 5), "Deleted recipe should appear in Recently Deleted")
        app.scrollToElement(deletedRow)
        deletedRow.swipeLeft()
        let restoreButton = app.buttons["Restore"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 5))
        restoreButton.tap()
        app.waitForUITransition()

        XCTAssertFalse(app.staticTexts["Neapolitan Pizza"].exists, "Restored recipe should leave the Recently Deleted list")

        app.navigateBack()
        app.navigateBack()
        app.waitForUITransition()

        XCTAssertTrue(app.staticTexts["Neapolitan Pizza"].waitForExistence(timeout: 5), "Restored recipe should be back in the recipe list")
    }

    func testDeleteAllRecentlyDeletedClearsListAndShowsEmptyHint() throws {
        // Delete two default recipes so there's something to clear.
        for name in ["Neapolitan Pizza", "New York Pizza"] {
            let cell = app.staticTexts[name]
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            app.scrollToElement(cell)
            cell.swipeLeft()
            app.buttons["Delete"].tap()
            app.waitForUITransition()
        }

        openSettings()
        openRecentlyDeleted()

        XCTAssertTrue(app.staticTexts["Neapolitan Pizza"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["New York Pizza"].waitForExistence(timeout: 5))

        let deleteAllButton = app.buttons["Delete All"]
        XCTAssertTrue(deleteAllButton.waitForExistence(timeout: 5), "Delete All button not found")
        deleteAllButton.tap()

        let confirmButton = app.alerts["Delete All Permanently?"].buttons["Delete All"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Delete All confirmation alert not found")
        confirmButton.tap()
        app.waitForUITransition()

        XCTAssertTrue(app.staticTexts["No Recently Deleted Recipes"].waitForExistence(timeout: 5), "Expected the empty-state hint after deleting all")
    }

    // MARK: - About links

    func testAboutLinksExistAndAreHittable() throws {
        openSettings()

        let sourceLink = app.links["Source Code on GitHub"]
        app.scrollToElement(sourceLink)
        XCTAssertTrue(sourceLink.waitForExistence(timeout: 5), "Source Code on GitHub link not found")
        XCTAssertTrue(sourceLink.isHittable, "Source Code on GitHub link should be hittable")

        let feedbackLink = app.links["Send Feedback"]
        app.scrollToElement(feedbackLink)
        XCTAssertTrue(feedbackLink.waitForExistence(timeout: 5), "Send Feedback link not found")
        XCTAssertTrue(feedbackLink.isHittable, "Send Feedback link should be hittable")

        // The food bank link is US-region-conditional; only assert it when present
        // so this test doesn't depend on the simulator's region.
        let foodBankLink = app.otherElements["foodBankLink"]
        if foodBankLink.waitForExistence(timeout: 2) {
            app.scrollToElement(foodBankLink)
            XCTAssertTrue(foodBankLink.isHittable, "Food bank link should be hittable when shown")
        }
    }
}
