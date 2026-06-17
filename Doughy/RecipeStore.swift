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

@Observable
class RecipeStore {
    private(set) var collections: [RecipeCollection] = []
    var pendingImport: RecipeFilePayload? = nil
    var pendingIntentImage: UIImage? = nil
    var pendingShareIntent: PendingShareRequest? = nil
    var pendingOpenIntent: PendingOpenRecipeRequest? = nil
    var pendingScanShortcut = false

    private let writer = RecipeWriter.shared
    private let predicates = RecipePredicates.shared
    private let historyWriter = HistoryWriter.shared
    private let recentRecipeShortcutsKey = "recentRecipeShortcuts"
    private let maxRecentRecipeShortcuts = 3

    init() {
        refresh()
        updateRecentRecipeShortcutItems()
    }

    func refresh() {
        collections = Settings.shared.refreshRecipes()
    }

    var collectionNames: [String] {
        collections.map(\.name)
    }

    func isNameTaken(_ name: String, excluding existingName: String? = nil) -> Bool {
        if let existing = existingName, name == existing { return false }
        return predicates.isRecipeNameTaken(name: name)
    }

    func delete(recipe: any RecipeProtocol) throws {
        try writer.deleteRecipe(recipe: recipe)
        refresh()
        removeRecentRecipeShortcut(collection: recipe.collection, name: recipe.name)
    }

    func save(recipe: any RecipeProtocol) throws {
        try writer.writeRecipe(recipe: recipe)
        refresh()
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
