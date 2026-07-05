//
//  UITestSupport.swift
//  Doughy UI Tests
//

import XCTest

class DoughyUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
    }
}

extension String {
    /// Parses a formatted weight/percent label (e.g. "1,234.5g" or "66.67%")
    /// into its numeric value, stripping the unit suffix and grouping separators.
    var parsedNumericValue: Double? {
        let stripped = trimmingCharacters(in: CharacterSet(charactersIn: "g%"))
            .replacingOccurrences(of: ",", with: "")
        return Double(stripped)
    }
}

extension XCUIElement {
    /// Gives the keyboard/focus animation a brief chance to settle after a tap.
    /// Xcode 27's managed UI-test devices do not report `hasFocus` reliably, and
    /// polling it can fail with a stale app snapshot even when typing would work.
    func waitForKeyboardFocus(timeout: TimeInterval = 0.3) {
        RunLoop.current.run(until: Date().addingTimeInterval(timeout))
    }

    /// Taps the field, clears any existing text, then types `text`.
    func clearAndType(_ text: String, app: XCUIApplication) {
        app.scrollToElement(self)
        tap()
        waitForKeyboardFocus()
        if let stringValue = value as? String, !stringValue.isEmpty, stringValue != placeholderValue {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
            typeText(deleteString)
        }
        typeText(text)
    }

    /// Taps the field (scrolling it into view first) and types `text`.
    func enterText(_ text: String, app: XCUIApplication) {
        app.scrollToElement(self)
        tap()
        waitForKeyboardFocus()
        typeText(text)
    }

    /// Focuses the field, double-taps to select its entire current value (real
    /// or placeholder), and types `text` to replace the selection. Unlike
    /// `clearAndType`, this doesn't rely on cursor position or a backspace
    /// count - a single tap can leave the cursor *before* an existing value
    /// (e.g. a count field defaulting to "1"), so backspaces would be no-ops
    /// and `text` would be prepended instead of replacing it. Double-tapping a
    /// short numeric value selects it entirely, so the typed text replaces it
    /// regardless of where the cursor landed.
    func replaceNumericValue(_ text: String, app: XCUIApplication) {
        app.scrollToElement(self)
        tap()
        waitForKeyboardFocus()
        doubleTap()
        typeText(text)
    }
}

