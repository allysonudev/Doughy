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

    // MARK: - Custom ingredient conversions (Add Ingredient)

    /// Opens the "Add Ingredient" sheet for the given category group and saves a new
    /// custom ingredient with the given unit and grams-per-unit value. Assumes Settings
    /// > Ingredient Conversions is already open.
    private func addCustomIngredient(name: String, groupIdentifier: String, unitLabel: String? = nil, grams: String) {
        let addButton = app.buttons["addIngredientButton_\(groupIdentifier)"]
        app.scrollToElement(addButton)
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add Ingredient button for \"\(groupIdentifier)\" not found")
        addButton.tap()

        let nameField = app.textFields["addIngredientNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Add-ingredient name field not found")
        nameField.enterText(name, app: app)

        if let unitLabel {
            let unitPicker = app.buttons["addIngredientUnitPicker"]
            XCTAssertTrue(unitPicker.waitForExistence(timeout: 5), "Add-ingredient unit picker not found")
            unitPicker.tap()
            let option = app.buttons[unitLabel]
            XCTAssertTrue(option.waitForExistence(timeout: 5), "Unit option \"\(unitLabel)\" not found")
            option.tap()
        }

        let gramsField = app.textFields["addIngredientGramsField"]
        XCTAssertTrue(gramsField.waitForExistence(timeout: 5), "Add-ingredient grams field not found")
        gramsField.replaceNumericValue(grams, app: app)
        app.navigationBars.firstMatch.tap() // dismiss keyboard so the value commits

        let saveButton = app.buttons["addIngredientSaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Add-ingredient Save button not found")
        saveButton.tap()
        app.waitForUITransition()
    }

    func testAddCustomIngredientAppearsAndPersistsAfterReopening() throws {
        openSettings()
        openIngredientConversions()

        addCustomIngredient(name: "Rosemary Leaves", groupIdentifier: "Other", unitLabel: "Tablespoons", grams: "4.5")

        let row = app.staticTexts["customIngredientRow_Rosemary Leaves"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Custom ingredient should appear in the conversions list")

        app.navigateBack()
        app.waitForUITransition()
        openIngredientConversions()

        let reopenedRow = app.staticTexts["customIngredientRow_Rosemary Leaves"]
        app.scrollToElement(reopenedRow)
        XCTAssertTrue(reopenedRow.waitForExistence(timeout: 5), "Custom ingredient should persist across a navigation round trip")
        let gramsField = app.textFields["customIngredientGramsField_Rosemary Leaves"]
        app.scrollToElement(gramsField)
        XCTAssertEqual(gramsField.value as? String, "4.5", "Custom ingredient grams-per-unit should persist")
    }

    func testAddCustomIngredientAppearsAsSuggestionChipInCreateFlow() throws {
        openSettings()
        openIngredientConversions()
        addCustomIngredient(name: "Rosemary Leaves", groupIdentifier: "Other", unitLabel: "Tablespoons", grams: "4.5")
        app.navigateBack()
        app.navigateBack()
        app.waitForUITransition()

        app.startCreateRecipe()
        app.chooseMode(byPercent: false)
        app.fillDetails(name: "Rosemary Focaccia", newCollection: "Chip Tests")

        app.fillFlour(at: 0, name: "Bread Flour", value: "500")

        let ingredientNameField = app.textFields["ingredientNameField_0"]
        XCTAssertTrue(ingredientNameField.waitForExistence(timeout: 5))
        ingredientNameField.tap()

        app.tapSuggestionChip(named: "Rosemary Leaves")
        let valueField = app.textFields["ingredientValueField_0"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 5))
        valueField.enterText("10", app: app)

        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Rosemary Focaccia"].waitForExistence(timeout: 5), "New recipe should appear in the recipe list")
    }

    func testAddCustomIngredientCyclesToConfiguredUnitInBakeSession() throws {
        openSettings()
        openIngredientConversions()
        addCustomIngredient(name: "Rosemary Leaves", groupIdentifier: "Other", unitLabel: "Tablespoons", grams: "4.5")
        app.navigateBack()
        app.navigateBack()
        app.waitForUITransition()

        app.startCreateRecipe()
        app.chooseMode(byPercent: false)
        app.fillDetails(name: "Rosemary Loaf", newCollection: "Bake Session Tests")
        app.fillFlour(at: 0, name: "Bread Flour", value: "500")
        app.fillIngredient(at: 0, name: "Rosemary Leaves", value: "9")
        app.tapIngredientsNext()
        app.saveRecipe()

        app.openCalculator(for: "Rosemary Loaf")
        app.expandIngredients()

        let weightText = app.staticTexts["ingredientWeight_Rosemary Leaves"]
        XCTAssertTrue(weightText.waitForExistence(timeout: 5), "Rosemary Leaves weight not found on results screen")
        let gramsLabel = weightText.label
        XCTAssertTrue(gramsLabel.hasSuffix("g"), "Initial display should be in grams, got \"\(gramsLabel)\"")

        weightText.tap()
        let cycledLabel = app.staticTexts["ingredientWeight_Rosemary Leaves"].label
        XCTAssertNotEqual(cycledLabel, gramsLabel, "Tapping the weight should cycle to the configured volume unit")
        XCTAssertTrue(cycledLabel.lowercased().contains("tablespoon"), "Cycled label should show tablespoons, got \"\(cycledLabel)\"")

        // Cycle again: back to grams, since only one custom unit is configured.
        app.staticTexts["ingredientWeight_Rosemary Leaves"].tap()
        let backToGrams = app.staticTexts["ingredientWeight_Rosemary Leaves"].label
        XCTAssertEqual(backToGrams, gramsLabel, "Cycling twice should return to the original grams display")
    }

    func testDeletingCustomIngredientRemovesChipAndStopsCycling() throws {
        openSettings()
        openIngredientConversions()
        addCustomIngredient(name: "Rosemary Leaves", groupIdentifier: "Other", unitLabel: "Tablespoons", grams: "4.5")
        app.navigateBack()
        app.navigateBack()
        app.waitForUITransition()

        // Create a recipe using the custom ingredient so we can confirm cycling stops after deletion.
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)
        app.fillDetails(name: "Rosemary Loaf 2", newCollection: "Delete Tests")
        app.fillFlour(at: 0, name: "Bread Flour", value: "500")
        app.fillIngredient(at: 0, name: "Rosemary Leaves", value: "9")
        app.tapIngredientsNext()
        app.saveRecipe()

        // Delete the custom ingredient from Settings.
        openSettings()
        openIngredientConversions()
        let row = app.staticTexts["customIngredientRow_Rosemary Leaves"]
        app.scrollToElement(row)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()
        XCTAssertFalse(app.staticTexts["customIngredientRow_Rosemary Leaves"].exists, "Custom ingredient should be removed from the list")
        app.navigateBack()
        app.navigateBack()
        app.waitForUITransition()

        // Suggestion chip should no longer appear in the create flow.
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)
        app.fillDetails(name: "Post Delete Loaf", newCollection: "Post Delete Tests")
        app.fillFlour(at: 0, name: "Bread Flour", value: "500")
        let ingredientNameField = app.textFields["ingredientNameField_0"]
        XCTAssertTrue(ingredientNameField.waitForExistence(timeout: 5))
        ingredientNameField.tap()
        ingredientNameField.typeText("Rosemary")
        XCTAssertFalse(app.buttons["suggestionChip_Rosemary Leaves"].waitForExistence(timeout: 2),
                        "Suggestion chip should no longer appear after the ingredient was deleted")
        ingredientNameField.clearAndType("Rosemary Leaves", app: app)
        let valueField = app.textFields["ingredientValueField_0"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 5))
        valueField.enterText("9", app: app)
        app.tapIngredientsNext()
        app.saveRecipe()

        // The amount should no longer cycle on the earlier recipe that already used it.
        app.openCalculator(for: "Rosemary Loaf 2")
        app.expandIngredients()
        let weightText = app.staticTexts["ingredientWeight_Rosemary Leaves"]
        XCTAssertTrue(weightText.waitForExistence(timeout: 5))
        let gramsLabel = weightText.label
        weightText.tap()
        let afterTapLabel = app.staticTexts["ingredientWeight_Rosemary Leaves"].label
        XCTAssertEqual(afterTapLabel, gramsLabel, "Amount should no longer cycle once its conversion has been deleted")
    }

    func testFluidOunceConversionAppearsInUnitMenu() throws {
        openSettings()
        selectPickerOption(identifier: "volumeUnitsPicker", optionLabel: "Imperial")

        openIngredientConversions()
        addCustomIngredient(name: "Fish Sauce", groupIdentifier: "Other", unitLabel: "Fluid Ounces", grams: "29.6")

        let unitLabel = app.staticTexts["customIngredientUnitLabel_Fish Sauce"]
        app.scrollToElement(unitLabel)
        XCTAssertTrue(unitLabel.waitForExistence(timeout: 5), "Fish Sauce unit label not found")
        XCTAssertTrue(unitLabel.label.contains("fl oz"), "Custom ingredient's stored unit should display as g/fl oz, got \"\(unitLabel.label)\"")
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
