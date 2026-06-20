//
//  RecipeFile.swift
//  Doughy

import Foundation

// MARK: - File payload (the on-disk JSON envelope)

struct RecipeFilePayload: Codable, Identifiable, Equatable {
    var id: String { recipe.name }
    let version: Int
    let author: String?
    let note: String?
    let recipe: RecipeFileData
}

struct RecipeLibraryBackup: Codable, Equatable {
    let version: Int
    let type: String
    let exportedAt: Date
    let recipes: [RecipeFilePayload]
}

struct RecipeFileData: Codable, Equatable {
    let name: String
    let collection: String
    let defaultWeight: Double
    let measurementMode: RecipeMeasurementMode?
    let ingredients: [IngredientFileData]
    let preferment: PrefermentFileData?
    let instructions: [String]

    init(from recipe: any RecipeProtocol) {
        name = recipe.name
        collection = recipe.collection
        defaultWeight = recipe.defaultWeight
        measurementMode = recipe.measurementMode
        ingredients = recipe.ingredients.map { IngredientFileData(from: $0) }
        preferment = (recipe as? PrefermentRecipe).map { PrefermentFileData(from: $0.preferment) }
        instructions = recipe.instructions.map { $0.step }
    }
}

struct IngredientFileData: Codable, Equatable {
    let name: String
    let isFlour: Bool
    let defaultPercentage: Double
    let defaultWeight: Double?
    let temperatureValue: Double?
    let temperatureUnit: String?   // "celsius" or "fahrenheit"
    let extraAmount: Double?
    let extraUnit: String?

    init(from ingredient: Ingredient) {
        name = ingredient.name
        isFlour = ingredient.isFlour
        defaultPercentage = ingredient.defaultPercentage
        defaultWeight = ingredient.defaultWeight
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
                          temperature: temp, defaultWeight: defaultWeight,
                          extraAmount: extraAmount, extraUnit: extraUnit)
    }
}

struct PrefermentFileData: Codable, Equatable {
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

    static func payload(from recipe: any RecipeProtocol, author: String?, note: String? = nil) -> RecipeFilePayload {
        let trimmedAuthor = author?.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note?.trimmingCharacters(in: .whitespaces)
        return RecipeFilePayload(
            version: 2,
            author: trimmedAuthor.flatMap { $0.isEmpty ? nil : $0 },
            note: trimmedNote.flatMap { $0.isEmpty ? nil : $0 },
            recipe: RecipeFileData(from: recipe)
        )
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
                                    preferment: pref.toPreferment(), instructions: instructions,
                                    measurementMode: data.measurementMode ?? .percent)
        }
        return Recipe(name: data.name, collection: collection,
                      defaultWeight: data.defaultWeight, ingredients: ingredients,
                      instructions: instructions,
                      measurementMode: data.measurementMode ?? .percent)
    }
}

enum RecipeLibraryBackupFile {
    static let fileExtension = "doughylibrary"
    static let type = "doughy.recipe-library"
    private static let version = 1

    static func backup(from recipes: [any RecipeProtocol]) -> RecipeLibraryBackup {
        RecipeLibraryBackup(
            version: version,
            type: type,
            exportedAt: Date(),
            recipes: recipes.map { RecipeFile.payload(from: $0, author: nil) }
        )
    }

    static func write(_ backup: RecipeLibraryBackup) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: backup.exportedAt)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Doughy Library Backup \(dateString)")
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func load(from url: URL) -> RecipeLibraryBackup? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RecipeLibraryBackup.self, from: data)
    }
}
