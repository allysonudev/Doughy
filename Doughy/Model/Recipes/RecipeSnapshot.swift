//
//  RecipeSnapshot.swift
//  Doughy
//

import Foundation

/// A `Codable` snapshot of a recipe's tweakable data, used for the Recipe
/// History feature. Deliberately excludes `name`/`collection` - renames
/// aren't tracked by history, and a snapshot is always restored onto the
/// recipe it was taken from.
struct RecipeSnapshot: Codable, Equatable {
    var defaultWeight: Double
    var ingredients: [IngredientSnapshot]
    var instructions: [String]
    var preferment: PrefermentSnapshot?

    init(from recipe: any RecipeProtocol) {
        defaultWeight = recipe.defaultWeight
        ingredients = recipe.ingredients.map(IngredientSnapshot.init)
        instructions = recipe.instructions.map(\.step)
        preferment = (recipe as? PrefermentRecipe).map { PrefermentSnapshot(from: $0.preferment) }
    }

    /// Reconstructs a recipe model from this snapshot, using the given
    /// `name`/`collection` (which the snapshot itself doesn't carry).
    func makeRecipe(name: String, collection: String) -> any RecipeProtocol {
        let ingredientModels = ingredients.map { $0.makeIngredient() }
        let instructionModels = instructions.map { Instruction(step: $0) }

        if let preferment {
            return PrefermentRecipe(name: name, collection: collection, defaultWeight: defaultWeight,
                                     ingredients: ingredientModels, preferment: preferment.makePreferment(),
                                     instructions: instructionModels)
        }
        return Recipe(name: name, collection: collection, defaultWeight: defaultWeight,
                       ingredients: ingredientModels, instructions: instructionModels)
    }
}

struct IngredientSnapshot: Codable, Equatable {
    var name: String
    var isFlour: Bool
    var defaultPercentage: Double
    var temperatureValue: Double?
    var temperatureMeasurement: String?
    var extraAmount: Double?
    var extraUnit: String?

    init(_ ingredient: Ingredient) {
        name = ingredient.name
        isFlour = ingredient.isFlour
        defaultPercentage = ingredient.defaultPercentage
        temperatureValue = ingredient.temperature?.value
        temperatureMeasurement = ingredient.temperature?.measurement.rawValue
        extraAmount = ingredient.extraAmount
        extraUnit = ingredient.extraUnit
    }

    func makeIngredient() -> Ingredient {
        var temperature: Temperature?
        if let value = temperatureValue,
           let measurement = temperatureMeasurement.flatMap(Temperature.Measurement.init) {
            temperature = Temperature(value: value, measurement: measurement)
        }
        return Ingredient(name: name, isFlour: isFlour, defaultPercentage: defaultPercentage,
                           temperature: temperature, extraAmount: extraAmount, extraUnit: extraUnit)
    }
}

struct PrefermentSnapshot: Codable, Equatable {
    var name: String
    var flourPercentage: Double
    var ingredients: [IngredientSnapshot]

    init(from preferment: Preferment) {
        name = preferment.name
        flourPercentage = preferment.flourPercentage
        ingredients = preferment.ingredients.map(IngredientSnapshot.init)
    }

    func makePreferment() -> Preferment {
        Preferment(name: name, flourPercentage: flourPercentage, ingredients: ingredients.map { $0.makeIngredient() })
    }
}
