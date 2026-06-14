//
//  HistoryWriter.swift
//  Doughy
//

import Foundation
import CoreData

class HistoryWriter: NSObject {

    private let coreDataGateway = CoreDataGateway.shared
    private let recipeReader = RecipeReader.shared
    private let recipeConverter = RecipeConverter.shared
    private let historyEntryConverter = HistoryEntryConverter.shared

    static let shared = HistoryWriter()

    private override init() { }

    func historyEntries(for recipe: any RecipeProtocol) -> [HistoryEntry] {
        guard let xcRecipe = recipeReader.getRecipe(collection: recipe.collection, name: recipe.name) else { return [] }
        return recipeReader.getHistoryEntries(for: xcRecipe).map(historyEntryConverter.convertToExternal)
    }

    func addNote(_ text: String, to recipe: any RecipeProtocol) throws {
        guard let xcRecipe = recipeReader.getRecipe(collection: recipe.collection, name: recipe.name) else {
            throw HistoryWritingError.recipeNotFound
        }
        addEntry(HistoryEntry(id: UUID(), date: Date(), kind: .note, text: text), to: xcRecipe)
        try save()
    }

    func deleteEntry(_ entry: HistoryEntry, from recipe: any RecipeProtocol) throws {
        guard let xcRecipe = recipeReader.getRecipe(collection: recipe.collection, name: recipe.name),
              let xcEntry = recipeReader.getHistoryEntries(for: xcRecipe).first(where: { $0.id == entry.id }) else {
            throw HistoryWritingError.entryNotFound
        }
        coreDataGateway.managedObjectConext.delete(xcEntry)
        try save()
    }

    func restoreVersion(_ entry: HistoryEntry, for recipe: any RecipeProtocol) throws {
        guard case .version(let snapshot) = entry.kind else {
            throw HistoryWritingError.invalidVersionEntry
        }
        guard let xcRecipe = recipeReader.getRecipe(collection: recipe.collection, name: recipe.name) else {
            throw HistoryWritingError.recipeNotFound
        }

        let currentSnapshot = RecipeSnapshot(from: recipeConverter.convertToExternal(recipe: xcRecipe))
        let summary = RecipeDiff.summarize(from: currentSnapshot, to: snapshot)
            ?? "Restored to version from \(entry.date.formatted(date: .abbreviated, time: .shortened))"
        addEntry(HistoryEntry(id: UUID(), date: Date(), kind: .version(currentSnapshot), text: summary), to: xcRecipe)

        let restoredRecipe = snapshot.makeRecipe(name: recipe.name, collection: recipe.collection)
        _ = recipeConverter.overWriteCoreData(recipe: restoredRecipe, existing: xcRecipe)

        try save()
    }

    /// Snapshots `recipe`'s current state as a new version entry (if `summary` is
    /// non-nil), then overwrites it with `snapshot`. Used by "Set as Default".
    func setAsDefault(snapshot: RecipeSnapshot, summary: String?, recipe: any RecipeProtocol) throws {
        guard let xcRecipe = recipeReader.getRecipe(collection: recipe.collection, name: recipe.name) else {
            throw HistoryWritingError.recipeNotFound
        }

        if let summary {
            let currentSnapshot = RecipeSnapshot(from: recipeConverter.convertToExternal(recipe: xcRecipe))
            addEntry(HistoryEntry(id: UUID(), date: Date(), kind: .version(currentSnapshot), text: summary), to: xcRecipe)
        }

        let updatedRecipe = snapshot.makeRecipe(name: recipe.name, collection: recipe.collection)
        _ = recipeConverter.overWriteCoreData(recipe: updatedRecipe, existing: xcRecipe)

        try save()
    }

    private func addEntry(_ entry: HistoryEntry, to xcRecipe: XCRecipe) {
        xcRecipe.addToHistoryEntries(historyEntryConverter.convertToCoreData(entry: entry))
    }

    private func save() throws {
        do {
            try coreDataGateway.managedObjectConext.save()
        }
        catch {
            throw HistoryWritingError.couldNotSave
        }
    }
}

enum HistoryWritingError: Error {
    case recipeNotFound
    case entryNotFound
    case invalidVersionEntry
    case couldNotSave
}
