//
//  RecipeFile.swift
//  Doughy

import Foundation

// MARK: - File payload (the on-disk JSON envelope)

struct RecipeFilePayload: Codable, Identifiable {
    var id: String { recipe.name }
    let version: Int
    let author: String?
    let recipe: RecipeFileData
}

struct RecipeFileData: Codable {
    let name: String
    let collection: String
    let defaultWeight: Double
    let ingredients: [IngredientFileData]
    let preferment: PrefermentFileData?
    let instructions: [String]

    init(from recipe: any RecipeProtocol) {
        name = recipe.name
        collection = recipe.collection
        defaultWeight = recipe.defaultWeight
        ingredients = recipe.ingredients.map { IngredientFileData(from: $0) }
        preferment = (recipe as? PrefermentRecipe).map { PrefermentFileData(from: $0.preferment) }
        instructions = recipe.instructions.map { $0.step }
    }
}

struct IngredientFileData: Codable {
    let name: String
    let isFlour: Bool
    let defaultPercentage: Double
    let temperatureValue: Double?
    let temperatureUnit: String?   // "celsius" or "fahrenheit"
    let extraAmount: Double?
    let extraUnit: String?

    init(from ingredient: Ingredient) {
        name = ingredient.name
        isFlour = ingredient.isFlour
        defaultPercentage = ingredient.defaultPercentage
        temperatureValue = ingredient.temperature?.value
        temperatureUnit = ingredient.temperature?.measurement.rawValue
        extraAmount = ingredient.extraAmount
        extraUnit = ingredient.extraUnit
    }

    func toIngredient() -> Ingredient {
        let temp: Temperature?
        if let value = temperatureValue,
           let unitStr = temperatureUnit,
           let measurement = Temperature.Measurement(rawValue: unitStr) {
            temp = Temperature(value: value, measurement: measurement)
        } else {
            temp = nil
        }
        return Ingredient(name: name, isFlour: isFlour, defaultPercentage: defaultPercentage,
                          temperature: temp, extraAmount: extraAmount, extraUnit: extraUnit)
    }
}

struct PrefermentFileData: Codable {
    let name: String
    let flourPercentage: Double
    let ingredients: [IngredientFileData]

    init(from preferment: Preferment) {
        name = preferment.name
        flourPercentage = preferment.flourPercentage
        ingredients = preferment.ingredients.map { IngredientFileData(from: $0) }
    }

    func toPreferment() -> Preferment {
        Preferment(name: name, flourPercentage: flourPercentage,
                   ingredients: ingredients.map { $0.toIngredient() })
    }
}

// MARK: - File utilities

enum RecipeFile {
    static let fileExtension = "doughy"
    static let uti = "org.georgie.doughy.recipe"

    static func payload(from recipe: any RecipeProtocol, author: String?) -> RecipeFilePayload {
        let trimmed = author?.trimmingCharacters(in: .whitespaces)
        return RecipeFilePayload(version: 1,
                                 author: trimmed.flatMap { $0.isEmpty ? nil : $0 },
                                 recipe: RecipeFileData(from: recipe))
    }

    /// Encodes `payload` and writes it to a uniquely-named temp file. Returns the URL.
    static func write(_ payload: RecipeFilePayload) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(payload)
        let safeName = payload.recipe.name
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?*"))
            .joined(separator: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Reads and decodes a `.doughy` file at `url`. Returns `nil` on any failure.
    static func load(from url: URL) -> RecipeFilePayload? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RecipeFilePayload.self, from: data)
    }

    /// Reconstructs a `RecipeProtocol` from `data`, placing it in `collection`.
    static func toRecipe(_ data: RecipeFileData, collection: String) -> any RecipeProtocol {
        let ingredients = data.ingredients.map { $0.toIngredient() }
        let instructions = data.instructions.map { Instruction(step: $0) }
        if let pref = data.preferment {
            return PrefermentRecipe(name: data.name, collection: collection,
                                    defaultWeight: data.defaultWeight, ingredients: ingredients,
                                    preferment: pref.toPreferment(), instructions: instructions)
        }
        return Recipe(name: data.name, collection: collection,
                      defaultWeight: data.defaultWeight, ingredients: ingredients,
                      instructions: instructions)
    }
}
