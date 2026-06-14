//
//  RecipeStore.swift
//  Doughy

import Foundation
import Observation

@Observable
class RecipeStore {
    private(set) var collections: [RecipeCollection] = []

    private let writer = RecipeWriter.shared
    private let predicates = RecipePredicates.shared
    private let historyWriter = HistoryWriter.shared

    init() {
        refresh()
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
    }

    func save(recipe: any RecipeProtocol) throws {
        try writer.writeRecipe(recipe: recipe)
        refresh()
    }

    func update(recipe: any RecipeProtocol, existingName: String, existingCollection: String) throws {
        try writer.updateRecipe(recipe: recipe, existingName: existingName, existingCollection: existingCollection)
        refresh()
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
}
