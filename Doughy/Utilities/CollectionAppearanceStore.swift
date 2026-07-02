//
//  CollectionAppearanceStore.swift
//  Doughy

import Foundation
import Observation

protocol DoughyKeyValueStore: AnyObject {
    func data(forKey defaultName: String) -> Data?
    func dictionary(forKey defaultName: String) -> [String: Any]?
    func string(forKey defaultName: String) -> String?
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
    func stringArray(forKey defaultName: String) -> [String]?
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: DoughyKeyValueStore {
    func stringArray(forKey defaultName: String) -> [String]? {
        array(forKey: defaultName) as? [String]
    }
}

/// Persists each collection's appearance (icon + color), keyed by collection name and
/// stored separately from the recipes themselves. Backed by UserDefaults for fast local
/// launches and mirrored to iCloud key-value storage so collection identity survives an
/// app reinstall alongside the CloudKit-backed recipes.
@Observable
class CollectionAppearanceStore {
    private var appearances: [String: CollectionAppearance]
    private(set) var recentEmojiIconKeys: [String]

    @ObservationIgnored private let key = "collectionAppearances"
    @ObservationIgnored private let recentEmojiIconKeysKey = "recentCollectionEmojiIconKeys"
    @ObservationIgnored private let seedFlagKey = "didSeedDefaultCollectionAppearances"
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let cloudStore: DoughyKeyValueStore?
    @ObservationIgnored private var cloudChangeObserver: NSObjectProtocol?
    @ObservationIgnored private let maxRecentEmojiIcons = 12

    /// One-time appearance seed for the collections Doughy ships by default, keyed by their
    /// stored (English) name. Seeded as real stored values, not a name-based heuristic, so
    /// collections the user later creates are unaffected.
    private static let defaultSeed: [String: CollectionAppearance] = [
        "Pizza": CollectionAppearance(iconKey: "pizza", colorKey: "deepOrange"),
        "Bagels": CollectionAppearance(iconKey: "bagel", colorKey: "amber"),
    ]

    init(userDefaults: UserDefaults = .standard,
         cloudStore: DoughyKeyValueStore? = NSUbiquitousKeyValueStore.default) {
        self.userDefaults = userDefaults
        self.cloudStore = cloudStore
        _ = cloudStore?.synchronize()

        let cloudAppearances = Self.loadAppearances(from: cloudStore?.data(forKey: key))
        let localAppearances = Self.loadAppearances(from: userDefaults.data(forKey: key))
        appearances = cloudAppearances.merging(localAppearances) { _, local in local }

        let cloudRecent = cloudStore?.stringArray(forKey: recentEmojiIconKeysKey) ?? []
        let localRecent = userDefaults.stringArray(forKey: recentEmojiIconKeysKey) ?? []
        recentEmojiIconKeys = Self.mergedRecentEmojiKeys(primary: localRecent, fallback: cloudRecent)

        if let ubiquitousStore = cloudStore as? NSUbiquitousKeyValueStore {
            cloudChangeObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: ubiquitousStore,
                queue: .main
            ) { [weak self] _ in
                self?.mergeCloudChanges()
            }
        }
        seedDefaultAppearancesIfNeeded()
        persist()
    }

    deinit {
        if let cloudChangeObserver {
            NotificationCenter.default.removeObserver(cloudChangeObserver)
        }
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

    func rememberEmojiIcon(_ emoji: String) {
        guard let key = CollectionIconCatalog.customEmojiKey(for: emoji) else { return }
        rememberEmojiIconKey(key)
    }

    func rememberEmojiIconKey(_ key: String) {
        guard CollectionIconCatalog.customEmoji(from: key) != nil else { return }
        var updated = recentEmojiIconKeys.filter { $0 != key }
        updated.insert(key, at: 0)
        recentEmojiIconKeys = Array(updated.prefix(maxRecentEmojiIcons))
        persistRecentEmojiIconKeys()
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
        cloudStore?.set(data, forKey: key)
        _ = cloudStore?.synchronize()
    }

    private func persistRecentEmojiIconKeys() {
        userDefaults.set(recentEmojiIconKeys, forKey: recentEmojiIconKeysKey)
        cloudStore?.set(recentEmojiIconKeys, forKey: recentEmojiIconKeysKey)
        _ = cloudStore?.synchronize()
    }

    private func mergeCloudChanges() {
        guard let cloudStore else { return }
        _ = cloudStore.synchronize()

        let cloudAppearances = Self.loadAppearances(from: cloudStore.data(forKey: key))
        var didChange = false
        for (collection, appearance) in cloudAppearances where appearances[collection] != appearance {
            appearances[collection] = appearance
            didChange = true
        }

        let mergedRecent = Self.mergedRecentEmojiKeys(
            primary: recentEmojiIconKeys,
            fallback: cloudStore.stringArray(forKey: recentEmojiIconKeysKey) ?? []
        )
        if mergedRecent != recentEmojiIconKeys {
            recentEmojiIconKeys = mergedRecent
            didChange = true
        }

        guard didChange else { return }
        persistLocalOnly()
    }

    private func persistLocalOnly() {
        guard let data = try? JSONEncoder().encode(appearances) else { return }
        userDefaults.set(data, forKey: key)
        userDefaults.set(recentEmojiIconKeys, forKey: recentEmojiIconKeysKey)
    }

    private static func loadAppearances(from data: Data?) -> [String: CollectionAppearance] {
        guard let data,
              let decoded = try? JSONDecoder().decode([String: CollectionAppearance].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func mergedRecentEmojiKeys(primary: [String], fallback: [String]) -> [String] {
        var result: [String] = []
        for key in primary + fallback
        where CollectionIconCatalog.customEmoji(from: key) != nil && !result.contains(key) {
            result.append(key)
        }
        return Array(result.prefix(12))
    }
}
