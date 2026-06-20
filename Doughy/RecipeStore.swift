//
//  RecipeStore.swift
//  Doughy

import Foundation
import Observation
import UIKit

private struct RecentRecipeShortcut: Codable, Equatable {
    let collection: String
    let name: String
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
    private let maxRecentRecipeShortcuts = 3

    init(isNewInstall: Bool = false) {
        self.isNewInstall = isNewInstall
        refresh()
        updateRecentRecipeShortcutItems()
    }

    func refresh() {
        collections = Settings.shared.refreshRecipes()
        deletedRecipes = recentlyDeletedStore.items()
    }

    var collectionNames: [String] {
        collections.map(\.name)
    }

    func isNameTaken(_ name: String, excluding existingName: String? = nil) -> Bool {
        if let existing = existingName, name == existing { return false }
        return predicates.isRecipeNameTaken(name: name)
    }

    func delete(recipe: any RecipeProtocol) throws {
        try recentlyDeletedStore.archive(recipe: recipe)
        try writer.deleteRecipe(recipe: recipe)
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

    func save(recipe: any RecipeProtocol) throws {
        try writer.writeRecipe(recipe: recipe)
        refresh()
    }

    func exportLibraryBackup() throws -> URL {
        let recipes = collections.flatMap(\.recipes)
        return try RecipeLibraryBackupFile.write(RecipeLibraryBackupFile.backup(from: recipes))
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
    }

    func update(recipe: any RecipeProtocol, existingName: String, existingCollection: String) throws {
        try writer.updateRecipe(recipe: recipe, existingName: existingName, existingCollection: existingCollection)
        refresh()
        removeRecentRecipeShortcut(collection: existingCollection, name: existingName)
        recordOpened(recipe: recipe)
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
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() { }

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
        } catch {
            throw RecentlyDeletedRecipeError.couldNotArchive
        }
    }
}
