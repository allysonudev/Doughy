//
//  SettingsTests.swift
//  Doughy Tests
//
//  Round-trip coverage for the user preferences that back the Settings screen:
//  volume system and in-app language. `Settings` reads/writes UserDefaults.standard,
//  so each test saves and restores the keys it touches to stay side-effect-free.
//

import XCTest
@testable import Doughy

final class SettingsTests: XCTestCase {

    private let defaults = UserDefaults.standard
    private let volumeKey = Settings.preferredVolumeSystemKey
    private let languageKey = Settings.preferredLanguageKey
    private let appleLanguagesKey = "AppleLanguages"
    private let onboardingVersionKey = Settings.lastOnboardingVersionKey

    private var savedVolume: Any?
    private var savedLanguage: Any?
    private var savedAppleLanguages: Any?
    private var savedOnboardingVersion: Any?

    override func setUp() {
        super.setUp()
        savedVolume = defaults.object(forKey: volumeKey)
        savedLanguage = defaults.object(forKey: languageKey)
        savedAppleLanguages = defaults.object(forKey: appleLanguagesKey)
        savedOnboardingVersion = defaults.object(forKey: onboardingVersionKey)
    }

    override func tearDown() {
        restore(savedVolume, forKey: volumeKey)
        restore(savedLanguage, forKey: languageKey)
        restore(savedAppleLanguages, forKey: appleLanguagesKey)
        restore(savedOnboardingVersion, forKey: onboardingVersionKey)
        super.tearDown()
    }

    private func restore(_ value: Any?, forKey key: String) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    // MARK: - Volume system

    func testVolumeSystemRoundTrips() {
        Settings.shared.setPreferredVolumeSystem(.imperial)
        XCTAssertEqual(Settings.shared.preferredVolumeSystem(), .imperial)

        Settings.shared.setPreferredVolumeSystem(.metric)
        XCTAssertEqual(Settings.shared.preferredVolumeSystem(), .metric)
    }

    func testVolumeSystemFallsBackToRegionDefaultWhenUnset() {
        defaults.removeObject(forKey: volumeKey)
        let expected: VolumeSystem = Locale.current.region?.identifier == "US" ? .imperial : .metric
        XCTAssertEqual(Settings.shared.preferredVolumeSystem(), expected)
    }

    func testVolumeSystemRawValuesAreStable() {
        // The raw strings are persisted to UserDefaults, so changing them would silently
        // reset existing users' preference. Pin them.
        XCTAssertEqual(VolumeSystem.metric.rawValue, "metric")
        XCTAssertEqual(VolumeSystem.imperial.rawValue, "imperial")
        XCTAssertEqual(VolumeSystem(rawValue: "metric"), .metric)
        XCTAssertEqual(VolumeSystem(rawValue: "imperial"), .imperial)
    }

    // MARK: - Language

    func testLanguageCodeRoundTripsAndUpdatesAppleLanguages() {
        Settings.shared.setPreferredLanguageCode("de")
        XCTAssertEqual(Settings.shared.preferredLanguageCode(), "de")
        // The override must also drive AppleLanguages so the bundle resolves on next launch,
        // with English as the fallback.
        let appleLanguages = defaults.array(forKey: appleLanguagesKey) as? [String]
        XCTAssertEqual(appleLanguages, ["de", "en"])
    }

    func testNilLanguageCodeClearsTheOverride() {
        Settings.shared.setPreferredLanguageCode("ja")
        XCTAssertEqual(Settings.shared.preferredLanguageCode(), "ja")
        XCTAssertEqual(defaults.array(forKey: appleLanguagesKey) as? [String], ["ja", "en"])

        Settings.shared.setPreferredLanguageCode(nil)
        XCTAssertNil(Settings.shared.preferredLanguageCode())
        // AppleLanguages is an OS-managed key: removing our override makes it fall back to the
        // device language list (non-nil), so assert our override is gone rather than nil.
        XCTAssertNotEqual(defaults.array(forKey: appleLanguagesKey) as? [String], ["ja", "en"])
    }

    // MARK: - Onboarding version

    func testLastOnboardingVersionRoundTrips() {
        Settings.shared.setLastOnboardingVersion("1.1")
        XCTAssertEqual(defaults.string(forKey: onboardingVersionKey), "1.1")

        Settings.shared.setLastOnboardingVersion("1.2")
        XCTAssertEqual(defaults.string(forKey: onboardingVersionKey), "1.2")
    }

    // MARK: - Default recipe repair

