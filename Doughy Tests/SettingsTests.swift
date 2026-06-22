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

    private var savedVolume: Any?
    private var savedLanguage: Any?
    private var savedAppleLanguages: Any?

    override func setUp() {
        super.setUp()
        savedVolume = defaults.object(forKey: volumeKey)
        savedLanguage = defaults.object(forKey: languageKey)
        savedAppleLanguages = defaults.object(forKey: appleLanguagesKey)
    }

    override func tearDown() {
        restore(savedVolume, forKey: volumeKey)
        restore(savedLanguage, forKey: languageKey)
        restore(savedAppleLanguages, forKey: appleLanguagesKey)
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
