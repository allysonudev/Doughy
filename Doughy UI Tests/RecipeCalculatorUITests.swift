//
//  RecipeCalculatorUITests.swift
//  Doughy UI Tests
//

import XCTest

/// Exercises the "How much do I need?" calculator against a known recipe:
///
///   Bread Flour: 100%, Water: 40%, Salt: 10% (default dough weight: 1500g)
///
/// The calculator distributes the total dough weight proportionally across
/// these percentages (sum = 150), so for any total weight `W`:
///   Bread Flour = W * 100/150,  Water = W * 40/150,  Salt = W * 10/150
///
/// Weights are chosen so every result lands on a whole number, matching the
/// app's WeightFormatter (no fractional digits above 100g).
final class RecipeCalculatorUITests: DoughyUITestCase {

    private let recipeName = "Calculator Test Loaf"

    private func createTestRecipe() {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        app.fillDetails(name: recipeName, newCollection: "Calculator Tests", defaultWeight: "1500")

        app.fillFlour(at: 0, name: "Bread Flour", value: "100")

        app.fillIngredient(at: 0, name: "Water", value: "40")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Salt", value: "10")

        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts[recipeName].waitForExistence(timeout: 5))
    }

    /// 1 dough at the default weight (1500g), with no modifications.
    func testSingleDoughAtDefaultWeight() throws {
        createTestRecipe()
        app.openCalculator(for: recipeName)

        app.tapCalculate()

        app.assertDoughTotalWeight("1,500g")
        app.assertCalculatedIngredient(name: "Bread Flour", weight: "1,000g", percent: "100%")
        app.assertCalculatedIngredient(name: "Water", weight: "400g", percent: "40%")
        app.assertCalculatedIngredient(name: "Salt", weight: "100g", percent: "10%")
    }

    /// Multiple doughs at the default weight scales every ingredient linearly.
    func testMultipleDoughsAtDefaultWeight() throws {
        createTestRecipe()
        app.openCalculator(for: recipeName)

        app.setDoughCount("3")
        app.tapCalculate()

        // 3 doughs * 1500g = 4500g total.
        app.assertDoughTotalWeight("4,500g")
        app.assertCalculatedIngredient(name: "Bread Flour", weight: "3,000g", percent: "100%")
        app.assertCalculatedIngredient(name: "Water", weight: "1,200g", percent: "40%")
        app.assertCalculatedIngredient(name: "Salt", weight: "300g", percent: "10%")
    }

    /// Overriding the single dough weight (instead of using the recipe's default).
    func testSingleDoughWithCustomWeight() throws {
        createTestRecipe()
        app.openCalculator(for: recipeName)

        app.setSingleDoughWeight("300")
        app.tapCalculate()

        app.assertDoughTotalWeight("300g")
        app.assertCalculatedIngredient(name: "Bread Flour", weight: "200g", percent: "100%")
        app.assertCalculatedIngredient(name: "Water", weight: "80g", percent: "40%")
        app.assertCalculatedIngredient(name: "Salt", weight: "20g", percent: "10%")
    }

    /// A custom single dough weight that doesn't divide evenly across the
    /// recipe's percentages (1000 / 150ths), so every ingredient weight is a
    /// repeating decimal (666.6..., 266.6..., 66.6...). Percentages stay exact
    /// integers here since this recipe has only one flour.
    func testSingleDoughWithNonWholeNumberWeight() throws {
        createTestRecipe()
        app.openCalculator(for: recipeName)

        app.setSingleDoughWeight("1000")
        app.tapCalculate()

        app.assertDoughTotalWeight("1,000g")
        // 100/150 * 1000 = 666.666... -> rounds to 0 decimals (>100).
        app.assertCalculatedIngredient(name: "Bread Flour", weight: 666.6666666666666, weightAccuracy: 0.5, percent: 100, percentAccuracy: 0.01)
        // 40/150 * 1000 = 266.666... -> rounds to 0 decimals (>100).
        app.assertCalculatedIngredient(name: "Water", weight: 266.6666666666667, weightAccuracy: 0.5, percent: 40, percentAccuracy: 0.01)
        // 10/150 * 1000 = 66.666... -> rounds to 1 decimal (10-100 range).
        app.assertCalculatedIngredient(name: "Salt", weight: 66.66666666666667, weightAccuracy: 0.5, percent: 10, percentAccuracy: 0.01)
    }

    /// Tweaking every non-flour ingredient's percentage recalculates the whole
    /// dough's proportions (flour stays the reference at 100%).
    func testAdjustingIngredientPercentagesRecalculatesProportions() throws {
        createTestRecipe()
        app.openCalculator(for: recipeName)

        app.setSingleDoughWeight("1800")
        app.toggleAdjustIngredients()

        // Recipe ingredient order: [0] Bread Flour (flour, not editable),
        // [1] Water, [2] Salt.
        app.setIngredientPercent(at: 1, value: "60")
        app.setIngredientPercent(at: 2, value: "20")

        app.tapCalculate()

        // New percent sum = 100 (flour) + 60 (water) + 20 (salt) = 180.
        // 1800g * 100/180 = 1000, * 60/180 = 600, * 20/180 = 200.
        app.assertDoughTotalWeight("1,800g")
        app.assertCalculatedIngredient(name: "Bread Flour", weight: "1,000g", percent: "100%")
        app.assertCalculatedIngredient(name: "Water", weight: "600g", percent: "60%")
        app.assertCalculatedIngredient(name: "Salt", weight: "200g", percent: "20%")
    }

    /// A recipe with two flours (percentages summing to 100%, as required by
    /// `CreateRecipeView.ingredientsReady` in by-percent mode) and other
    /// percentages chosen so the calculated weights are repeating decimals,
    /// exercising rounding/precision in `WeightFormatter`'s output.
    ///
    ///   Bread Flour 70%, Whole Wheat Flour 30%, Water 65%, Salt 2%, Yeast 1%
    ///   (total percent = 168, default weight = 1000)
    ///
    /// Since the flour percentages sum to 100, the recomputed percentages on
    /// the results screen are always exactly the input percentages.
    func testCalculatorWithRepeatingDecimalWeights() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: true)

        let name = "Repeating Decimal Loaf"
        app.fillDetails(name: name, newCollection: "Calculator Tests", defaultWeight: "1000")

        app.fillFlour(at: 0, name: "Bread Flour", value: "70")
        app.addFlour()
        app.fillFlour(at: 1, name: "Whole Wheat Flour", value: "30")

        app.fillIngredient(at: 0, name: "Water", value: "65")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Salt", value: "2")
        app.addIngredient()
        app.fillIngredient(at: 2, name: "Yeast", value: "1")

        app.tapIngredientsNext()
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        app.openCalculator(for: name)
        app.tapCalculate()

        app.assertDoughTotalWeight("1,000g")

        // weight = percent / 168 * 1000.
        // Bread Flour: 70/168*1000 = 416.6666... -> 0 decimals (>100) -> 417
        app.assertCalculatedIngredient(name: "Bread Flour", weight: 416.6666666666667, weightAccuracy: 0.5, percent: 70, percentAccuracy: 0.01)
        // Whole Wheat Flour: 30/168*1000 = 178.5714... -> 0 decimals (>100) -> 179
        app.assertCalculatedIngredient(name: "Whole Wheat Flour", weight: 178.57142857142858, weightAccuracy: 0.5, percent: 30, percentAccuracy: 0.01)
        // Water: 65/168*1000 = 386.9047... -> 0 decimals (>100) -> 387
        app.assertCalculatedIngredient(name: "Water", weight: 386.9047619047619, weightAccuracy: 0.5, percent: 65, percentAccuracy: 0.01)
        // Salt: 2/168*1000 = 11.9047... -> 1 decimal (10-100) -> 11.9
        app.assertCalculatedIngredient(name: "Salt", weight: 11.904761904761905, weightAccuracy: 0.01, percent: 2, percentAccuracy: 0.01)
        // Yeast: 1/168*1000 = 5.9523... -> 2 decimals (<10) -> 5.95
        app.assertCalculatedIngredient(name: "Yeast", weight: 5.9523809523809526, weightAccuracy: 0.01, percent: 1, percentAccuracy: 0.01)
    }

    // MARK: - Copy recipe

    /// Opens a recipe's calculator, copies it via `calculatorCopyButton` (behind
    /// `calculatorActionsMenu`), saves the copy (pre-filled as "Copy of <name>" per
    /// `CreateRecipeView.copyName`), and confirms the copy shows up in the recipe list.
    func testCopyRecipeAppearsInList() throws {
        createTestRecipe()
        app.openCalculator(for: recipeName)

        let menu = app.buttons["calculatorActionsMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "Recipe actions menu not found")
        menu.tap()

        let copyButton = app.buttons["calculatorCopyButton"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5), "Copy button not found")
        copyButton.tap()

        // The copy sheet opens directly on the details step, pre-filled from the
        // original recipe (same collection, "Copy of <name>").
        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Copy sheet's name field not found")
        XCTAssertEqual(nameField.value as? String, "Copy of \(recipeName)")

        app.tapDetailsNext()
        app.tapIngredientsNext()
        app.saveRecipe()

        // Saving the copy dismisses back to the calculator, not the list; return there.
        app.navigateBack()

        let copyCell = app.staticTexts["Copy of \(recipeName)"]
        app.scrollUntilExists(copyCell)
        XCTAssertTrue(copyCell.waitForExistence(timeout: 5), "Copied recipe should appear in the recipe list")
    }

    // MARK: - By-weight adjust

    /// Mirrors `testAdjustingIngredientPercentagesRecalculatesProportions`, but for a
    /// by-weight recipe: overriding ingredient weights in Adjust mode (via
    /// `ingredientWeightField_N`) recalculates the results screen directly from the
    /// overridden grams (no percentage math involved for by-weight recipes).
    func testByWeightAdjustingIngredientWeightsRecalculatesResults() throws {
        let name = "By Weight Adjust Loaf"
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)
        app.fillDetails(name: name, newCollection: "By Weight Adjust Tests")

        app.fillFlour(at: 0, name: "Bread Flour", value: "500")
        app.fillIngredient(at: 0, name: "Water", value: "350")
        app.addIngredient()
        app.fillIngredient(at: 1, name: "Salt", value: "10")

        app.tapIngredientsNext()
        app.saveRecipe()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        app.openCalculator(for: name)
        app.showAdjustMode()

        // Recipe ingredient order: [0] Water, [1] Salt (flour has no weight field; it's read-only in Adjust mode).
        app.setIngredientWeight(at: 0, value: "400")
        app.setIngredientWeight(at: 1, value: "15")

        app.tapCalculate()

        app.assertCalculatedIngredient(name: "Bread Flour", weight: "500g", percent: "100%")
        app.assertCalculatedIngredient(name: "Water", weight: "400g", percent: "80%")
        app.assertCalculatedIngredient(name: "Salt", weight: "15g", percent: "3%")
    }

    // MARK: - Unit cycling

    /// Tapping a liquid ingredient's weight on the results screen cycles its displayed
    /// unit, per `CalculatorView+UnitCycling.swift`'s `cycleUnits`/`advanceUnit`. Water
    /// has a known density, so its weight row is tappable (`isButton` trait) and starts
    /// in grams before cycling to a volume unit.
    func testTappingLiquidIngredientCyclesDisplayUnit() throws {
        createTestRecipe()
        app.openCalculator(for: recipeName)
        app.tapCalculate()
        app.expandIngredients()

        let weightText = app.staticTexts["ingredientWeight_Water"]
        XCTAssertTrue(weightText.waitForExistence(timeout: 5), "Water's calculated weight not found")
        let originalLabel = weightText.label
        XCTAssertTrue(originalLabel.hasSuffix("g"), "Water should start displayed in grams, got \(originalLabel)")

        app.cycleIngredientUnit(name: "Water")

        let afterFirstTap = app.staticTexts["ingredientWeight_Water"]
        XCTAssertTrue(afterFirstTap.waitForExistence(timeout: 5))
        XCTAssertNotEqual(afterFirstTap.label, originalLabel, "Tapping the weight should cycle to a different unit")

        // Cycle again to confirm it keeps advancing through the unit list (not stuck).
        app.cycleIngredientUnit(name: "Water")
        let afterSecondTap = app.staticTexts["ingredientWeight_Water"]
        XCTAssertTrue(afterSecondTap.waitForExistence(timeout: 5))
        XCTAssertNotEqual(afterSecondTap.label, afterFirstTap.label, "Second tap should advance to yet another unit (or wrap distinctly)")
    }
}