    func testDuplicateDefaultRecipesAreCollapsedByDefaultKey() throws {
        try withIsolatedRecipeStore {
            let item = DefaultRecipeFactory.shared.createWithKeys()[0]
            insertDefaultRecipe(item)
            insertDefaultRecipe(item)
            try CoreDataGateway.shared.managedObjectConext.save()

            XCTAssertEqual(RecipeReader.shared.getRecipes().count, 2)

            let removed = try RecipeWriter.shared.removeDuplicateDefaultRecipes()
            let remaining = RecipeReader.shared.getRecipes()

            XCTAssertEqual(removed, 1)
            XCTAssertEqual(remaining.count, 1)
            XCTAssertEqual(remaining.first?.value(forKey: "defaultKey") as? String, item.key)
        }
    }

    func testDuplicateDefaultRecipeRepairPreservesEditedDefault() throws {
        try withIsolatedRecipeStore {
            let item = DefaultRecipeFactory.shared.createWithKeys()[0]
            let editedDefault = insertDefaultRecipe(item)
            let note = HistoryEntry(id: UUID(), date: Date(), kind: .note, text: "Keep my tweak")
            editedDefault.addToHistoryEntries(HistoryEntryConverter.shared.convertToCoreData(entry: note))
            insertDefaultRecipe(item)
            try CoreDataGateway.shared.managedObjectConext.save()

            let removed = try RecipeWriter.shared.removeDuplicateDefaultRecipes()
            let remaining = RecipeReader.shared.getRecipes()

            XCTAssertEqual(removed, 1)
            XCTAssertEqual(remaining.count, 1)
            XCTAssertEqual(remaining.first?.historyEntries?.count, 1)
            XCTAssertEqual(remaining.first?.value(forKey: "defaultKey") as? String, item.key)
        }
    }

    func testRefreshingRecipesRepairsDuplicateDefaultsBeforeDisplay() throws {
        try withIsolatedRecipeStore {
            let item = DefaultRecipeFactory.shared.createWithKeys()[0]
            insertDefaultRecipe(item)
            insertDefaultRecipe(item)
            try CoreDataGateway.shared.managedObjectConext.save()

            let recipeCount = Settings.shared.refreshRecipes().flatMap(\.recipes).count

            XCTAssertEqual(recipeCount, 1)
            XCTAssertEqual(RecipeReader.shared.getRecipes().count, 1)
        }
    }

    private func withIsolatedRecipeStore(_ test: () throws -> Void) throws {
        try RecipeWriter.shared.replaceLibrary(with: [])
        defer { restoreDefaultRecipeLibrary() }
        try test()
    }

    @discardableResult
    private func insertDefaultRecipe(_ item: (recipe: RecipeProtocol, key: String)) -> XCRecipe {
        let recipe = RecipeConverter.shared.convertToCoreData(recipe: item.recipe)
        recipe.setValue(item.key, forKey: "defaultKey")
        return recipe
    }

    private func restoreDefaultRecipeLibrary() {
        try? RecipeWriter.shared.replaceLibrary(with: [])
        for item in DefaultRecipeFactory.shared.createWithKeys() {
            try? RecipeWriter.shared.writeDefaultRecipe(recipe: item.recipe, key: item.key)
        }
    }

    // MARK: - DensityUnit.systemDefault

    func testImperialPassesThroughNativeCookingUnits() {
        XCTAssertEqual(DensityUnit.systemDefault(for: .cup,        in: .imperial), .cup)
        XCTAssertEqual(DensityUnit.systemDefault(for: .tablespoon, in: .imperial), .tablespoon)
        XCTAssertEqual(DensityUnit.systemDefault(for: .teaspoon,   in: .imperial), .teaspoon)
    }

    func testImperialMapsMetricUnitsToClosestCookingUnit() {
        // Milliliter is small → teaspoon; deciliter/liter are large → cup.
        XCTAssertEqual(DensityUnit.systemDefault(for: .milliliter, in: .imperial), .teaspoon)
        XCTAssertEqual(DensityUnit.systemDefault(for: .deciliter,  in: .imperial), .cup)
        XCTAssertEqual(DensityUnit.systemDefault(for: .liter,      in: .imperial), .cup)
    }

    func testMetricPassesThroughNativeMetricUnits() {
        XCTAssertEqual(DensityUnit.systemDefault(for: .milliliter, in: .metric), .milliliter)
        XCTAssertEqual(DensityUnit.systemDefault(for: .deciliter,  in: .metric), .deciliter)
        XCTAssertEqual(DensityUnit.systemDefault(for: .liter,      in: .metric), .liter)
    }

    func testMetricMapsImperialUnitsToClosestMetricUnit() {
        // Cup → deciliter; small cooking units (tbsp/tsp) → milliliter.
        XCTAssertEqual(DensityUnit.systemDefault(for: .cup,        in: .metric), .deciliter)
        XCTAssertEqual(DensityUnit.systemDefault(for: .tablespoon, in: .metric), .milliliter)
        XCTAssertEqual(DensityUnit.systemDefault(for: .teaspoon,   in: .metric), .milliliter)
    }
}
