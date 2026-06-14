//
//  IngredientConversionStore.swift
//  Doughy
//

import Foundation

/// Persists user-provided gram conversions for "weird" ingredients (e.g. "rosemary
/// leaves" -> grams per tablespoon) so future scans can convert them automatically.
class IngredientConversionStore: NSObject {

    static let shared = IngredientConversionStore()

    private let userDefaults = UserDefaults.standard
    private let storageKey = "ingredientConversionStoreKey"
    private let extraStorageKey = "ingredientConversionStoreExtraKey"

    private override init() { super.init() }

    private func key(name: String, unit: String) -> String {
        "\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(unit.lowercased())"
    }

    private var conversions: [String: Double] {
        get { userDefaults.dictionary(forKey: storageKey) as? [String: Double] ?? [:] }
        set { userDefaults.set(newValue, forKey: storageKey) }
    }

    private var alwaysExtra: Set<String> {
        get { Set(userDefaults.array(forKey: extraStorageKey) as? [String] ?? []) }
        set { userDefaults.set(Array(newValue), forKey: extraStorageKey) }
    }

    /// Returns the learned grams-per-unit conversion for the given ingredient name and
    /// unit (e.g. "rosemary leaves" + "tablespoon"), if one has been provided before.
    func gramsPerUnit(name: String, unit: String) -> Double? {
        conversions[key(name: name, unit: unit)]
    }

    /// Saves a grams-per-unit conversion for future scans.
    func save(name: String, unit: String, gramsPerUnit: Double) {
        var current = conversions
        current[key(name: name, unit: unit)] = gramsPerUnit
        conversions = current
    }

    /// Returns whether the user previously chose to keep this ingredient/unit in its
    /// original unit, so future scans should skip the conversion prompt for it.
    func isAlwaysExtra(name: String, unit: String) -> Bool {
        alwaysExtra.contains(key(name: name, unit: unit))
    }

    /// Remembers that this ingredient/unit should always be kept as an "extra"
    /// ingredient in its original unit, without prompting again.
    func markAsExtra(name: String, unit: String) {
        var current = alwaysExtra
        current.insert(key(name: name, unit: unit))
        alwaysExtra = current
    }
}
