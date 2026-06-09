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
}
