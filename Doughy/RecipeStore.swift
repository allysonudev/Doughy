//
//  RecipeStore.swift
//  Doughy

import Foundation
import CoreData
import Observation
import UIKit

struct RecentRecipeShortcut: Codable, Equatable {
    let collection: String
    let name: String
}

struct RecipeOrder: Codable, Equatable {
    var collections: [String: [String]]

    static let empty = RecipeOrder(collections: [:])

    var isEmpty: Bool {
        collections.values.allSatisfy(\.isEmpty)
    }
}

struct DeletedRecipe: Identifiable, Codable, Equatable {
    let id: UUID
    let deletedAt: Date
    let payload: RecipeFilePayload

    var name: String { payload.recipe.name }
    var collection: String { payload.recipe.collection }
}

@Observable
class RecipeStore {
    private(set) var collections: [RecipeCollection] = []
    private(set) var deletedRecipes: [DeletedRecipe] = []
    var pendingImport: RecipeFilePayload? = nil
    var pendingWebsiteImport: WebsiteRecipeImportRequest? = nil
    var pendingIntentImage: UIImage? = nil
    var pendingShareIntent: PendingShareRequest? = nil
    var pendingOpenIntent: PendingOpenRecipeRequest? = nil
    var pendingScanShortcut = false

    /// True only when the store was created before any default recipes existed —
    /// i.e., this is a genuine first install, not an upgrade from 1.0.
    let isNewInstall: Bool

    private let writer = RecipeWriter.shared
    private let predicates = RecipePredicates.shared
    private let historyWriter = HistoryWriter.shared
    private let recentlyDeletedStore = RecentlyDeletedRecipeStore.shared
    private let recentRecipeShortcutsKey = "recentRecipeShortcuts"
    private let lastRecipeAddedCollectionKey = "lastRecipeAddedCollection"
    private let recipeOrderKey = "recipeOrderByCollection"
    private let cloudStore: DoughyKeyValueStore? = NSUbiquitousKeyValueStore.default
    private let maxRecentRecipeShortcuts = 3
    private var remoteChangeObserver: NSObjectProtocol?

    struct BackupData: Codable, Equatable {
        let recentRecipeShortcuts: [RecentRecipeShortcut]?
        let lastRecipeAddedCollection: String?
        let recentlyDeletedRecipes: [DeletedRecipe]?
        let recipeOrder: RecipeOrder?

        var isEmpty: Bool {
            (recentRecipeShortcuts?.isEmpty ?? true) &&
            lastRecipeAddedCollection == nil &&
            (recentlyDeletedRecipes?.isEmpty ?? true) &&
            (recipeOrder?.isEmpty ?? true)
        }
    }

    init(isNewInstall: Bool = false) {
        self.isNewInstall = isNewInstall
        hydrateUserStateFromCloud()
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: CoreDataGateway.shared.persistentContainer.persistentStoreCoordinator,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        refresh()
        updateRecentRecipeShortcutItems()
    }

