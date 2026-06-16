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
    private let groupStorageKey = "ingredientConversionGroupKey"

    private override init() { super.init() }

    private func key(name: String, unit: String) -> String {
        "\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(unit.lowercased())"
    }

    private var conversions: [String: Double] {
        get { userDefaults.dictionary(forKey: storageKey) as? [String: Double] ?? [:] }
        set { userDefaults.set(newValue, forKey: storageKey) }
    }

    private var entryGroups: [String: String] {
        get { userDefaults.dictionary(forKey: groupStorageKey) as? [String: String] ?? [:] }
        set { userDefaults.set(newValue, forKey: groupStorageKey) }
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
    /// Pass `group` when adding manually from the settings UI so the entry appears in the right section.
    func save(name: String, unit: String, gramsPerUnit: Double, group: IngredientCategoryGroup? = nil) {
        let k = key(name: name, unit: unit)
        var current = conversions
        current[k] = gramsPerUnit
        conversions = current
        if let group = group {
            var currentGroups = entryGroups
            currentGroups[k] = group.rawValue
            entryGroups = currentGroups
        }
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

    /// A user-saved volume-to-weight conversion entry.
    struct ConversionEntry: Identifiable {
        var id: String  // compound "name|unit" key
        var name: String
        var unit: String
        var gramsPerUnit: Double
        /// Set when the entry was added manually from a specific section in Settings.
        /// Nil for entries learned automatically during scanning.
        var group: IngredientCategoryGroup?
    }

    /// All user-saved gram conversions, sorted by name.
    func allEntries() -> [ConversionEntry] {
        let groupsDict = entryGroups
        return conversions.compactMap { compoundKey, grams in
            let parts = compoundKey.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            let group = groupsDict[compoundKey].flatMap { IngredientCategoryGroup(rawValue: $0) }
            return ConversionEntry(id: compoundKey, name: parts[0], unit: parts[1], gramsPerUnit: grams, group: group)
        }.sorted { $0.name < $1.name }
    }

    /// Removes a user-saved conversion.
    func delete(name: String, unit: String) {
        let k = key(name: name, unit: unit)
        var current = conversions
        current.removeValue(forKey: k)
        conversions = current
        var currentGroups = entryGroups
        currentGroups.removeValue(forKey: k)
        entryGroups = currentGroups
    }
}
