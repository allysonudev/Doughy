//
//  PrefermentToolTests.swift
//  Doughy Tests
//

import XCTest
@testable import Doughy

final class PrefermentToolTests: XCTestCase {

    private func flour(_ name: String = "Bread Flour", percent: Double) -> Ingredient {
        Ingredient(name: name, isFlour: true, defaultPercentage: percent, temperature: nil)
    }

    private func ingredient(_ name: String, percent: Double) -> Ingredient {
        Ingredient(name: name, isFlour: false, defaultPercentage: percent, temperature: nil)
    }

    private func simpleRecipe(
        flours: [Ingredient]? = nil,
        waterPercent: Double = 70,
        yeastPercent: Double = 1,
        defaultWeight: Double = 1000
    ) -> Recipe {
        Recipe(
            name: "Test Loaf",
            collection: "Tests",
            defaultWeight: defaultWeight,
            ingredients: (flours ?? [flour(percent: 100)]) + [
                ingredient("Water", percent: waterPercent),
                ingredient("Salt", percent: 2),
                ingredient("Instant Yeast", percent: yeastPercent)
            ],
            instructions: []
        )
    }

    // MARK: - canAddPreferment

    func testCanAddPrefermentRequiresFlourWaterAndYeast() {
        XCTAssertTrue(PrefermentTool.canAddPreferment(to: simpleRecipe()))

        let noYeast = Recipe(
            name: "No Yeast", collection: "Tests", defaultWeight: 1000,
            ingredients: [flour(percent: 100), ingredient("Water", percent: 70)],
            instructions: []
        )
        XCTAssertFalse(PrefermentTool.canAddPreferment(to: noYeast))

        let noWater = Recipe(
            name: "No Water", collection: "Tests", defaultWeight: 1000,
            ingredients: [flour(percent: 100), ingredient("Instant Yeast", percent: 1)],
            instructions: []
        )
        XCTAssertFalse(PrefermentTool.canAddPreferment(to: noWater))
    }

    func testCanAddPrefermentFalseWhenRecipeAlreadyHasOne() throws {
        let base = simpleRecipe()
        let preferment = PrefermentTool.buildPreferment(
            name: "Poolish", flourPercentOfTotal: 50,
            flourAllocations: PrefermentTool.defaultFlourAllocations(for: base),
            hydrationPercent: 100, waterName: "Water",
            yeastPercent: 0.1, yeastName: "Instant Yeast"
        )
        let withPreferment = try PrefermentTool.addPreferment(preferment, to: base, removingYeastNamed: nil)
        XCTAssertFalse(PrefermentTool.canAddPreferment(to: withPreferment))
    }

    // MARK: - addPreferment / removePreferment

    func testAddPoolishKeepsMainDoughTotalsUnchanged() throws {
        let base = simpleRecipe()
        let preferment = PrefermentTool.buildPreferment(
            name: "Poolish", flourPercentOfTotal: 50,
            flourAllocations: PrefermentTool.defaultFlourAllocations(for: base),
            hydrationPercent: 100, waterName: "Water",
            yeastPercent: 0.1, yeastName: "Instant Yeast"
        )
        let result = try PrefermentTool.addPreferment(preferment, to: base, removingYeastNamed: nil)

        // Main dough totals are unchanged - they already represented the recipe's grand total.
        XCTAssertEqual(result.ingredients.count, base.ingredients.count)
        XCTAssertEqual(result.ingredients.first { $0.name == "Water" }?.defaultPercentage ?? 0, 70, accuracy: 0.0001)
        XCTAssertEqual(result.ingredients.first { $0.name == "Bread Flour" }?.defaultPercentage ?? 0, 100, accuracy: 0.0001)

        XCTAssertEqual(result.preferment.flourPercentage, 50, accuracy: 0.0001)
        XCTAssertEqual(result.preferment.ingredients.first { $0.name == "Water" }?.defaultPercentage ?? 0, 100, accuracy: 0.0001)
        XCTAssertEqual(result.preferment.ingredients.first { $0.name == "Instant Yeast" }?.defaultPercentage ?? 0, 0.1, accuracy: 0.0001)

        // Total hydration (water / flour) is identical before and after.
        let calculator = Calculator.shared
        let before = try calculator.calculate(recipe: base)
        let after = try calculator.calculate(recipe: result)
        let beforeHydration = (before.ingredients.first { $0.name == "Water" }?.weight ?? 0)
            / (before.ingredients.filter(\.isFlour).map(\.weight).reduce(0, +))
        let afterTotalWater = after.ingredients.first { $0.name == "Water" }!.weight
        let afterTotalFlour = after.ingredients.filter(\.isFlour).map(\.weight).reduce(0, +)
        XCTAssertEqual(beforeHydration, afterTotalWater / afterTotalFlour, accuracy: 0.0001)
    }

    func testAddSourdoughStarterRemovesYeastFromMainDough() throws {
        let base = simpleRecipe()
        let preferment = PrefermentTool.buildPreferment(
            name: "Sourdough Starter", flourPercentOfTotal: 10,
            flourAllocations: PrefermentTool.defaultFlourAllocations(for: base),
            hydrationPercent: 100, waterName: "Water",
            yeastPercent: nil, yeastName: nil
        )
        let result = try PrefermentTool.addPreferment(preferment, to: base, removingYeastNamed: "Instant Yeast")

        XCTAssertNil(result.ingredients.first { $0.name == "Instant Yeast" })
        XCTAssertTrue(result.preferment.ingredients.allSatisfy { !$0.name.localizedCaseInsensitiveContains("yeast") })
    }

