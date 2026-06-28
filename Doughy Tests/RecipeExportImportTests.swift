//
//  RecipeExportImportTests.swift
//  Doughy
//
//  Created by Allyson Urick on 6/17/26.
//  Copyright © 2026 Allyson Urick. All rights reserved.
//

@testable import Doughy
import XCTest

final class DoughyFileRoundTripTests: XCTestCase {
    
    let recipeName = "Focaccia"
    let collection = "Yummy Bread"
    let user_name = "curiousurick"
    let defaultWeight: Double = 800
    let flour = "Bread Flour"
    let flourPerc:Double = 100
    let water = "Water"
    let waterPerc: Double = 75
    let waterTemp = Temperature(value: 95, measurement: .fahrenheit)
    let salt = "Fine Sea Salt"
    let saltPerc: Double = 2.3
    let oliveOil = "Olive Oil"
    let oliveOilPerc: Double = 10
    let yeast = "Instant Yeast"
    let yeastPerc: Double = 0.5
    
    let preferment = "Poolish"
    let prefermentFlourPerc: Double = 50
    
    let instruction1 = Instruction(step: "Knead the dough")
    let instruction2 = Instruction(step: "Proof the dough")
    let instruction3 = Instruction(step: "Shape the dough")
    let instruction4 = Instruction(step: "Bake the dough")
    
    func testExportImportRecipePreservesDocumentExactly() throws {
        
        let recipe = Recipe(
            name: recipeName, collection: collection, defaultWeight: defaultWeight, ingredients: [
                Ingredient(name: flour, isFlour: true, defaultPercentage: 100, temperature: nil),
                Ingredient(name: water, isFlour: false, defaultPercentage: waterPerc, temperature: waterTemp),
                Ingredient(name: salt, isFlour: false, defaultPercentage: saltPerc, temperature: nil),
                Ingredient(name: oliveOil, isFlour: false, defaultPercentage: oliveOilPerc, temperature: nil),
                Ingredient(name: yeast, isFlour: false, defaultPercentage: yeastPerc, temperature: nil),
            ], instructions: [instruction1, instruction2, instruction3, instruction4])
        
        // Arrange
        let original = RecipeFile.payload(from: recipe, author: user_name)
        
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        
        let originalData = try encoder.encode(original)
        
        // Export
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("doughy")
        
        try originalData.write(to: url)
        
        // Import
        let importedData = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        let imported = try decoder.decode(
            RecipeFilePayload.self,
            from: importedData
        )
        
        // Assert object equality
        XCTAssertEqual(original, imported)
        
        // Assert raw bytes equality
        XCTAssertEqual(originalData, importedData)
    }
    
    func testExportImportPrefermentRecipePreservesDocumentExactly() throws {
        
        let recipe = PrefermentRecipe(
            name: recipeName, collection: collection, defaultWeight: defaultWeight, ingredients: [
                Ingredient(name: flour, isFlour: true, defaultPercentage: flourPerc, temperature: nil),
                Ingredient(name: water, isFlour: false, defaultPercentage: waterPerc, temperature: waterTemp),
                Ingredient(name: salt, isFlour: false, defaultPercentage: saltPerc, temperature: nil),
                Ingredient(name: oliveOil, isFlour: false, defaultPercentage: oliveOilPerc, temperature: nil),
                Ingredient(name: yeast, isFlour: false, defaultPercentage: yeastPerc, temperature: nil),
            ],
            preferment: Preferment(
                name: preferment, flourPercentage: prefermentFlourPerc, ingredients: [
                    Ingredient(name: flour, isFlour: true, defaultPercentage: flourPerc, temperature: nil),
                    Ingredient(name: water, isFlour: false, defaultPercentage: waterPerc, temperature: waterTemp),
                    Ingredient(name: yeast, isFlour: false, defaultPercentage: yeastPerc, temperature: nil)
                ]),
            instructions: [instruction1, instruction2, instruction3, instruction4])
        
        // Arrange
        let original = RecipeFile.payload(from: recipe, author: user_name)
        
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        
        let originalData = try encoder.encode(original)
        
        // Export
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("doughy")
        
        try originalData.write(to: url)
        
        // Import
        let importedData = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        let imported = try decoder.decode(
            RecipeFilePayload.self,
            from: importedData
        )
        
        // Assert object equality
        XCTAssertEqual(original, imported)
        
        // Assert raw bytes equality
        XCTAssertEqual(originalData, importedData)
    }

