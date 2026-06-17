//
//  CalculatorTests.swift
//  Doughy Tests
//

import XCTest
@testable import Doughy

final class CalculatorTests: XCTestCase {

    private let calculator = Calculator.shared

    private func flour(_ name: String = "Bread Flour", percent: Double = 100, weight: Double? = nil) -> Ingredient {
        Ingredient(name: name, isFlour: true, defaultPercentage: percent, temperature: nil, defaultWeight: weight)
    }

    private func ingredient(
        _ name: String,
        percent: Double,
        temperature: Temperature? = nil,
        weight: Double? = nil,
        extraAmount: Double? = nil,
        extraUnit: String? = nil
    ) -> Ingredient {
        Ingredient(
            name: name,
            isFlour: false,
            defaultPercentage: percent,
            temperature: temperature,
            defaultWeight: weight,
            extraAmount: extraAmount,
            extraUnit: extraUnit
        )
    }

    func testPercentRecipeWeightsSumToTotalAndPreservePercentages() throws {
        let recipe = Recipe(
            name: "Simple Loaf",
            collection: "Tests",
            defaultWeight: 1000,
            ingredients: [
                flour(),
                ingredient("Water", percent: 70),
                ingredient("Salt", percent: 2)
            ],
            instructions: []
        )

        let result = try calculator.calculate(recipe: recipe)

        XCTAssertEqual(result.weight, 1000, accuracy: 0.0001)
        XCTAssertEqual(result.ingredients.reduce(0) { $0 + $1.weight }, 1000, accuracy: 0.0001)
        XCTAssertEqual(result.ingredients.first { $0.name == "Bread Flour" }?.percentage ?? 0, 100, accuracy: 0.0001)
        XCTAssertEqual(result.ingredients.first { $0.name == "Water" }?.percentage ?? 0, 70, accuracy: 0.0001)
        XCTAssertEqual(result.ingredients.first { $0.name == "Salt" }?.percentage ?? 0, 2, accuracy: 0.0001)

        let flourWeight = 1000.0 * 100.0 / 172.0
        XCTAssertEqual(result.ingredients.first { $0.name == "Bread Flour" }?.weight ?? 0, flourWeight, accuracy: 0.0001)
    }

    func testWeightRecipeUsesIngredientWeightsAndScalesByRequestedTotal() throws {
        let recipe = Recipe(
            name: "Ganache",
            collection: "Tests",
            defaultWeight: 360,
            ingredients: [
                ingredient("Chocolate", percent: 0, weight: 200),
                ingredient("Cream", percent: 0, weight: 150),
                ingredient("Salt", percent: 0, weight: 10)
            ],
            instructions: [],
            measurementMode: .weight
        )
        let measured = recipe.ingredients.map { MeasuredIngredient(ingredient: $0, percent: $0.defaultPercentage, temperature: $0.temperature, weight: $0.defaultWeight) }

        let result = try calculator.calculate(ingredients: measured, preferment: nil, recipe: recipe, totalWeight: 720)

        XCTAssertEqual(result.weight, 720, accuracy: 0.0001)
        XCTAssertEqual(result.ingredients.first { $0.name == "Chocolate" }?.weight ?? 0, 400, accuracy: 0.0001)
        XCTAssertEqual(result.ingredients.first { $0.name == "Cream" }?.weight ?? 0, 300, accuracy: 0.0001)
        XCTAssertEqual(result.ingredients.first { $0.name == "Salt" }?.weight ?? 0, 20, accuracy: 0.0001)
    }

    func testExtraIngredientAmountsScaleWithBatchSize() throws {
        let recipe = Recipe(
            name: "Rosemary Loaf",
            collection: "Tests",
            defaultWeight: 500,
            ingredients: [
                flour(),
                ingredient("Water", percent: 70),
                ingredient("Rosemary", percent: 0, extraAmount: 2, extraUnit: "tablespoon")
            ],
            instructions: []
        )
        let measured = recipe.ingredients.map { MeasuredIngredient(ingredient: $0, percent: $0.defaultPercentage, temperature: $0.temperature) }

        let result = try calculator.calculate(ingredients: measured, preferment: nil, recipe: recipe, totalWeight: 1500)

        let rosemary = try XCTUnwrap(result.ingredients.first { $0.name == "Rosemary" })
        XCTAssertEqual(rosemary.extraAmount ?? 0, 6, accuracy: 0.0001)
        XCTAssertEqual(rosemary.extraUnit, "tablespoon")
    }

    func testPrefermentRecipeComputesPrefermentWeightAndSharedTotals() throws {
        let preferment = Preferment(
            name: "Poolish",
            flourPercentage: 50,
            ingredients: [
                flour(percent: 100),
                ingredient("Water", percent: 100),
                ingredient("Yeast", percent: 0.5)
            ]
        )
        let recipe = PrefermentRecipe(
            name: "Poolish Loaf",
            collection: "Tests",
            defaultWeight: 1000,
            ingredients: [
                flour(),
                ingredient("Water", percent: 70),
                ingredient("Salt", percent: 2)
            ],
            preferment: preferment,
            instructions: []
        )

        let result = try XCTUnwrap(try calculator.calculate(recipe: recipe) as? CalculatedPrefermentRecipe)

        let totalFlourWeight = result.ingredients.filter(\.isFlour).reduce(0) { $0 + $1.weight }
        XCTAssertEqual(result.preferment.ingredients.first { $0.isFlour }?.weight ?? 0, totalFlourWeight * 0.5, accuracy: 0.0001)

        let doughWater = try XCTUnwrap(result.ingredients.first { $0.name == "Water" })
        let prefermentWater = try XCTUnwrap(result.preferment.ingredients.first { $0.name == "Water" })
        XCTAssertEqual(doughWater.totalPercentage, prefermentWater.totalPercentage, accuracy: 0.0001)
        XCTAssertLessThan(doughWater.percentage, doughWater.totalPercentage)
    }

    func testPrefermentThatExceedsFinalDoughThrows() {
        let preferment = Preferment(
            name: "Poolish",
            flourPercentage: 50,
            ingredients: [flour(percent: 100), ingredient("Water", percent: 100)]
        )
        let recipe = PrefermentRecipe(
            name: "Impossible Loaf",
            collection: "Tests",
            defaultWeight: 1000,
            ingredients: [flour(), ingredient("Water", percent: 30)],
            preferment: preferment,
            instructions: []
        )

        XCTAssertThrowsError(try calculator.calculate(recipe: recipe)) { error in
            guard case CalculationError.finalDoughNegativeValue(let name, _) = error else {
                return XCTFail("Expected final dough negative value, got \(error)")
            }
            XCTAssertEqual(name, "Water")
        }
    }
}
