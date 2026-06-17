//
//  CalculatorOverridesTests.swift
//  Doughy Tests
//

import XCTest
@testable import Doughy

final class CalculatorOverridesTests: XCTestCase {

    func testHasAnyOverrideReflectsEveryOverrideKind() {
        XCTAssertFalse(overrides().hasAnyOverride)
        XCTAssertTrue(overrides(ingredientPercents: [1: 75]).hasAnyOverride)
        XCTAssertTrue(overrides(ingredientWeights: [1: 200]).hasAnyOverride)
        XCTAssertTrue(overrides(ingredientTemps: [1: 78]).hasAnyOverride)
        XCTAssertTrue(overrides(prefermentIngredientPercents: [1: 90]).hasAnyOverride)
        XCTAssertTrue(overrides(prefermentIngredientWeights: [1: 120]).hasAnyOverride)
        XCTAssertTrue(overrides(prefermentTotalPercent: 45).hasAnyOverride)
        XCTAssertTrue(overrides(singleDoughWeight: 1100).hasAnyOverride)
        XCTAssertTrue(overrides(extraIngredientAmounts: [2: 3]).hasAnyOverride)
    }

    func testApplyingOverridesToPercentPrefermentRecipeUpdatesSnapshot() throws {
        let recipe = percentPrefermentRecipe()
        let snapshot = overrides(
            ingredientPercents: [1: 76],
            ingredientTemps: [1: 78, 1001: 70],
            prefermentIngredientPercents: [1: 90],
            prefermentTotalPercent: 45,
            singleDoughWeight: 1100,
            extraIngredientAmounts: [2: 3],
            temperatureMeasurement: .fahrenheit
        ).applied(to: recipe)

        XCTAssertEqual(snapshot.defaultWeight, 1100)
        XCTAssertEqual(snapshot.ingredients[1].defaultPercentage, 76)
        XCTAssertEqual(snapshot.ingredients[1].temperatureValue, 78)
        XCTAssertEqual(snapshot.ingredients[1].temperatureMeasurement, Temperature.Measurement.fahrenheit.rawValue)
        XCTAssertEqual(snapshot.ingredients[2].extraAmount, 3)

        let preferment = try XCTUnwrap(snapshot.preferment)
        XCTAssertEqual(preferment.flourPercentage, 45)
        XCTAssertEqual(preferment.ingredients[1].defaultPercentage, 90)
        XCTAssertEqual(preferment.ingredients[1].temperatureValue, 70)
        XCTAssertEqual(preferment.ingredients[1].temperatureMeasurement, Temperature.Measurement.fahrenheit.rawValue)
    }

    func testApplyingWeightOverridesRecomputesWeightRecipeDefaultWeight() {
        let recipe = Recipe(
            name: "Chocolate Sauce",
            collection: "Tests",
            defaultWeight: 360,
            ingredients: [
                Ingredient(name: "Chocolate", isFlour: false, defaultPercentage: 0, temperature: nil, defaultWeight: 200),
                Ingredient(name: "Cream", isFlour: false, defaultPercentage: 0, temperature: nil, defaultWeight: 150),
                Ingredient(name: "Salt", isFlour: false, defaultPercentage: 0, temperature: nil, defaultWeight: 10),
                Ingredient(name: "Vanilla", isFlour: false, defaultPercentage: 0, temperature: nil, extraAmount: 1, extraUnit: "teaspoon")
            ],
            instructions: [],
            measurementMode: .weight
        )

        let snapshot = overrides(ingredientWeights: [0: 250, 1: 175]).applied(to: recipe)

        XCTAssertEqual(snapshot.measurementMode, .weight)
        XCTAssertEqual(snapshot.ingredients.map(\.defaultWeight), [250, 175, 10, nil])
        XCTAssertEqual(snapshot.defaultWeight, 435)
    }

    private func percentPrefermentRecipe() -> PrefermentRecipe {
        PrefermentRecipe(
            name: "Poolish Loaf",
            collection: "Tests",
            defaultWeight: 1000,
            ingredients: [
                Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 100, temperature: nil),
                Ingredient(name: "Water", isFlour: false, defaultPercentage: 70, temperature: nil),
                Ingredient(name: "Rosemary", isFlour: false, defaultPercentage: 0, temperature: nil, extraAmount: 2, extraUnit: "tablespoon")
            ],
            preferment: Preferment(
                name: "Poolish",
                flourPercentage: 40,
                ingredients: [
                    Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 100, temperature: nil),
                    Ingredient(name: "Water", isFlour: false, defaultPercentage: 100, temperature: nil)
                ]
            ),
            instructions: []
        )
    }

    private func overrides(
        ingredientPercents: [Int: Double] = [:],
        ingredientWeights: [Int: Double] = [:],
        ingredientTemps: [Int: Double] = [:],
        prefermentIngredientPercents: [Int: Double] = [:],
        prefermentIngredientWeights: [Int: Double] = [:],
        prefermentTotalPercent: Double? = nil,
        singleDoughWeight: Double? = nil,
        extraIngredientAmounts: [Int: Double] = [:],
        temperatureMeasurement: Temperature.Measurement = .fahrenheit
    ) -> CalculatorOverrides {
        CalculatorOverrides(
            ingredientPercents: ingredientPercents,
            ingredientWeights: ingredientWeights,
            ingredientTemps: ingredientTemps,
            prefermentIngredientPercents: prefermentIngredientPercents,
            prefermentIngredientWeights: prefermentIngredientWeights,
            prefermentTotalPercent: prefermentTotalPercent,
            singleDoughWeight: singleDoughWeight,
            extraIngredientAmounts: extraIngredientAmounts,
            temperatureMeasurement: temperatureMeasurement
        )
    }
}