    func testAddPrefermentThrowsWhenHydrationExceedsAvailableWater() {
        let base = simpleRecipe(waterPercent: 60)
        // 80% flour at 100% hydration wants 80% of total flour in water - more than the 60% the recipe has.
        let preferment = PrefermentTool.buildPreferment(
            name: "Poolish", flourPercentOfTotal: 80,
            flourAllocations: PrefermentTool.defaultFlourAllocations(for: base),
            hydrationPercent: 100, waterName: "Water",
            yeastPercent: nil, yeastName: nil
        )
        XCTAssertThrowsError(try PrefermentTool.addPreferment(preferment, to: base, removingYeastNamed: nil)) { error in
            guard case RecipeBuilderError.mainDoughLessThanPreferment = error else {
                return XCTFail("Expected mainDoughLessThanPreferment, got \(error)")
            }
        }
    }

    func testRemovePrefermentRestoresPlainRecipeWithSameIngredients() throws {
        let base = simpleRecipe()
        let preferment = PrefermentTool.buildPreferment(
            name: "Biga", flourPercentOfTotal: 50,
            flourAllocations: PrefermentTool.defaultFlourAllocations(for: base),
            hydrationPercent: 60, waterName: "Water",
            yeastPercent: 0.1, yeastName: "Instant Yeast"
        )
        let withPreferment = try PrefermentTool.addPreferment(preferment, to: base, removingYeastNamed: nil)

        let removed = PrefermentTool.removePreferment(from: withPreferment)

        XCTAssertEqual(removed.ingredients.count, base.ingredients.count)
        for original in base.ingredients {
            XCTAssertEqual(removed.ingredients.first { $0.name == original.name }?.defaultPercentage ?? 0, original.defaultPercentage, accuracy: 0.0001)
        }
    }

    // MARK: - Multiple flours

    func testBuildPrefermentSplitsMultipleFlours() throws {
        let flours = [flour("Bread Flour", percent: 80), flour("Whole Wheat", percent: 20)]
        let base = simpleRecipe(flours: flours)

        var allocations = PrefermentTool.defaultFlourAllocations(for: base)
        XCTAssertEqual(allocations.count, 2)
        XCTAssertEqual(allocations.first { $0.name == "Bread Flour" }?.percentOfPrefermentFlour ?? 0, 80, accuracy: 0.0001)
        XCTAssertEqual(allocations.first { $0.name == "Whole Wheat" }?.percentOfPrefermentFlour ?? 0, 20, accuracy: 0.0001)

        // Override to an all-bread-flour preferment.
        allocations = allocations.map {
            PrefermentTool.FlourAllocation(name: $0.name, percentOfPrefermentFlour: $0.name == "Bread Flour" ? 100 : 0)
        }
        let preferment = PrefermentTool.buildPreferment(
            name: "Poolish", flourPercentOfTotal: 50,
            flourAllocations: allocations,
            hydrationPercent: 100, waterName: "Water",
            yeastPercent: nil, yeastName: nil
        )
        let result = try PrefermentTool.addPreferment(preferment, to: base, removingYeastNamed: nil)
        XCTAssertEqual(result.preferment.ingredients.first { $0.name == "Bread Flour" }?.defaultPercentage ?? 0, 100, accuracy: 0.0001)
        XCTAssertNil(result.preferment.ingredients.first { $0.name == "Whole Wheat" && $0.defaultPercentage > 0 })
    }

    // MARK: - Low-yeast recipes (Neapolitan-style regression)

    /// A slow-fermented, low-yeast recipe (e.g. Neapolitan pizza, ~0.05% total
    /// yeast) shouldn't break when a Biga's default yeast is applied: a flat
    /// 0.1% default would claim more yeast than a 0.05%-total recipe has once
    /// split across a 50%-flour preferment, pushing the final dough negative.
    func testBigaDefaultYeastNeverExceedsALowYeastRecipesTotal() throws {
        let base = simpleRecipe(yeastPercent: 0.05)

        let defaultYeast = try XCTUnwrap(PrefermentPreset.biga.defaultYeastPercent(for: base))
        let preferment = PrefermentTool.buildPreferment(
            name: "Biga", flourPercentOfTotal: PrefermentPreset.biga.defaultFlourPercentOfTotal,
            flourAllocations: PrefermentTool.defaultFlourAllocations(for: base),
            hydrationPercent: PrefermentPreset.biga.defaultHydrationPercent, waterName: "Water",
            yeastPercent: defaultYeast, yeastName: "Instant Yeast"
        )

        let result = try PrefermentTool.addPreferment(preferment, to: base, removingYeastNamed: nil)
        let calculated = try Calculator.shared.calculate(recipe: result)

        let finalYeast = calculated.ingredients.first { $0.name == "Instant Yeast" }
        XCTAssertNotNil(finalYeast)
        XCTAssertGreaterThanOrEqual(finalYeast?.weight ?? -1, 0)
    }
}
