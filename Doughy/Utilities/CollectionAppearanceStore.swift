//
//  CollectionAppearanceStore.swift
//  Doughy

import Foundation
import Observation

/// Persists each collection's appearance (icon + color), keyed by collection name and
/// stored separately from the recipes themselves. Backed by UserDefaults (JSON), and
/// `@Observable` so avatars update immediately when an appearance changes.
@Observable
class CollectionAppearanceStore {
    private var appearances: [String: CollectionAppearance]

    @ObservationIgnored private let key = "collectionAppearances"
    @ObservationIgnored private let seedFlagKey = "didSeedDefaultCollectionAppearances"
    @ObservationIgnored private let userDefaults: UserDefaults

    /// One-time appearance seed for the collections Doughy ships by default, keyed by their
    /// stored (English) name. Seeded as real stored values, not a name-based heuristic, so
    /// collections the user later creates are unaffected.
    private static let defaultSeed: [String: CollectionAppearance] = [
        "Pizza": CollectionAppearance(iconKey: "pizza", colorKey: "deepOrange"),
        "Bagels": CollectionAppearance(iconKey: "bagel", colorKey: "amber"),
    ]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: CollectionAppearance].self, from: data) {
            appearances = decoded
        } else {
            appearances = [:]
        }
        seedDefaultAppearancesIfNeeded()
    }

    /// Seeds the default-collection appearances exactly once. Skips any collection that
    /// already has an appearance, so it never clobbers a user's choice.
    private func seedDefaultAppearancesIfNeeded() {
        guard !userDefaults.bool(forKey: seedFlagKey) else { return }
        for (name, appearance) in Self.defaultSeed where appearances[name] == nil {
            appearances[name] = appearance
        }
        persist()
        userDefaults.set(true, forKey: seedFlagKey)
    }

    func appearance(for collection: String) -> CollectionAppearance {
        appearances[collection] ?? .none
    }

    /// All stored appearances, keyed by collection name (for library backup/export).
    func allAppearances() -> [String: CollectionAppearance] {
        appearances
    }

    func setIcon(_ iconKey: String?, for collection: String) {
        var current = appearances[collection] ?? .none
        current.iconKey = iconKey
        set(current, for: collection)
    }

    func setColor(_ colorKey: String?, for collection: String) {
        var current = appearances[collection] ?? .none
        current.colorKey = colorKey
        set(current, for: collection)
    }

    func set(_ appearance: CollectionAppearance, for collection: String) {
        appearances[collection] = appearance.isEmpty ? nil : appearance
        persist()
    }

    /// Moves a collection's appearance to a new name (used when a collection is renamed).
    /// If the destination already has an appearance, it is kept (merge target wins).
    func rename(from oldName: String, to newName: String) {
        guard oldName != newName, let moved = appearances[oldName] else { return }
        appearances[oldName] = nil
        if appearances[newName] == nil {
            appearances[newName] = moved
        }
        persist()
    }

    /// Removes appearance entries for collections that no longer exist, so renamed,
    /// merged, or emptied collections don't leave orphaned metadata behind.
    func cleanupOrphans(validNames: Set<String>) {
        let removed = appearances.keys.filter { !validNames.contains($0) }
        guard !removed.isEmpty else { return }
        for name in removed { appearances[name] = nil }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(appearances) else { return }
        userDefaults.set(data, forKey: key)
    }
}
