//
//  RecipeSnapshotTests.swift
//  Doughy Tests
//

import XCTest
@testable import Doughy

final class RecipeSnapshotTests: XCTestCase {

    func testSnapshotCapturesAndRestoresEditableRecipeFields() throws {
        let recipe = PrefermentRecipe(
            name: "Original Name",
            collection: "Original Collection",
            defaultWeight: 875,
            ingredients: [
                Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 80, temperature: nil),
                Ingredient(name: "Whole Wheat Flour", isFlour: true, defaultPercentage: 20, temperature: nil),
                Ingredient(name: "Water", isFlour: false, defaultPercentage: 72.5, temperature: Temperature(value: 78, measurement: .fahrenheit)),
                Ingredient(name: "Rosemary", isFlour: false, defaultPercentage: 0, temperature: nil, extraAmount: 2, extraUnit: "tablespoon")
            ],
            preferment: Preferment(
                name: "Levain",
                flourPercentage: 25,
                ingredients: [
                    Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 100, temperature: nil),
                    Ingredient(name: "Water", isFlour: false, defaultPercentage: 100, temperature: Temperature(value: 23, measurement: .celsius))
                ]
            ),
            instructions: [Instruction(step: "Autolyse."), Instruction(step: "Bake.")],
            measurementMode: .weight
        )

        let restored = RecipeSnapshot(from: recipe).makeRecipe(name: "Restored Name", collection: "Restored Collection")
        let restoredPreferment = try XCTUnwrap(restored as? PrefermentRecipe)

        XCTAssertEqual(restored.name, "Restored Name")
        XCTAssertEqual(restored.collection, "Restored Collection")
        XCTAssertEqual(restored.defaultWeight, recipe.defaultWeight)
        XCTAssertEqual(restored.measurementMode, .weight)
        assertIngredientsEqual(restored.ingredients, recipe.ingredients)
        XCTAssertEqual(restored.instructions.map(\.step), recipe.instructions.map(\.step))
        XCTAssertEqual(restoredPreferment.preferment.name, recipe.preferment.name)
        XCTAssertEqual(restoredPreferment.preferment.flourPercentage, recipe.preferment.flourPercentage)
        assertIngredientsEqual(restoredPreferment.preferment.ingredients, recipe.preferment.ingredients)
    }

    func testInvalidTemperatureMeasurementIsDroppedRatherThanCrashing() throws {
        let data = try XCTUnwrap("""
        {
          "defaultWeight": 500,
          "measurementMode": "percent",
          "ingredients": [
            {
              "name": "Water",
              "isFlour": false,
              "defaultPercentage": 70,
              "temperatureValue": 78,
              "temperatureMeasurement": "kelvin"
            }
          ],
          "instructions": []
        }
        """.data(using: .utf8))

        let snapshot = try JSONDecoder().decode(RecipeSnapshot.self, from: data)
        let recipe = snapshot.makeRecipe(name: "Restored", collection: "Tests")
        let ingredient = try XCTUnwrap(recipe.ingredients.first)

        XCTAssertEqual(ingredient.name, "Water")
        XCTAssertNil(ingredient.temperature)
    }

    private func assertIngredientsEqual(_ lhs: [Ingredient], _ rhs: [Ingredient], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)
        for (left, right) in zip(lhs, rhs) {
            XCTAssertEqual(left.name, right.name, file: file, line: line)
            XCTAssertEqual(left.isFlour, right.isFlour, file: file, line: line)
            XCTAssertEqual(left.defaultPercentage, right.defaultPercentage, file: file, line: line)
            XCTAssertEqual(left.defaultWeight, right.defaultWeight, file: file, line: line)
            XCTAssertEqual(left.temperature?.value, right.temperature?.value, file: file, line: line)
            XCTAssertEqual(left.temperature?.measurement, right.temperature?.measurement, file: file, line: line)
            XCTAssertEqual(left.extraAmount, right.extraAmount, file: file, line: line)
            XCTAssertEqual(left.extraUnit, right.extraUnit, file: file, line: line)
        }
    }
}