extension XCUIApplication {
    /// Scrolls the screen until `element` is hittable, or gives up after a few attempts.
    func scrollToElement(_ element: XCUIElement, maxSwipes: Int = 8) {
        var attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            swipeUp()
            attempts += 1
        }
    }

    /// Scrolls the screen until `element` exists in the accessibility tree (e.g. a List
    /// row that hasn't been instantiated yet because it's off-screen), or gives up.
    func scrollUntilExists(_ element: XCUIElement, maxSwipes: Int = 8) {
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            swipeUp()
            attempts += 1
        }
    }

    /// Gives SwiftUI navigation/presentation a short moment to settle before
    /// the next accessibility snapshot. Xcode 27 can otherwise throw kAXError
    /// while the managed UI-test device is between screens.
    func waitForUITransition(timeout: TimeInterval = 0.5) {
        RunLoop.current.run(until: Date().addingTimeInterval(timeout))
    }

    // MARK: - Recipe list

    func startCreateRecipe() {
        let addButton = buttons["addRecipeButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add recipe button not found")
        addButton.tap()
        waitForUITransition()
    }

    /// Swipes a recipe row left and taps "Edit".
    func editRecipe(named name: String) {
        let cell = staticTexts[name]
        scrollUntilExists(cell)
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Recipe \"\(name)\" not found in list")
        scrollToElement(cell)
        cell.swipeLeft()
        let editButton = buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit button not found")
        editButton.tap()
    }

    /// Taps a recipe row to open its calculator.
    func openCalculator(for name: String) {
        let cell = staticTexts[name]
        scrollUntilExists(cell)
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Recipe \"\(name)\" not found in list")
        scrollToElement(cell)
        cell.tap()
    }

    // MARK: - Calculator

    func showRecipeMode() {
        let button = buttons["recipeModeButton"]
        if button.waitForExistence(timeout: 2) {
            button.tap()
        } else {
            buttons["Recipe"].tap()
        }
    }

    func showAdjustMode() {
        let button = buttons["adjustModeButton"]
        if button.waitForExistence(timeout: 2) {
            button.tap()
        } else {
            buttons["Adjust"].tap()
        }
    }

    func setDoughCount(_ count: String) {
        showAdjustMode()
        let field = textFields["doughCountField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Dough count field not found")
        field.replaceNumericValue(count, app: self)
    }

    func setSingleDoughWeight(_ weight: String) {
        showAdjustMode()
        let field = textFields["singleDoughWeightField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Single dough weight field not found")
        field.replaceNumericValue(weight, app: self)
    }

    /// Enters the Adjust tab. Ingredient controls are now always visible there.
    func toggleAdjustIngredients() {
        showAdjustMode()
    }

    /// Sets the override percentage for the ingredient at `index` (its position
    /// in the recipe's ingredient list). Only non-flour ingredients have an
    /// editable percent field.
    func setIngredientPercent(at index: Int, value: String) {
        showAdjustMode()
        let field = textFields["ingredientPercentField_\(index)"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Ingredient percent field \(index) not found")
        scrollToElement(field)
        field.replaceNumericValue(value, app: self)
    }

    /// Sets the override weight for the ingredient at `index` (its position in the
    /// recipe's ingredient list). Only present for by-weight recipes in Adjust mode.
    func setIngredientWeight(at index: Int, value: String) {
        showAdjustMode()
        let field = textFields["ingredientWeightField_\(index)"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Ingredient weight field \(index) not found")
        scrollToElement(field)
        field.replaceNumericValue(value, app: self)
    }

    /// Taps the results-screen weight/percent label for the named ingredient to cycle
    /// its displayed unit (grams -> primary volume unit -> ... -> grams). Only works
    /// for ingredients with a known density/volume conversion.
    func cycleIngredientUnit(name: String) {
        expandIngredients()
        let weightText = staticTexts["ingredientWeight_\(name)"]
        XCTAssertTrue(weightText.waitForExistence(timeout: 5), "Calculated weight for \(name) not found")
        weightText.tap()
    }

    func tapCalculate() {
        showRecipeMode()
    }

    /// Ingredients live in a collapsible "peek" sheet on the results screen; the rows aren't in the
    /// accessibility tree until it's raised. Expands it (idempotently) before reading any ingredient
    /// data. Safe to call repeatedly — it no-ops once the sheet is already open.
    func expandIngredients() {
        // If a dough/ingredient value is already present, the sheet is open.
        if staticTexts["doughTotalWeight"].exists { return }
        let bar = buttons["ingredientsPeekBar"]
        guard bar.waitForExistence(timeout: 5) else { return }
        bar.tap()
        _ = staticTexts["doughTotalWeight"].waitForExistence(timeout: 5)
    }

    /// Asserts the calculated dough's total weight on the results screen.
    func assertDoughTotalWeight(_ weight: String, _ message: String = "") {
        expandIngredients()
        let weightText = staticTexts["doughTotalWeight"]
        XCTAssertTrue(weightText.waitForExistence(timeout: 5), "Dough total weight not found. \(message)")
        XCTAssertEqual(weightText.label, weight, "Dough total weight mismatch. \(message)")
    }

    /// Asserts a calculated ingredient's weight and percentage on the results screen.
    func assertCalculatedIngredient(name: String, weight: String, percent: String, _ message: String = "") {
        expandIngredients()
        let weightText = staticTexts["ingredientWeight_\(name)"]
        XCTAssertTrue(weightText.waitForExistence(timeout: 5), "Calculated weight for \(name) not found. \(message)")
        XCTAssertEqual(weightText.label, weight, "Calculated weight for \(name) mismatch. \(message)")

        let percentText = staticTexts["ingredientPercent_\(name)"]
        XCTAssertTrue(percentText.waitForExistence(timeout: 5), "Calculated percent for \(name) not found. \(message)")
        XCTAssertEqual(percentText.label, percent, "Calculated percent for \(name) mismatch. \(message)")
    }

    /// Asserts a calculated ingredient's weight and percentage on the results screen,
    /// parsing the displayed (rounded) labels as numbers and comparing within
    /// `weightAccuracy`/`percentAccuracy`. Use this for values with repeating decimals,
    /// where the exact formatted string depends on rounding and isn't worth pinning down
    /// to the digit - the goal is to catch precision-loss/floor/ceil bugs, not to
    /// pin the formatter's rounding mode.
    func assertCalculatedIngredient(
        name: String,
        weight: Double,
        weightAccuracy: Double,
        percent: Double,
        percentAccuracy: Double,
        _ message: String = ""
    ) {
        expandIngredients()
        let weightText = staticTexts["ingredientWeight_\(name)"]
        XCTAssertTrue(weightText.waitForExistence(timeout: 5), "Calculated weight for \(name) not found. \(message)")
        let actualWeight = weightText.label.parsedNumericValue
        XCTAssertNotNil(actualWeight, "Could not parse calculated weight \"\(weightText.label)\" for \(name). \(message)")
        if let actualWeight {
            XCTAssertEqual(actualWeight, weight, accuracy: weightAccuracy, "Calculated weight for \(name) mismatch. \(message)")
        }

        let percentText = staticTexts["ingredientPercent_\(name)"]
        XCTAssertTrue(percentText.waitForExistence(timeout: 5), "Calculated percent for \(name) not found. \(message)")
        let actualPercent = percentText.label.parsedNumericValue
        XCTAssertNotNil(actualPercent, "Could not parse calculated percent \"\(percentText.label)\" for \(name). \(message)")
        if let actualPercent {
            XCTAssertEqual(actualPercent, percent, accuracy: percentAccuracy, "Calculated percent for \(name) mismatch. \(message)")
        }
    }

    // MARK: - Mode selection

    func chooseMode(byPercent: Bool) {
        let card = buttons[byPercent ? "byPercentModeCard" : "byWeightModeCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Mode card not found")
        card.tap()
        waitForUITransition()
    }

    // MARK: - Details step

    func fillDetails(name: String, newCollection: String, defaultWeight: String? = nil, includePreferment: Bool = false) {
        let nameField = textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Recipe name field not found")
        nameField.enterText(name, app: self)

        let newCollectionToggle = switches["newCollectionToggle"]
        XCTAssertTrue(newCollectionToggle.waitForExistence(timeout: 5))
        scrollToElement(newCollectionToggle)
        // The accessibility identifier is on the whole row, but tapping its
        // center misses the actual switch control on the right edge.
        newCollectionToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let collectionField = textFields["newCollectionNameField"]
        XCTAssertTrue(collectionField.waitForExistence(timeout: 5), "New collection name field not found")
        collectionField.enterText(newCollection, app: self)

        if let defaultWeight {
            let weightField = textFields["defaultWeightField"]
            XCTAssertTrue(weightField.waitForExistence(timeout: 5), "Default weight field not found")
            weightField.enterText(defaultWeight, app: self)
        }

        if includePreferment {
            let prefermentToggle = switches["containsPrefermentToggle"]
            XCTAssertTrue(prefermentToggle.waitForExistence(timeout: 5))
            scrollToElement(prefermentToggle)
            prefermentToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }

        tapDetailsNext()
    }

    /// Opens the (new-recipe) collection picker and selects `name` from the list of
    /// existing collections. The default SwiftUI `Picker` inside a `Form` pushes a
    /// selection screen whose rows may surface as buttons or static text depending on
    /// platform/style, so this checks both.
    func selectExistingCollection(_ name: String) {
        let picker = buttons["collectionPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Collection picker not found")
        scrollToElement(picker)
        picker.tap()

        let buttonOption = buttons[name].firstMatch
        if buttonOption.waitForExistence(timeout: 3) {
            buttonOption.tap()
            return
        }
        let textOption = staticTexts[name].firstMatch
        XCTAssertTrue(textOption.waitForExistence(timeout: 5), "Existing collection option \"\(name)\" not found in picker")
        textOption.tap()
    }

    func tapDetailsNext() {
        let next = buttons["detailsNextButton"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Details Next button not found")
        scrollToElement(next)
        next.tap()
    }

    // MARK: - Ingredients step

    func fillFlour(at index: Int, name: String, value: String) {
        let nameField = textFields["flourNameField_\(index)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Flour name field \(index) not found")
        nameField.enterText(name, app: self)

        let valueField = textFields["flourValueField_\(index)"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 5), "Flour value field \(index) not found")
        valueField.enterText(value, app: self)
    }

    func fillIngredient(at index: Int, name: String, value: String? = nil) {
        let nameField = textFields["ingredientNameField_\(index)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Ingredient name field \(index) not found")
        nameField.enterText(name, app: self)

        if let value {
            let valueField = textFields["ingredientValueField_\(index)"]
            XCTAssertTrue(valueField.waitForExistence(timeout: 5), "Ingredient value field \(index) not found")
            valueField.enterText(value, app: self)
        }
    }

    /// Taps "Add Flour" to append a new (empty) flour row.
    func addFlour() {
        let button = buttons["addFlourButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Add Flour button not found")
        scrollToElement(button)
        button.tap()
    }

    /// Taps "Add Ingredient" to append a new regular ingredient row.
    func addIngredient() {
        let button = buttons["addIngredientButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Add Ingredient button not found")
        scrollToElement(button)
        button.tap()

        let byPercent = buttons["By Percentage"].firstMatch
        if byPercent.waitForExistence(timeout: 1) {
            byPercent.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return
        }

        let byWeight = buttons["By Weight"].firstMatch
        if byWeight.waitForExistence(timeout: 1) {
            byWeight.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Swipes the flour row at `index` left and taps "Delete".
    func deleteFlour(at index: Int) {
        let nameField = textFields["flourNameField_\(index)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Flour name field \(index) not found")
        scrollToElement(nameField)
        nameField.swipeLeft()
        let deleteButton = buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button not found after swiping flour row \(index)")
        deleteButton.tap()
    }

    /// Swipes the ingredient row at `index` left and taps "Delete".
    func deleteIngredient(at index: Int) {
        let nameField = textFields["ingredientNameField_\(index)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Ingredient name field \(index) not found")
        scrollToElement(nameField)
        nameField.swipeLeft()
        let deleteButton = buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button not found after swiping ingredient row \(index)")
        deleteButton.tap()
    }

    /// Asserts the flour row at `index` has the given name and value.
    func assertFlour(at index: Int, name: String, value: String, _ message: String = "") {
        let nameField = textFields["flourNameField_\(index)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Flour name field \(index) not found. \(message)")
        XCTAssertEqual(nameField.value as? String, name, "Flour \(index) name mismatch. \(message)")

        let valueField = textFields["flourValueField_\(index)"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 5), "Flour value field \(index) not found. \(message)")
        XCTAssertEqual(valueField.value as? String, value, "Flour \(index) value mismatch. \(message)")
    }

    /// Asserts the ingredient row at `index` has the given name and value.
    func assertIngredient(at index: Int, name: String, value: String, _ message: String = "") {
        let nameField = textFields["ingredientNameField_\(index)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Ingredient name field \(index) not found. \(message)")
        XCTAssertEqual(nameField.value as? String, name, "Ingredient \(index) name mismatch. \(message)")

        let valueField = textFields["ingredientValueField_\(index)"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 5), "Ingredient value field \(index) not found. \(message)")
        XCTAssertEqual(valueField.value as? String, value, "Ingredient \(index) value mismatch. \(message)")
    }

    /// Taps a suggestion chip with the given ingredient name, which must currently be
    /// visible below a focused flour/ingredient name field.
    func tapSuggestionChip(named name: String) {
        let chip = buttons["suggestionChip_\(name)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Suggestion chip \"\(name)\" not found")
        chip.tap()
    }

    func tapIngredientsNext() {
        let next = buttons["ingredientsNextButton"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Ingredients Next button not found")
        scrollToElement(next)
        next.tap()
    }

    // MARK: - Preferment step

    func fillPrefermentDetails(name: String, flourPercent: String? = nil) {
        let nameField = textFields["prefermentNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Preferment name field not found")
        nameField.enterText(name, app: self)

        if let flourPercent {
            let percentField = textFields["prefermentFlourPercentField"]
            XCTAssertTrue(percentField.waitForExistence(timeout: 5), "Preferment flour percent field not found")
            percentField.enterText(flourPercent, app: self)
        }
    }

    func fillPrefermentFlour(at index: Int, name: String, value: String) {
        let nameField = textFields["prefermentFlourNameField_\(index)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Preferment flour name field \(index) not found")
        nameField.enterText(name, app: self)

        let valueField = textFields["prefermentFlourValueField_\(index)"]
        XCTAssertTrue(valueField.waitForExistence(timeout: 5), "Preferment flour value field \(index) not found")
        valueField.enterText(value, app: self)
    }

    func tapPrefermentNext() {
        let next = buttons["prefermentNextButton"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Preferment Next button not found")
        scrollToElement(next)
        next.tap()
    }

    // MARK: - Discard confirmation

    /// Dismisses the "discard unsaved changes" confirmation without discarding.
    /// The dialog renders as a popover whose cancel-role ("Keep Editing") button
    /// is omitted (per SwiftUI's popover behavior), so dismiss it by tapping outside.
    func dismissDiscardConfirmation() {
        let dismissRegion = otherElements["PopoverDismissRegion"]
        XCTAssertTrue(dismissRegion.waitForExistence(timeout: 5))
        dismissRegion.tap()
    }

    // MARK: - Preview / save

    func saveRecipe() {
        let save = buttons["saveRecipeButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Save button not found")
        scrollToElement(save)
        save.tap()
    }

    // MARK: - Navigation

    /// Pops the current screen via the leading navigation bar button.
    func navigateBack() {
        let back = navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Back button not found")
        back.tap()
    }

    // MARK: - History

    /// Opens recipe history from the calculator screen, using the actions menu when needed.
    func openHistory() {
        let button = buttons["historyButton"]
        if !button.waitForExistence(timeout: 2) {
            let menu = buttons["calculatorActionsMenu"]
            XCTAssertTrue(menu.waitForExistence(timeout: 5), "Recipe actions menu not found")
            menu.tap()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "History button not found")
        button.tap()
    }

    /// Finds a history entry row whose text contains `text`.
    func historyEntry(containing text: String) -> XCUIElement {
        staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Asserts a history entry containing `text` exists, scrolling to find it if needed.
    func assertHistoryEntryExists(containing text: String, _ message: String = "") {
        let entry = historyEntry(containing: text)
        scrollUntilExists(entry)
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "History entry containing \"\(text)\" not found. \(message)")
    }

    /// Asserts no history entry contains `text`.
    func assertHistoryEntryDoesNotExist(containing text: String, _ message: String = "") {
        XCTAssertFalse(historyEntry(containing: text).exists, "History entry containing \"\(text)\" unexpectedly found. \(message)")
    }

    /// Asserts the history screen is showing its empty state.
    func assertNoHistoryEntries(_ message: String = "") {
        XCTAssertTrue(staticTexts["No History Yet"].waitForExistence(timeout: 5), "Expected empty history state. \(message)")
    }

    /// Swipes a history entry row left and taps "Delete".
    func deleteHistoryEntry(containing text: String) {
        let entry = historyEntry(containing: text)
        scrollUntilExists(entry)
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "History entry containing \"\(text)\" not found")
        scrollToElement(entry)
        entry.swipeLeft()
        let deleteButton = buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button not found after swiping history entry")
        deleteButton.tap()
    }

    /// Swipes a history entry row left, taps "Restore", and confirms the alert.
    func restoreHistoryEntry(containing text: String) {
        let entry = historyEntry(containing: text)
        scrollUntilExists(entry)
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "History entry containing \"\(text)\" not found")
        scrollToElement(entry)
        entry.swipeLeft()
        let restoreButton = buttons["Restore"]
        XCTAssertTrue(restoreButton.waitForExistence(timeout: 5), "Restore button not found after swiping history entry")
        restoreButton.tap()

        let confirmButton = alerts["Restore Version"].buttons["Restore"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Restore confirmation alert not found")
        confirmButton.tap()
    }

    // MARK: - Calculator results: notes + set as default

    /// Enters text into the results screen's note field and taps "Save Note".
    func saveHistoryNote(_ text: String) {
        let field = textFields["historyNoteField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "History note field not found")
        field.clearAndType(text, app: self)

        let saveButton = buttons["saveNoteButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save Note button not found")
        scrollToElement(saveButton)
        saveButton.tap()
    }

    /// Taps the results screen's "Save Note" button without changing its current text.
    func tapSaveNote() {
        let saveButton = buttons["saveNoteButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Save Note button not found")
        scrollToElement(saveButton)
        saveButton.tap()
    }

    /// Taps "Set as Default" and confirms the resulting confirmation dialog.
    func setAsDefaultAndConfirm() {
        let button = buttons["setAsDefaultButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Set as Default button not found")
        scrollToElement(button)
        button.tap()

        let confirmButton = sheets.buttons["Set as Default"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "Set as Default confirmation not found")
        confirmButton.tap()
    }
}
