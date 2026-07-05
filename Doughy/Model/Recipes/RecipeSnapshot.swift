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
    var measurementMode: RecipeMeasurementMode
    var ingredients: [IngredientSnapshot]
    var instructions: [String]
    var preferment: PrefermentSnapshot?
    var sourceURL: String?

    enum CodingKeys: String, CodingKey {
        case defaultWeight, measurementMode, ingredients, instructions, preferment, sourceURL
    }

    init(from recipe: any RecipeProtocol) {
        defaultWeight = recipe.defaultWeight
        measurementMode = recipe.measurementMode
        ingredients = recipe.ingredients.map(IngredientSnapshot.init)
        instructions = recipe.instructions.map(\.step)
        preferment = (recipe as? PrefermentRecipe).map { PrefermentSnapshot(from: $0.preferment) }
        sourceURL = recipe.sourceURL?.absoluteString
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultWeight = try container.decode(Double.self, forKey: .defaultWeight)
        measurementMode = try container.decodeIfPresent(RecipeMeasurementMode.self, forKey: .measurementMode) ?? .percent
        ingredients = try container.decode([IngredientSnapshot].self, forKey: .ingredients)
        instructions = try container.decode([String].self, forKey: .instructions)
        preferment = try container.decodeIfPresent(PrefermentSnapshot.self, forKey: .preferment)
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
    }

    /// Reconstructs a recipe model from this snapshot, using the given
    /// `name`/`collection` (which the snapshot itself doesn't carry).
    func makeRecipe(name: String, collection: String) -> any RecipeProtocol {
        let ingredientModels = ingredients.map { $0.makeIngredient() }
        let instructionModels = instructions.map { Instruction(step: $0) }
        let sourceURL = sourceURL.flatMap(URL.init(string:))

        if let preferment {
            return PrefermentRecipe(name: name, collection: collection, defaultWeight: defaultWeight,
                                     ingredients: ingredientModels, preferment: preferment.makePreferment(),
                                     instructions: instructionModels,
                                     measurementMode: measurementMode,
                                     sourceURL: sourceURL)
        }
        return Recipe(name: name, collection: collection, defaultWeight: defaultWeight,
                       ingredients: ingredientModels, instructions: instructionModels,
                       measurementMode: measurementMode,
                       sourceURL: sourceURL)
    }
}

struct IngredientSnapshot: Codable, Equatable {
    var name: String
    var isFlour: Bool
    var defaultPercentage: Double
    var defaultWeight: Double?
    var temperatureValue: Double?
    var temperatureMeasurement: String?
    var extraAmount: Double?
    var extraUnit: String?

    enum CodingKeys: String, CodingKey {
        case name, isFlour, defaultPercentage, defaultWeight, temperatureValue, temperatureMeasurement, extraAmount, extraUnit
    }

    init(_ ingredient: Ingredient) {
        name = ingredient.name
        isFlour = ingredient.isFlour
        defaultPercentage = ingredient.defaultPercentage
        defaultWeight = ingredient.defaultWeight
        temperatureValue = ingredient.temperature?.value
        temperatureMeasurement = ingredient.temperature?.measurement.rawValue
        extraAmount = ingredient.extraAmount
        extraUnit = ingredient.extraUnit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        isFlour = try container.decode(Bool.self, forKey: .isFlour)
        defaultPercentage = try container.decode(Double.self, forKey: .defaultPercentage)
        defaultWeight = try container.decodeIfPresent(Double.self, forKey: .defaultWeight)
        temperatureValue = try container.decodeIfPresent(Double.self, forKey: .temperatureValue)
        temperatureMeasurement = try container.decodeIfPresent(String.self, forKey: .temperatureMeasurement)
        extraAmount = try container.decodeIfPresent(Double.self, forKey: .extraAmount)
        extraUnit = try container.decodeIfPresent(String.self, forKey: .extraUnit)
    }

    func makeIngredient() -> Ingredient {
        var temperature: Temperature?
        if let value = temperatureValue,
           let measurement = temperatureMeasurement.flatMap(Temperature.Measurement.init) {
            temperature = Temperature(value: value, measurement: measurement)
        }
        return Ingredient(name: name, isFlour: isFlour, defaultPercentage: defaultPercentage,
                           temperature: temperature, defaultWeight: defaultWeight,
                           extraAmount: extraAmount, extraUnit: extraUnit)
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
