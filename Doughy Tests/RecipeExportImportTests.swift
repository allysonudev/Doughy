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

    func testExportImportPreservesRecipeSourceURL() throws {
        let sourceURL = URL(string: "https://example.com/focaccia")!
        let recipe = Recipe(name: recipeName, collection: collection, defaultWeight: defaultWeight,
                            ingredients: [Ingredient(name: flour, isFlour: true, defaultPercentage: 100, temperature: nil)],
                            instructions: [instruction1],
                            sourceURL: sourceURL)
        let payload = RecipeFile.payload(from: recipe, author: user_name)

        let data = try JSONEncoder().encode(payload)
        let imported = try JSONDecoder().decode(RecipeFilePayload.self, from: data)
        let importedRecipe = RecipeFile.toRecipe(imported.recipe, collection: imported.recipe.collection)

        XCTAssertEqual(imported.recipe.sourceURL, sourceURL.absoluteString)
        XCTAssertEqual(importedRecipe.sourceURL, sourceURL)
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

    // MARK: - Corrupted / non-recipe .doughy input

    func testMalformedJSONThrowsRatherThanCrashing() {
        let malformed = Data("{ this is not valid json ".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(RecipeFilePayload.self, from: malformed))
    }

    func testEmptyDataThrowsRatherThanCrashing() {
        XCTAssertThrowsError(try JSONDecoder().decode(RecipeFilePayload.self, from: Data()))
    }

    func testValidJSONWithWrongSchemaThrows() {
        // Well-formed JSON, but it's not a recipe document at all (missing every
        // required key) - should fail decoding, not silently produce a garbage payload.
        let wrongSchema = Data("""
        { "hello": "world", "count": 42 }
        """.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(RecipeFilePayload.self, from: wrongSchema))
    }

    func testValidRecipeJSONMissingRequiredFieldThrows() {
        // Has the right shape but the recipe is missing `defaultWeight`, a required field.
        let missingField = Data("""
        {
          "version": 2,
          "recipe": {
            "name": "Broken Recipe",
            "collection": "Legacy",
            "ingredients": [
              { "name": "Bread Flour", "isFlour": true, "defaultPercentage": 100 }
            ],
            "instructions": ["Mix"]
          }
        }
        """.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(RecipeFilePayload.self, from: missingField))
    }

    func testRecipeFileLoadReturnsNilForCorruptedFileInsteadOfCrashing() throws {
        // RecipeFile.load is the app's actual import entry point for a .doughy document
        // URL - it swallows decode failures and returns nil rather than throwing/crashing.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("doughy")
        try Data("not json at all".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNil(RecipeFile.load(from: url))
    }

    func testRecipeFileLoadReturnsNilForEmptyFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("doughy")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNil(RecipeFile.load(from: url))
    }

    // MARK: - Importing a duplicate-named recipe

    /// Importing a `.doughy` file whose recipe name/collection already exists in the
    /// library is the same code path as saving a new recipe with a colliding name:
    /// `RecipeWriter.writeRecipe` (which `RecipeStore.save` delegates to) throws
    /// `recipeExistsDuringWrite` rather than silently renaming or replacing.
    func testImportingDuplicateNamedRecipeThrowsRecipeExistsError() throws {
        try RecipeWriter.shared.replaceLibrary(with: [])
        defer { try? RecipeWriter.shared.replaceLibrary(with: []) }

        let payload = RecipeFile.payload(from: simpleRecipe(), author: user_name)
        let recipe = RecipeFile.toRecipe(payload.recipe, collection: payload.recipe.collection)

        try RecipeWriter.shared.writeRecipe(recipe: recipe)

        // Importing the exact same name/collection again should throw rather than
        // silently overwrite or duplicate.
        XCTAssertThrowsError(try RecipeWriter.shared.writeRecipe(recipe: recipe)) { error in
            guard case RecipeWritingError.recipeExistsDuringWrite = error else {
                return XCTFail("Expected recipeExistsDuringWrite, got \(error)")
            }
        }
        XCTAssertEqual(RecipeReader.shared.getRecipes(collection: payload.recipe.collection).count, 1)
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

    func testLibraryBackupPreservesRecipeSourceURL() throws {
        let sourceURL = URL(string: "https://example.com/focaccia")!
        let recipe = Recipe(name: recipeName, collection: collection, defaultWeight: defaultWeight,
                            ingredients: [Ingredient(name: flour, isFlour: true, defaultPercentage: 100, temperature: nil)],
                            instructions: [instruction1],
                            sourceURL: sourceURL)
        let backup = RecipeLibraryBackupFile.backup(from: [recipe])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode(RecipeLibraryBackup.self, from: try encoder.encode(backup))

        XCTAssertEqual(imported.recipes.first?.recipe.sourceURL, sourceURL.absoluteString)
    }

    func testLibraryBackupRoundTripsUserState() throws {
        let userState = RecipeLibraryUserState(
            settings: Settings.BackupData(preferredLanguageCode: "de",
                                          preferredVolumeSystem: VolumeSystem.metric.rawValue,
                                          prefersCelsius: true),
            ingredientDensities: IngredientDensityStore.BackupData(
                densityOverrides: ["breadFlour": 130],
                displayUnits: ["breadFlour": "cup"],
                eggOverrides: ["large_whole": 52],
                defaultEggSize: "jumbo",
                hiddenCategories: ["cakeFlour"]
            ),
            ingredientConversions: IngredientConversionStore.BackupData(
                conversions: ["rosemary leaves|tablespoon": 1.7],
                alwaysExtra: ["sesame seeds|pinch"],
                entryGroups: ["rosemary leaves|tablespoon": IngredientCategoryGroup.other.rawValue]
            ),
            recipes: RecipeStore.BackupData(
                recentRecipeShortcuts: [RecentRecipeShortcut(collection: "Pizza", name: "New York Pizza")],
                lastRecipeAddedCollection: "Pizza",
                recentlyDeletedRecipes: nil,
                recipeOrder: RecipeOrder(collections: ["Pizza": ["New York Pizza", "Margherita"]])
            )
        )
        let backup = RecipeLibraryBackupFile.backup(from: [simpleRecipe()], userState: userState)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let imported = try decoder.decode(RecipeLibraryBackup.self, from: try encoder.encode(backup))

        XCTAssertEqual(imported.userState, userState)
    }

    func testCustomEmojiIconKeyResolvesToEmojiGlyph() throws {
        let key = try XCTUnwrap(CollectionIconCatalog.customEmojiKey(for: " 🌯 "))
        let icon = try XCTUnwrap(CollectionIconCatalog.icon(for: key))

        XCTAssertEqual(key, "emoji:🌯")
        XCTAssertEqual(icon.key, key)
        if case .emoji(let value) = icon.glyph {
            XCTAssertEqual(value, "🌯")
        } else {
            XCTFail("Expected custom emoji key to resolve to an emoji glyph.")
        }
        XCTAssertNil(CollectionIconCatalog.customEmojiKey(for: "AB"))
        XCTAssertNil(CollectionIconCatalog.customEmojiKey(for: "1"))
    }

    func testCollectionAppearanceStoreRemembersRecentCustomEmojiIcons() throws {
        let suiteName = "CollectionAppearanceStoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = CollectionAppearanceStore(userDefaults: defaults, cloudStore: nil)
        store.rememberEmojiIcon("🌯")
        store.rememberEmojiIcon("🥟")
        store.rememberEmojiIcon("🌯")
        store.rememberEmojiIcon("1")

        XCTAssertEqual(store.recentEmojiIconKeys, ["emoji:🌯", "emoji:🥟"])

        let reloaded = CollectionAppearanceStore(userDefaults: defaults, cloudStore: nil)
        XCTAssertEqual(reloaded.recentEmojiIconKeys, ["emoji:🌯", "emoji:🥟"])
    }

    func testCollectionAppearanceStoreRestoresAppearancesFromCloudAfterReinstall() throws {
        let firstInstallSuite = "CollectionAppearanceStoreTests-\(UUID().uuidString)"
        let firstInstallDefaults = try XCTUnwrap(UserDefaults(suiteName: firstInstallSuite))
        let cloudStore = TestCollectionAppearanceKeyValueStore()
        defer { firstInstallDefaults.removePersistentDomain(forName: firstInstallSuite) }

        let firstInstall = CollectionAppearanceStore(userDefaults: firstInstallDefaults,
                                                     cloudStore: cloudStore)
        firstInstall.set(CollectionAppearance(iconKey: "emoji:🌯", colorKey: "mint"), for: "Wraps")

        let reinstallSuite = "CollectionAppearanceStoreTests-\(UUID().uuidString)"
        let reinstallDefaults = try XCTUnwrap(UserDefaults(suiteName: reinstallSuite))
        defer { reinstallDefaults.removePersistentDomain(forName: reinstallSuite) }

        let reinstalled = CollectionAppearanceStore(userDefaults: reinstallDefaults,
                                                    cloudStore: cloudStore)

        XCTAssertEqual(reinstalled.appearance(for: "Wraps").iconKey, "emoji:🌯")
        XCTAssertEqual(reinstalled.appearance(for: "Wraps").colorKey, "mint")
    }

    func testCollectionAppearanceStoreMirrorsRecentEmojiIconsToCloud() throws {
        let firstInstallSuite = "CollectionAppearanceStoreTests-\(UUID().uuidString)"
        let firstInstallDefaults = try XCTUnwrap(UserDefaults(suiteName: firstInstallSuite))
        let cloudStore = TestCollectionAppearanceKeyValueStore()
        defer { firstInstallDefaults.removePersistentDomain(forName: firstInstallSuite) }

        let firstInstall = CollectionAppearanceStore(userDefaults: firstInstallDefaults,
                                                     cloudStore: cloudStore)
        firstInstall.rememberEmojiIcon("🌯")

        let reinstallSuite = "CollectionAppearanceStoreTests-\(UUID().uuidString)"
        let reinstallDefaults = try XCTUnwrap(UserDefaults(suiteName: reinstallSuite))
        defer { reinstallDefaults.removePersistentDomain(forName: reinstallSuite) }

        let reinstalled = CollectionAppearanceStore(userDefaults: reinstallDefaults,
                                                    cloudStore: cloudStore)

        XCTAssertEqual(reinstalled.recentEmojiIconKeys, ["emoji:🌯"])
    }

    func testIngredientConversionStoreRestoresFromCloudAfterReinstall() throws {
        let firstInstallSuite = "IngredientConversionStoreTests-\(UUID().uuidString)"
        let firstInstallDefaults = try XCTUnwrap(UserDefaults(suiteName: firstInstallSuite))
        let cloudStore = TestCollectionAppearanceKeyValueStore()
        defer { firstInstallDefaults.removePersistentDomain(forName: firstInstallSuite) }

        let firstInstall = IngredientConversionStore(userDefaults: firstInstallDefaults, cloudStore: cloudStore)
        firstInstall.save(name: "Rosemary Leaves", unit: "tablespoon", gramsPerUnit: 1.7, group: .other)
        firstInstall.markAsExtra(name: "Sesame Seeds", unit: "pinch")

        let reinstallSuite = "IngredientConversionStoreTests-\(UUID().uuidString)"
        let reinstallDefaults = try XCTUnwrap(UserDefaults(suiteName: reinstallSuite))
        defer { reinstallDefaults.removePersistentDomain(forName: reinstallSuite) }

        let reinstalled = IngredientConversionStore(userDefaults: reinstallDefaults, cloudStore: cloudStore)

        XCTAssertEqual(reinstalled.gramsPerUnit(name: "rosemary leaves", unit: "tablespoon"), 1.7)
        XCTAssertTrue(reinstalled.isAlwaysExtra(name: "sesame seeds", unit: "pinch"))
        XCTAssertEqual(reinstalled.allEntries().first?.group, .other)
    }

    func testIngredientDensityStoreRestoresFromCloudAfterReinstall() throws {
        let firstInstallSuite = "IngredientDensityStoreTests-\(UUID().uuidString)"
        let firstInstallDefaults = try XCTUnwrap(UserDefaults(suiteName: firstInstallSuite))
        let cloudStore = TestCollectionAppearanceKeyValueStore()
        defer { firstInstallDefaults.removePersistentDomain(forName: firstInstallSuite) }

        let firstInstall = IngredientDensityStore(userDefaults: firstInstallDefaults, cloudStore: cloudStore)
        firstInstall.setGramsPerCup(130, for: .breadFlour)
        firstInstall.setDisplayUnit(.cup, for: .breadFlour)
        firstInstall.setGramsPerEgg(52, for: .large)
        firstInstall.setDefaultEggSize(.jumbo)
        firstInstall.hide(category: .cakeFlour)

        let reinstallSuite = "IngredientDensityStoreTests-\(UUID().uuidString)"
        let reinstallDefaults = try XCTUnwrap(UserDefaults(suiteName: reinstallSuite))
        defer { reinstallDefaults.removePersistentDomain(forName: reinstallSuite) }

        let reinstalled = IngredientDensityStore(userDefaults: reinstallDefaults, cloudStore: cloudStore)

        XCTAssertEqual(reinstalled.gramsPerCup(for: .breadFlour), 130)
        XCTAssertEqual(reinstalled.displayUnit(for: .breadFlour), .cup)
        XCTAssertEqual(reinstalled.gramsPerEgg(for: .large), 52)
        XCTAssertEqual(reinstalled.defaultEggSize(), .jumbo)
        XCTAssertTrue(reinstalled.hiddenCategories().contains(.cakeFlour))
    }

    func testIngredientDensityStoreResetAllToDefaultsRestoresEveryDefault() throws {
        let suiteName = "IngredientDensityStoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let cloudStore = TestCollectionAppearanceKeyValueStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = IngredientDensityStore(userDefaults: defaults, cloudStore: cloudStore)

        // Change several values/units/egg weights away from their defaults.
        let defaultBreadFlourGramsPerCup = store.gramsPerCup(for: .breadFlour)
        let defaultBreadFlourDisplayUnit = store.displayUnit(for: .breadFlour)
        let defaultLargeEggGrams = store.gramsPerEgg(for: .large)
        let defaultEggSize = store.defaultEggSize()

        store.setGramsPerCup(999, for: .breadFlour)
        store.setDisplayUnit(.deciliter, for: .breadFlour)
        store.setGramsPerEgg(12, for: .large)
        store.setDefaultEggSize(.jumbo)
        store.hide(category: .cakeFlour)

        XCTAssertTrue(store.isCustomized(.breadFlour))
        XCTAssertTrue(store.isCustomized(.large))
        XCTAssertTrue(store.hiddenCategories().contains(.cakeFlour))
        XCTAssertNotEqual(store.defaultEggSize(), defaultEggSize)

        store.resetAllToDefaults()

        // Every customization is gone: values fall back to their hard-coded defaults.
        XCTAssertFalse(store.isCustomized(.breadFlour))
        XCTAssertFalse(store.isCustomized(.large))
        XCTAssertEqual(store.gramsPerCup(for: .breadFlour), defaultBreadFlourGramsPerCup)
        XCTAssertEqual(store.displayUnit(for: .breadFlour), defaultBreadFlourDisplayUnit)
        XCTAssertEqual(store.gramsPerEgg(for: .large), defaultLargeEggGrams)
        XCTAssertEqual(store.defaultEggSize(), defaultEggSize)
        XCTAssertTrue(store.hiddenCategories().isEmpty)

        // backupData() reports nothing left to back up once everything is default again.
        XCTAssertNil(store.backupData())
    }
}

private final class TestCollectionAppearanceKeyValueStore: DoughyKeyValueStore {
    private var values: [String: Any] = [:]

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func dictionary(forKey defaultName: String) -> [String: Any]? {
        values[defaultName] as? [String: Any]
    }

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }

    func stringArray(forKey defaultName: String) -> [String]? {
        values[defaultName] as? [String]
    }

    func synchronize() -> Bool {
        true
    }
}
