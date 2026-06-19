//
//  RecipeHistoryUITests.swift
//  Doughy UI Tests
//

import XCTest

/// Exercises the Recipe History feature against a recipe with:
///
///   Bread Flour: 100% (flour), Water: 70%, Salt: 2% (default dough weight: 1000g)
final class RecipeHistoryUITests: DoughyUITestCase {

    private func createTestRecipe(named name: String) {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        app.fillDetails(name: name, newCollection: "History Tests", defaultWeight: "1000")

        app.fillFlour(at: 0, name: "Bread Flour", value: "100")
        app.fillIngredient(at: 0, name: "Water", value: "70")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Salt", value: "2")

        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    /// Editing a recipe with a real change records a version entry with the
    /// expected diff. Restoring that version reverts the recipe and records a
    /// new version entry for the reverse change.
    func testEditRecordsVersionAndRestoreReverts() throws {
        let name = "History Edit Loaf"
        createTestRecipe(named: name)

        // Change Salt from 2% to 2.2%.
        app.editRecipe(named: name)
        app.tapDetailsNext()
        app.textFields["ingredientValueField_1"].replaceNumericValue("2.2", app: app)
        app.tapIngredientsNext()
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        app.openCalculator(for: name)
        app.openHistory()
        app.assertHistoryEntryExists(containing: "Salt: 2% → 2.2%")

        // Restoring reverts Salt to 2% and records the reverse diff.
        app.restoreHistoryEntry(containing: "Salt: 2% → 2.2%")
        app.assertHistoryEntryExists(containing: "Salt: 2.2% → 2%")

        app.navigateBack()
        app.navigateBack()

        app.editRecipe(named: name)
        app.tapDetailsNext()
        app.assertIngredient(at: 1, name: "Salt", value: "2")
        app.tapIngredientsNext()
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    /// Saving an edit that doesn't actually change anything shouldn't add a
    /// history entry.
    func testEditWithNoChangesDoesNotRecordHistory() throws {
        let name = "History No Change Loaf"
        createTestRecipe(named: name)

        app.editRecipe(named: name)
        app.tapDetailsNext()
        app.tapIngredientsNext()
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        app.openCalculator(for: name)
        app.openHistory()
        app.assertNoHistoryEntries()
    }

    /// Adjusting the calculator and tapping "Set as Default" updates the
    /// recipe's defaults and records a version entry with the expected diff.
    func testSetAsDefaultFromCalculatorOverride() throws {
        let name = "History Set Default Loaf"
        createTestRecipe(named: name)

        app.openCalculator(for: name)
        app.setSingleDoughWeight("1200")
        app.toggleAdjustIngredients()
        // Recipe ingredient order: [0] Bread Flour (flour, not editable),
        // [1] Water, [2] Salt.
        app.setIngredientPercent(at: 2, value: "3")
        app.tapCalculate()

        app.setAsDefaultAndConfirm()

        app.navigateBack()
        app.openHistory()
        app.assertHistoryEntryExists(containing: "Salt: 2% → 3%")
        app.assertHistoryEntryExists(containing: "Weight: 1,000g → 1,200g")

        app.navigateBack()
        app.navigateBack()

        // Re-open the calculator fresh and confirm the new defaults are applied.
        app.openCalculator(for: name)
        app.tapCalculate()

        app.assertDoughTotalWeight("1,200g")
        // 3/173 * 1200 = 20.808...
        app.assertCalculatedIngredient(name: "Salt", weight: 1200.0 * 3 / 173, weightAccuracy: 0.05, percent: 3, percentAccuracy: 0.01)
    }

    /// Notes can be added with or without calculator overrides: without
    /// overrides the note field starts empty, with overrides it's pre-filled
    /// with the diff those overrides would apply. Both end up in history.
    func testAddNoteWithAndWithoutOverrides() throws {
        let name = "History Note Loaf"
        createTestRecipe(named: name)

        // No overrides: save a free-text note.
        app.openCalculator(for: name)
        app.tapCalculate()
        app.saveHistoryNote("Tasted great, nice open crumb.")

        app.navigateBack()
        app.openHistory()
        app.assertHistoryEntryExists(containing: "Tasted great, nice open crumb.")

        // With an override: the note field is pre-filled with the diff, and
        // saving it as-is records that diff.
        app.navigateBack()
        app.setSingleDoughWeight("1100")
        app.tapCalculate()
        app.tapSaveNote()

        app.navigateBack()
        app.openHistory()
        app.assertHistoryEntryExists(containing: "Weight: 1,000g → 1,100g")
    }

    /// Deleting history entries (both notes and versions) removes them from
    /// the list. Deleting a version entry doesn't affect the live recipe.
    func testDeleteHistoryEntries() throws {
        let name = "History Delete Loaf"
        createTestRecipe(named: name)

        // Add and then delete a note.
        app.openCalculator(for: name)
        app.tapCalculate()
        app.saveHistoryNote("Note to delete")

        app.navigateBack()
        app.openHistory()
        app.assertHistoryEntryExists(containing: "Note to delete")
        app.deleteHistoryEntry(containing: "Note to delete")
        app.assertNoHistoryEntries()

        app.navigateBack()
        app.navigateBack()

        // Edit the recipe to record a version entry, then delete it.
        app.editRecipe(named: name)
        app.tapDetailsNext()
        app.textFields["ingredientValueField_1"].replaceNumericValue("2.5", app: app)
        app.tapIngredientsNext()
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        app.openCalculator(for: name)
        app.openHistory()
        app.assertHistoryEntryExists(containing: "Salt: 2% → 2.5%")
        app.deleteHistoryEntry(containing: "Salt: 2% → 2.5%")
        app.assertNoHistoryEntries()

        // Deleting the version entry shouldn't have reverted the live recipe.
        app.navigateBack()
        app.navigateBack()

        app.editRecipe(named: name)
        app.tapDetailsNext()
        app.assertIngredient(at: 1, name: "Salt", value: "2.5")
        app.tapIngredientsNext()
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }
}