    deinit {
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
        }
    }

    func refresh() {
        collections = applySavedRecipeOrder(to: Settings.shared.refreshRecipes())
        deletedRecipes = recentlyDeletedStore.items()
    }

    var collectionNames: [String] {
        collections.map(\.name)
    }

    var defaultCollectionForNewRecipe: String? {
        if let stored = UserDefaults.standard.string(forKey: lastRecipeAddedCollectionKey),
           collections.contains(where: { $0.name == stored }) {
            return stored
        }

        return loadRecentRecipeShortcuts()
            .first { recent in
                collections.contains { $0.name == recent.collection }
            }?
            .collection
    }

    func isNameTaken(_ name: String, excluding existingName: String? = nil) -> Bool {
        if let existing = existingName, name == existing { return false }
        return predicates.isRecipeNameTaken(name: name)
    }

    func delete(recipe: any RecipeProtocol) throws {
        try recentlyDeletedStore.archive(recipe: recipe)
        try writer.deleteRecipe(recipe: recipe)
        removeRecipeFromSavedOrder(collection: recipe.collection, name: recipe.name)
        refresh()
        removeRecentRecipeShortcut(collection: recipe.collection, name: recipe.name)
    }

    func restoreDeletedRecipe(_ deletedRecipe: DeletedRecipe) throws {
        let nameAlreadyExists = collections.contains { collection in
            collection.name == deletedRecipe.collection &&
            collection.recipes.contains { $0.name == deletedRecipe.name }
        }
        guard !nameAlreadyExists else {
            throw RecentlyDeletedRecipeError.recipeExists
        }
        let recipe = RecipeFile.toRecipe(deletedRecipe.payload.recipe, collection: deletedRecipe.collection)
        try writer.writeRecipe(recipe: recipe)
        recentlyDeletedStore.remove(id: deletedRecipe.id)
        refresh()
    }

    func permanentlyDelete(_ deletedRecipe: DeletedRecipe) {
        recentlyDeletedStore.remove(id: deletedRecipe.id)
        refresh()
    }

    func permanentlyDeleteAllRecentlyDeleted() {
        recentlyDeletedStore.removeAll()
        refresh()
    }

    func save(recipe: any RecipeProtocol, recordsAddedCollection: Bool = true) throws {
        try writer.writeRecipe(recipe: recipe)
        refresh()
        if recordsAddedCollection {
            recordRecipeAdded(to: recipe.collection)
        }
        appendRecipeToSavedOrderIfNeeded(recipe)
    }

    func exportLibraryBackup(appearances: [String: CollectionAppearance] = [:]) throws -> URL {
        let recipes = collections.flatMap(\.recipes)
        let userState = RecipeLibraryUserState(
            settings: Settings.shared.backupData(),
            ingredientDensities: IngredientDensityStore.shared.backupData(),
            ingredientConversions: IngredientConversionStore.shared.backupData(),
            recipes: backupData()
        )
        return try RecipeLibraryBackupFile.write(
            RecipeLibraryBackupFile.backup(from: recipes, appearances: appearances, userState: userState)
        )
    }

    func restoreLibraryBackup(_ backup: RecipeLibraryBackup) throws {
        guard backup.version == 1, backup.type == RecipeLibraryBackupFile.type else {
            throw RecipeLibraryBackupError.unsupportedVersion
        }
        let duplicateNames = Dictionary(grouping: backup.recipes, by: { $0.recipe.name.lowercased() })
            .contains { $0.value.count > 1 }
        guard !duplicateNames else {
            throw RecipeLibraryBackupError.duplicateRecipes
        }
        let recipes = backup.recipes.map { RecipeFile.toRecipe($0.recipe, collection: $0.recipe.collection) }
        try writer.replaceLibrary(with: recipes)
        refresh()
        updateRecentRecipeShortcutItems()
        restore(backup.userState?.recipes)
    }

    func update(recipe: any RecipeProtocol, existingName: String, existingCollection: String) throws {
        try writer.updateRecipe(recipe: recipe, existingName: existingName, existingCollection: existingCollection)
        updateSavedOrderForRecipeChange(recipe: recipe, existingName: existingName, existingCollection: existingCollection)
        refresh()
        removeRecentRecipeShortcut(collection: existingCollection, name: existingName)
        recordOpened(recipe: recipe)
    }

    func moveRecipes(in collectionName: String, fromOffsets: IndexSet, toOffset: Int) {
        guard let collection = collections.first(where: { $0.name == collectionName }) else { return }
        let recipes = reordered(collection.recipes, fromOffsets: fromOffsets, toOffset: toOffset)
        collection.recipes = recipes
        saveRecipeOrder(for: collectionName, names: recipes.map(\.name))
        collections = collections
    }

    func recordOpened(recipe: any RecipeProtocol) {
        let opened = RecentRecipeShortcut(collection: recipe.collection, name: recipe.name)
        var recents = loadRecentRecipeShortcuts()
            .filter { $0 != opened }
        recents.insert(opened, at: 0)
        saveRecentRecipeShortcuts(Array(recents.prefix(maxRecentRecipeShortcuts)))
        updateRecentRecipeShortcutItems()
    }

    // MARK: - History

    func historyEntries(for recipe: any RecipeProtocol) -> [HistoryEntry] {
        historyWriter.historyEntries(for: recipe)
    }

    func addNote(_ text: String, to recipe: any RecipeProtocol) throws {
        try historyWriter.addNote(text, to: recipe)
    }

    func deleteHistoryEntry(_ entry: HistoryEntry, from recipe: any RecipeProtocol) throws {
        try historyWriter.deleteEntry(entry, from: recipe)
    }

    func restoreVersion(_ entry: HistoryEntry, for recipe: any RecipeProtocol) throws {
        try historyWriter.restoreVersion(entry, for: recipe)
        refresh()
    }

    func setAsDefault(recipe: any RecipeProtocol, overrides: CalculatorOverrides) throws {
        let currentSnapshot = RecipeSnapshot(from: recipe)
        let newSnapshot = overrides.applied(to: recipe)
        let summary = RecipeDiff.summarize(from: currentSnapshot, to: newSnapshot)
        try historyWriter.setAsDefault(snapshot: newSnapshot, summary: summary, recipe: recipe)
        refresh()
    }

    private func recordRecipeAdded(to collection: String) {
        guard collections.contains(where: { $0.name == collection }) else { return }
        UserDefaults.standard.set(collection, forKey: lastRecipeAddedCollectionKey)
        cloudStore?.set(collection, forKey: lastRecipeAddedCollectionKey)
        _ = cloudStore?.synchronize()
    }

    private func removeRecentRecipeShortcut(collection: String, name: String) {
        let removed = RecentRecipeShortcut(collection: collection, name: name)
        let recents = loadRecentRecipeShortcuts()
            .filter { $0 != removed }
        saveRecentRecipeShortcuts(recents)
        updateRecentRecipeShortcutItems()
    }

    private func updateRecentRecipeShortcutItems() {
        let validRecents = loadRecentRecipeShortcuts()
            .filter { recent in
                collections.contains { collection in
                    collection.name == recent.collection &&
                    collection.recipes.contains { $0.name == recent.name }
                }
            }

        if validRecents != loadRecentRecipeShortcuts() {
            saveRecentRecipeShortcuts(validRecents)
        }

        UIApplication.shared.shortcutItems = validRecents.prefix(maxRecentRecipeShortcuts).map { recent in
            UIApplicationShortcutItem(
                type: DoughyShortcut.openRecipe,
                localizedTitle: recent.name,
                localizedSubtitle: recent.collection,
                icon: UIApplicationShortcutIcon(systemImageName: "book"),
                userInfo: [
                    DoughyShortcut.collectionUserInfoKey: recent.collection as NSString,
                    DoughyShortcut.nameUserInfoKey: recent.name as NSString,
                ]
            )
        }
    }

    private func loadRecentRecipeShortcuts() -> [RecentRecipeShortcut] {
        guard let data = UserDefaults.standard.data(forKey: recentRecipeShortcutsKey),
              let recents = try? JSONDecoder().decode([RecentRecipeShortcut].self, from: data) else {
            return []
        }
        return Array(recents.prefix(maxRecentRecipeShortcuts))
    }

    private func saveRecentRecipeShortcuts(_ recents: [RecentRecipeShortcut]) {
        guard let data = try? JSONEncoder().encode(Array(recents.prefix(maxRecentRecipeShortcuts))) else { return }
        UserDefaults.standard.set(data, forKey: recentRecipeShortcutsKey)
        cloudStore?.set(data, forKey: recentRecipeShortcutsKey)
        _ = cloudStore?.synchronize()
    }

    func backupData() -> BackupData? {
        let data = BackupData(
            recentRecipeShortcuts: loadRecentRecipeShortcuts().nilIfEmpty,
            lastRecipeAddedCollection: UserDefaults.standard.string(forKey: lastRecipeAddedCollectionKey),
            recentlyDeletedRecipes: recentlyDeletedStore.items().nilIfEmpty,
            recipeOrder: loadRecipeOrder().isEmpty ? nil : loadRecipeOrder()
        )
        return data.isEmpty ? nil : data
    }

    func restore(_ data: BackupData?) {
        guard let data else { return }
        saveRecentRecipeShortcuts(data.recentRecipeShortcuts ?? [])
        if let collection = data.lastRecipeAddedCollection {
            UserDefaults.standard.set(collection, forKey: lastRecipeAddedCollectionKey)
            cloudStore?.set(collection, forKey: lastRecipeAddedCollectionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastRecipeAddedCollectionKey)
            cloudStore?.removeObject(forKey: lastRecipeAddedCollectionKey)
        }
        recentlyDeletedStore.restore(data.recentlyDeletedRecipes ?? [])
        saveRecipeOrder(data.recipeOrder ?? .empty)
        _ = cloudStore?.synchronize()
        refresh()
    }

    private func hydrateUserStateFromCloud() {
        _ = cloudStore?.synchronize()
        let localRecents = loadRecentRecipeShortcuts()
        let cloudRecents = cloudStore?.data(forKey: recentRecipeShortcutsKey).flatMap {
            try? JSONDecoder().decode([RecentRecipeShortcut].self, from: $0)
        } ?? []
        var mergedRecents: [RecentRecipeShortcut] = []
        for recent in localRecents + cloudRecents where !mergedRecents.contains(recent) {
            mergedRecents.append(recent)
        }
        saveRecentRecipeShortcuts(Array(mergedRecents.prefix(maxRecentRecipeShortcuts)))

        if UserDefaults.standard.object(forKey: lastRecipeAddedCollectionKey) == nil,
           let cloudCollection = cloudStore?.string(forKey: lastRecipeAddedCollectionKey) {
            UserDefaults.standard.set(cloudCollection, forKey: lastRecipeAddedCollectionKey)
        }
        if let localCollection = UserDefaults.standard.string(forKey: lastRecipeAddedCollectionKey) {
            cloudStore?.set(localCollection, forKey: lastRecipeAddedCollectionKey)
            _ = cloudStore?.synchronize()
        }
        let mergedOrder = mergedRecipeOrder(local: loadRecipeOrder(), cloud: loadCloudRecipeOrder())
        saveRecipeOrder(mergedOrder)
    }

    private func applySavedRecipeOrder(to collections: [RecipeCollection]) -> [RecipeCollection] {
        let order = loadRecipeOrder().collections
        for collection in collections {
            guard let savedNames = order[collection.name], !savedNames.isEmpty else { continue }
            let savedIndex = Dictionary(uniqueKeysWithValues: savedNames.enumerated().map { ($0.element, $0.offset) })
            collection.recipes.sort { lhs, rhs in
                switch (savedIndex[lhs.name], savedIndex[rhs.name]) {
                case let (left?, right?):
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            }
        }
        return collections
    }

    private func reordered(_ recipes: [RecipeProtocol], fromOffsets: IndexSet, toOffset: Int) -> [RecipeProtocol] {
        let validOffsets = fromOffsets.filter { recipes.indices.contains($0) }.sorted()
        guard !validOffsets.isEmpty else { return recipes }

        let moving = validOffsets.map { recipes[$0] }
        var result = recipes
        for offset in validOffsets.reversed() {
            result.remove(at: offset)
        }

        let removedBeforeTarget = validOffsets.filter { $0 < toOffset }.count
        let insertionIndex = min(max(toOffset - removedBeforeTarget, 0), result.count)
        result.insert(contentsOf: moving, at: insertionIndex)
        return result
    }

    private func appendRecipeToSavedOrderIfNeeded(_ recipe: any RecipeProtocol) {
        var order = loadRecipeOrder()
        guard order.collections[recipe.collection] != nil else { return }
        if order.collections[recipe.collection]?.contains(recipe.name) == false {
            order.collections[recipe.collection]?.append(recipe.name)
            saveRecipeOrder(order)
        }
    }

    private func removeRecipeFromSavedOrder(collection: String, name: String) {
        var order = loadRecipeOrder()
        guard order.collections[collection]?.contains(name) == true else { return }
        order.collections[collection]?.removeAll { $0 == name }
        saveRecipeOrder(order)
    }

    private func updateSavedOrderForRecipeChange(recipe: any RecipeProtocol, existingName: String, existingCollection: String) {
        var order = loadRecipeOrder()
        guard order.collections[existingCollection] != nil || order.collections[recipe.collection] != nil else { return }

        if existingCollection == recipe.collection {
            if let index = order.collections[existingCollection]?.firstIndex(of: existingName) {
                order.collections[existingCollection]?[index] = recipe.name
            }
        } else {
            order.collections[existingCollection]?.removeAll { $0 == existingName }
            var destination = order.collections[recipe.collection] ?? []
            if !destination.contains(recipe.name) {
                destination.append(recipe.name)
            }
            order.collections[recipe.collection] = destination
        }
        saveRecipeOrder(order)
    }

    private func saveRecipeOrder(for collection: String, names: [String]) {
        var order = loadRecipeOrder()
        order.collections[collection] = names
        saveRecipeOrder(order)
    }

    private func loadRecipeOrder() -> RecipeOrder {
        guard let data = UserDefaults.standard.data(forKey: recipeOrderKey),
              let order = try? JSONDecoder().decode(RecipeOrder.self, from: data) else {
            return .empty
        }
        return order
    }

    private func loadCloudRecipeOrder() -> RecipeOrder {
        guard let data = cloudStore?.data(forKey: recipeOrderKey),
              let order = try? JSONDecoder().decode(RecipeOrder.self, from: data) else {
            return .empty
        }
        return order
    }

    private func saveRecipeOrder(_ order: RecipeOrder) {
        if order.isEmpty {
            UserDefaults.standard.removeObject(forKey: recipeOrderKey)
            cloudStore?.removeObject(forKey: recipeOrderKey)
            _ = cloudStore?.synchronize()
            return
        }
        guard let data = try? JSONEncoder().encode(order) else { return }
        UserDefaults.standard.set(data, forKey: recipeOrderKey)
        cloudStore?.set(data, forKey: recipeOrderKey)
        _ = cloudStore?.synchronize()
    }

    private func mergedRecipeOrder(local: RecipeOrder, cloud: RecipeOrder) -> RecipeOrder {
        var merged = cloud.collections
        for (collection, localNames) in local.collections {
            var names = merged[collection] ?? []
            for name in localNames where !names.contains(name) {
                names.append(name)
            }
            merged[collection] = names
        }
        return RecipeOrder(collections: merged)
    }
}

