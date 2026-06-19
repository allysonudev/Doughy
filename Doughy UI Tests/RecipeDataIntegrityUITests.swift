//
//  RecipeDataIntegrityUITests.swift
//  Doughy UI Tests
//

import XCTest

final class RecipeDataIntegrityUITests: DoughyUITestCase {

    /// Everything entered at creation time should round-trip when the recipe is
    /// reopened for editing: name, flours (in order), and ingredients (in order),
    /// including non-flour staples like salt, yeast, oil, and sugar.
    ///
    /// Weight-mode recipes should reopen in weight mode, preserving the gram
    /// values entered at creation time.
    func testCreatedRecipeDataRoundTripsThroughEdit() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)

        app.fillDetails(name: "Data Integrity Loaf", newCollection: "Data Integrity Tests")

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

        XCTAssertTrue(app.staticTexts["Data Integrity Loaf"].waitForExistence(timeout: 5))
        // The new collection should appear as its own section in the recipe list.
        XCTAssertTrue(app.staticTexts["Data Integrity Tests"].waitForExistence(timeout: 5))

        app.editRecipe(named: "Data Integrity Loaf")

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "Data Integrity Loaf")

        app.tapDetailsNext()

        app.assertFlour(at: 0, name: "Bread Flour", value: "400")
        app.assertFlour(at: 1, name: "Whole Wheat Flour", value: "100")
        XCTAssertFalse(app.textFields["flourNameField_2"].exists, "Should be exactly 2 flours")

        app.assertIngredient(at: 0, name: "Water", value: "350")
        app.assertIngredient(at: 1, name: "Salt", value: "10")
        app.assertIngredient(at: 2, name: "Yeast", value: "5")
        app.assertIngredient(at: 3, name: "Olive Oil", value: "15")
        app.assertIngredient(at: 4, name: "Sugar", value: "10")
        XCTAssertFalse(app.textFields["ingredientNameField_5"].exists, "Should be exactly 5 ingredients")
    }

    /// Editing a recipe and saving without changing anything should leave every
    /// field exactly as it was.
    func testEditWithNoChangesPreservesRecipeData() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        app.fillDetails(name: "No Change Loaf", newCollection: "No Change Tests", defaultWeight: "900")

        app.fillFlour(at: 0, name: "Bread Flour", value: "90")
        app.addFlour()
        app.fillFlour(at: 1, name: "Whole Wheat Flour", value: "10")

        app.fillIngredient(at: 0, name: "Water", value: "65")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Salt", value: "2")

        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["No Change Loaf"].waitForExistence(timeout: 5))

        // First pass: confirm the data is there, then save without changing anything.
        app.editRecipe(named: "No Change Loaf")

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "No Change Loaf")

        let weightField = app.textFields["defaultWeightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        XCTAssertEqual(weightField.value as? String, "900")

        app.tapDetailsNext()

        app.assertFlour(at: 0, name: "Bread Flour", value: "90")
        app.assertFlour(at: 1, name: "Whole Wheat Flour", value: "10")
        app.assertIngredient(at: 0, name: "Water", value: "65")
        app.assertIngredient(at: 1, name: "Salt", value: "2")

        app.tapIngredientsNext()
        app.saveRecipe()

        // Second pass: nothing should have changed.
        XCTAssertTrue(app.staticTexts["No Change Loaf"].waitForExistence(timeout: 5))
        app.editRecipe(named: "No Change Loaf")

        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, "No Change Loaf")
        XCTAssertEqual(weightField.value as? String, "900")

        app.tapDetailsNext()

        app.assertFlour(at: 0, name: "Bread Flour", value: "90", "after a no-op edit")
        app.assertFlour(at: 1, name: "Whole Wheat Flour", value: "10", "after a no-op edit")
        XCTAssertFalse(app.textFields["flourNameField_2"].exists, "Should still be exactly 2 flours")

        app.assertIngredient(at: 0, name: "Water", value: "65", "after a no-op edit")
        app.assertIngredient(at: 1, name: "Salt", value: "2", "after a no-op edit")
        XCTAssertFalse(app.textFields["ingredientNameField_2"].exists, "Should still be exactly 2 ingredients")
    }

    /// Deleting one ingredient during an edit should leave all the others
    /// (and the flours) untouched, with the remaining rows shifted up.
    ///
    /// Weight-mode recipes reopen in grams, so deleting one ingredient should
    /// leave the remaining gram values untouched.
    func testEditDeletingIngredientRemovesOnlyThatIngredient() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)

        app.fillDetails(name: "Delete Ingredient Loaf", newCollection: "Delete Ingredient Tests")

        app.fillFlour(at: 0, name: "Bread Flour", value: "500")

        app.fillIngredient(at: 0, name: "Water", value: "350")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Salt", value: "10")
        app.addIngredient()
        app.fillIngredient(at: 2, name: "Yeast", value: "5")

        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Delete Ingredient Loaf"].waitForExistence(timeout: 5))

        app.editRecipe(named: "Delete Ingredient Loaf")
        app.tapDetailsNext()

        // Remove "Salt" (index 1); "Water" and "Yeast" should remain, with "Yeast" shifting up.
        app.deleteIngredient(at: 1)

        app.assertIngredient(at: 0, name: "Water", value: "350", "right after deleting Salt")
        app.assertIngredient(at: 1, name: "Yeast", value: "5", "right after deleting Salt")
        XCTAssertFalse(app.textFields["ingredientNameField_2"].exists, "Salt should be gone")
        for index in 0...1 {
            XCTAssertNotEqual(app.textFields["ingredientNameField_\(index)"].value as? String, "Salt")
        }

        // Flour should be untouched by the ingredient deletion.
        app.assertFlour(at: 0, name: "Bread Flour", value: "500", "right after deleting an ingredient")

        app.tapIngredientsNext()
        app.saveRecipe()

        // Reopen to confirm the deletion persisted.
        XCTAssertTrue(app.staticTexts["Delete Ingredient Loaf"].waitForExistence(timeout: 5))
        app.editRecipe(named: "Delete Ingredient Loaf")
        app.tapDetailsNext()

        app.assertFlour(at: 0, name: "Bread Flour", value: "500", "after reopening")
        app.assertIngredient(at: 0, name: "Water", value: "350", "after reopening")
        app.assertIngredient(at: 1, name: "Yeast", value: "5", "after reopening")
        XCTAssertFalse(app.textFields["ingredientNameField_2"].exists, "Salt should still be gone after saving")
        for index in 0...1 {
            XCTAssertNotEqual(app.textFields["ingredientNameField_\(index)"].value as? String, "Salt")
        }
    }

    /// Deleting one flour during an edit should leave all other flours and all
    /// ingredients untouched, with the remaining flour rows shifted up.
    ///
    /// In weight mode, deleting one flour should leave the remaining flour and
    /// ingredient gram values untouched.
    func testEditDeletingFlourRemovesOnlyThatFlour() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)

        app.fillDetails(name: "Delete Flour Loaf", newCollection: "Delete Flour Tests")

        app.fillFlour(at: 0, name: "Bread Flour", value: "400")
        app.addFlour()
        app.fillFlour(at: 1, name: "Whole Wheat Flour", value: "100")

        app.fillIngredient(at: 0, name: "Water", value: "350")

        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Delete Flour Loaf"].waitForExistence(timeout: 5))

        app.editRecipe(named: "Delete Flour Loaf")
        app.tapDetailsNext()

        // Remove "Bread Flour" (index 0); "Whole Wheat Flour" should shift up to index 0.
        app.deleteFlour(at: 0)

        app.assertFlour(at: 0, name: "Whole Wheat Flour", value: "100", "right after deleting Bread Flour")
        XCTAssertFalse(app.textFields["flourNameField_1"].exists, "Bread Flour should be gone")
        XCTAssertNotEqual(app.textFields["flourNameField_0"].value as? String, "Bread Flour")

        // Ingredients should be untouched by the flour deletion.
        app.assertIngredient(at: 0, name: "Water", value: "350", "right after deleting a flour")

        app.tapIngredientsNext()
        app.saveRecipe()

        // Reopen to confirm the deletion persisted.
        XCTAssertTrue(app.staticTexts["Delete Flour Loaf"].waitForExistence(timeout: 5))
        app.editRecipe(named: "Delete Flour Loaf")
        app.tapDetailsNext()

        app.assertFlour(at: 0, name: "Whole Wheat Flour", value: "100", "after reopening")
        XCTAssertFalse(app.textFields["flourNameField_1"].exists, "Bread Flour should still be gone after saving")
        app.assertIngredient(at: 0, name: "Water", value: "350", "after reopening")
    }
}
