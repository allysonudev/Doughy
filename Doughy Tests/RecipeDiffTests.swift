//
//  RecipeDiffTests.swift
//  Doughy Tests
//

import XCTest
@testable import Doughy

final class RecipeDiffTests: XCTestCase {

    private func makeRecipe(
        defaultWeight: Double = 1000,
        ingredients: [Ingredient]? = nil,
        instructions: [Instruction] = [Instruction(step: "Mix everything together.")]
    ) -> Recipe {
        let defaultIngredients = [
            Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 100, temperature: nil),
            Ingredient(name: "Water", isFlour: false, defaultPercentage: 70,
                       temperature: Temperature(value: 75, measurement: .fahrenheit)),
            Ingredient(name: "Salt", isFlour: false, defaultPercentage: 2, temperature: nil),
        ]
        return Recipe(name: "Test Loaf", collection: "Test Collection", defaultWeight: defaultWeight,
                       ingredients: ingredients ?? defaultIngredients, instructions: instructions)
    }

    private func makePrefermentRecipe(flourPercentage: Double = 20, prefermentIngredients: [Ingredient]? = nil) -> PrefermentRecipe {
        let recipe = makeRecipe()
        let defaultPrefermentIngredients = [
            Ingredient(name: "Bread Flour", isFlour: true, defaultPercentage: 100, temperature: nil),
            Ingredient(name: "Water", isFlour: false, defaultPercentage: 100, temperature: nil),
        ]
        let preferment = Preferment(name: "Starter", flourPercentage: flourPercentage,
                                     ingredients: prefermentIngredients ?? defaultPrefermentIngredients)
        return PrefermentRecipe(name: recipe.name, collection: recipe.collection, defaultWeight: recipe.defaultWeight,
                                 ingredients: recipe.ingredients, preferment: preferment, instructions: recipe.instructions)
    }

    // MARK: - No changes

    func testNoChangesReturnsNil() {
        let snapshot = RecipeSnapshot(from: makeRecipe())
        XCTAssertNil(RecipeDiff.summarize(from: snapshot, to: snapshot))
    }

    func testIdenticalPrefermentRecipesReturnNil() {
        let snapshot = RecipeSnapshot(from: makePrefermentRecipe())
        XCTAssertNil(RecipeDiff.summarize(from: snapshot, to: snapshot))
    }

    // MARK: - Ingredient changes

    func testIngredientPercentageChange() {
        let old = RecipeSnapshot(from: makeRecipe())
        var new = old
        new.ingredients[2].defaultPercentage = 2.2

        XCTAssertEqual(RecipeDiff.summarize(from: old, to: new), "Salt: 2% → 2.2%")
    }

    func testIngredientTemperatureChange() {
        let old = RecipeSnapshot(from: makeRecipe())
        var new = old
        new.ingredients[1].temperatureValue = 78

        XCTAssertEqual(RecipeDiff.summarize(from: old, to: new), "Water temp: 75º F → 78º F")
    }

    func testAddedIngredient() {
        let old = RecipeSnapshot(from: makeRecipe())
        var new = old
        new.ingredients.append(IngredientSnapshot(Ingredient(name: "Honey", isFlour: false, defaultPercentage: 5, temperature: nil)))

        XCTAssertEqual(RecipeDiff.summarize(from: old, to: new), "+ Added Honey")
    }

    func testRemovedIngredient() {
        let old = RecipeSnapshot(from: makeRecipe())
        var new = old
        new.ingredients.removeLast()

        XCTAssertEqual(RecipeDiff.summarize(from: old, to: new), "- Removed Salt")
    }

    // MARK: - Weight changes

    func testDefaultWeightChange() {
        let old = RecipeSnapshot(from: makeRecipe(defaultWeight: 350))
        let new = RecipeSnapshot(from: makeRecipe(defaultWeight: 400))

        XCTAssertEqual(RecipeDiff.summarize(from: old, to: new), "Weight: 350g → 400g")
    }

    // MARK: - Instructions

    func testInstructionsChange() {
        let old = RecipeSnapshot(from: makeRecipe(instructions: [Instruction(step: "Mix.")]))
        let new = RecipeSnapshot(from: makeRecipe(instructions: [Instruction(step: "Mix thoroughly.")]))

        XCTAssertEqual(RecipeDiff.summarize(from: old, to: new), "Instructions updated")
    }

    // MARK: - Preferment changes

    func testPrefermentFlourPercentageChange() {
        let old = RecipeSnapshot(from: makePrefermentRecipe(flourPercentage: 20))
        let new = RecipeSnapshot(from: makePrefermentRecipe(flourPercentage: 25))

        XCTAssertEqual(RecipeDiff.summarize(from: old, to: new), "Starter flour: 20% → 25%")
    }

    func testAddedPreferment() {
        let old = RecipeSnapshot(from: makeRecipe())
        let new = RecipeSnapshot(from: makePrefermentRecipe())

        XCTAssertEqual(RecipeDiff.summarize(from: old, to: new), "+ Added preferment")
    }

    func testRemovedPreferment() {
        let old = RecipeSnapshot(from: makePrefermentRecipe())
        let new = RecipeSnapshot(from: makeRecipe())

        XCTAssertEqual(RecipeDiff.summarize(from: old, to: new), "- Removed preferment")
    }
}