    func testExportImportWeightRecipePreservesModeAndIngredientWeights() throws {
        let recipe = Recipe(
            name: "Chocolate Sauce",
            collection: collection,
            defaultWeight: 360,
            ingredients: [
                Ingredient(name: "Chocolate", isFlour: false, defaultPercentage: 0, temperature: nil, defaultWeight: 200),
                Ingredient(name: "Cream", isFlour: false, defaultPercentage: 0, temperature: nil, defaultWeight: 150),
                Ingredient(name: "Salt", isFlour: false, defaultPercentage: 0, temperature: nil, defaultWeight: 10)
            ],
            instructions: [instruction1],
            measurementMode: .weight)

        let payload = RecipeFile.payload(from: recipe, author: user_name)
        let imported = RecipeFile.toRecipe(payload.recipe, collection: payload.recipe.collection)

        XCTAssertEqual(payload.version, 2)
        XCTAssertEqual(payload.recipe.measurementMode, RecipeMeasurementMode.weight)
        XCTAssertEqual(imported.measurementMode, RecipeMeasurementMode.weight)
        XCTAssertEqual(imported.ingredients.map { $0.defaultWeight }, [200, 150, 10])
    }

    private func simpleRecipe() -> Recipe {
        Recipe(name: recipeName, collection: collection, defaultWeight: defaultWeight,
               ingredients: [Ingredient(name: flour, isFlour: true, defaultPercentage: 100, temperature: nil)],
               instructions: [instruction1])
    }

    func testExportImportPreservesCollectionAppearance() throws {
        let appearance = CollectionAppearance(iconKey: "pizza", colorKey: "deepOrange")
        let original = RecipeFile.payload(from: simpleRecipe(), author: user_name,
                                          collectionAppearance: appearance)

        let data = try JSONEncoder().encode(original)
        let imported = try JSONDecoder().decode(RecipeFilePayload.self, from: data)

        XCTAssertEqual(original, imported)
        XCTAssertEqual(imported.collectionAppearance, appearance)
        XCTAssertEqual(imported.collectionAppearance?.iconKey, "pizza")
        XCTAssertEqual(imported.collectionAppearance?.colorKey, "deepOrange")
    }

    func testEmptyAppearanceIsTreatedAsNoneAndOmittedFromJSON() throws {
        // An empty appearance (no icon, no color) should not be written, and an icon-only
        // appearance should omit the absent color key (encodeIfPresent on optionals).
        let emptyPayload = RecipeFile.payload(from: simpleRecipe(), author: user_name,
                                              collectionAppearance: CollectionAppearance())
        XCTAssertNil(emptyPayload.collectionAppearance)

        let iconOnly = RecipeFile.payload(from: simpleRecipe(), author: user_name,
                                          collectionAppearance: CollectionAppearance(iconKey: "bagel"))
        let json = String(data: try JSONEncoder().encode(iconOnly), encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"iconKey\":\"bagel\""))
        XCTAssertFalse(json.contains("colorKey"))
    }

    func testLegacyDocumentWithoutAppearanceDecodesToNil() throws {
        // A .doughy written before appearances existed must still import (field absent → nil).
        let legacy = """
        {
          "version": 2,
          "recipe": {
            "name": "Old Recipe",
            "collection": "Legacy",
            "defaultWeight": 500,
            "ingredients": [
              { "name": "Bread Flour", "isFlour": true, "defaultPercentage": 100 }
            ],
            "instructions": ["Mix"]
          }
        }
        """
        let imported = try JSONDecoder().decode(RecipeFilePayload.self, from: Data(legacy.utf8))

        XCTAssertNil(imported.collectionAppearance)
        XCTAssertEqual(imported.recipe.name, "Old Recipe")
        XCTAssertEqual(imported.recipe.collection, "Legacy")
    }

    func testLibraryBackupRoundTripsCollectionAppearances() throws {
        let appearances = [
            "Pizza": CollectionAppearance(iconKey: "pizza", colorKey: "deepOrange"),
            "Bagels": CollectionAppearance(iconKey: "bagel", colorKey: "amber"),
        ]
        let backup = RecipeLibraryBackupFile.backup(from: [simpleRecipe()], appearances: appearances)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode(RecipeLibraryBackup.self, from: try encoder.encode(backup))

        XCTAssertEqual(imported.collections, appearances)
    }
}