enum RecentlyDeletedRecipeError: LocalizedError {
    case recipeExists
    case couldNotArchive

    var errorDescription: String? {
        switch self {
        case .recipeExists:
            return "A recipe with that name already exists in this collection. Delete or rename the active recipe, then try restoring again."
        case .couldNotArchive:
            return "The recipe could not be moved to Recently Deleted."
        }
    }
}

enum RecipeLibraryBackupError: LocalizedError {
    case unsupportedVersion
    case duplicateRecipes

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return "This backup was made by a newer version of Doughy."
        case .duplicateRecipes:
            return "This backup contains more than one recipe with the same name."
        }
    }
}

private final class RecentlyDeletedRecipeStore {
    static let shared = RecentlyDeletedRecipeStore()

    private let key = "recentlyDeletedRecipes"
    private let retentionDays = 30
    private let userDefaults = UserDefaults.standard
    private let cloudStore: DoughyKeyValueStore? = NSUbiquitousKeyValueStore.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        hydrateFromCloud()
    }

    func archive(recipe: any RecipeProtocol) throws {
        let deletedRecipe = DeletedRecipe(
            id: UUID(),
            deletedAt: Date(),
            payload: RecipeFile.payload(from: recipe, author: nil)
        )
        var currentItems = items()
        currentItems.removeAll {
            $0.name == recipe.name && $0.collection == recipe.collection
        }
        currentItems.insert(deletedRecipe, at: 0)
        try save(currentItems)
    }

    func items(now: Date = Date()) -> [DeletedRecipe] {
        let loaded = load()
        let retained = loaded
            .filter { expirationDate(for: $0) > now }
            .sorted { $0.deletedAt > $1.deletedAt }
        if retained != loaded {
            try? save(retained)
        }
        return retained
    }

    func remove(id: UUID) {
        let retained = load().filter { $0.id != id }
        try? save(retained)
    }

    func removeAll() {
        userDefaults.removeObject(forKey: key)
        cloudStore?.removeObject(forKey: key)
        _ = cloudStore?.synchronize()
    }

    func expirationDate(for deletedRecipe: DeletedRecipe) -> Date {
        Calendar.current.date(byAdding: .day, value: retentionDays, to: deletedRecipe.deletedAt)
            ?? deletedRecipe.deletedAt
    }

    private func load() -> [DeletedRecipe] {
        guard let data = userDefaults.data(forKey: key),
              let recipes = try? decoder.decode([DeletedRecipe].self, from: data) else {
            return []
        }
        return recipes
    }

    private func save(_ recipes: [DeletedRecipe]) throws {
        do {
            let data = try encoder.encode(recipes)
            userDefaults.set(data, forKey: key)
            cloudStore?.set(data, forKey: key)
            _ = cloudStore?.synchronize()
        } catch {
            throw RecentlyDeletedRecipeError.couldNotArchive
        }
    }

    func restore(_ recipes: [DeletedRecipe]) {
        try? save(recipes)
    }

    private func hydrateFromCloud() {
        _ = cloudStore?.synchronize()
        let local = load()
        let cloud = cloudStore?.data(forKey: key).flatMap {
            try? decoder.decode([DeletedRecipe].self, from: $0)
        } ?? []
        var merged: [DeletedRecipe] = []
        for item in local + cloud
        where !merged.contains(where: { $0.name == item.name && $0.collection == item.collection }) {
            merged.append(item)
        }
        try? save(merged)
    }
}

private extension Array {
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}
