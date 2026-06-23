//
//  RecipesDataStore.swift
//  Doughy
//
//  Created by urickg on 3/20/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit
import CoreData

class RecipeWriter: NSObject {
    
    private let objectFactory = ObjectFactory.shared
    private let coreDataGateway = CoreDataGateway.shared
    private let recipeConverter = RecipeConverter.shared
    private let recipeReader = RecipeReader.shared
    private let historyEntryConverter = HistoryEntryConverter.shared
    
    static let shared = RecipeWriter()
    
    private override init() { }
    
    func writeDefaultRecipe(recipe: RecipeProtocol, key: String) throws {
        if recipeReader.getRecipe(collection: recipe.collection, name: recipe.name) != nil {
            throw RecipeWritingError.recipeExistsDuringWrite
        }
        let xcRecipe = recipeConverter.convertToCoreData(recipe: recipe)
        xcRecipe.setValue(key, forKey: "defaultKey")
        do {
            try self.coreDataGateway.managedObjectConext.save()
        } catch {
            throw RecipeWritingError.couldNotSave
        }
    }

    func writeRecipe(recipe: RecipeProtocol) throws {
        print("Writing Recipe \(recipe)")
        
        // Update if there exists a recipe by this name already
        if recipeReader.getRecipe(collection: recipe.collection, name: recipe.name) != nil {
            print("Attempted to write a recipe when one exists in the collection with this name")
            throw RecipeWritingError.recipeExistsDuringWrite
        }
        
        let _ = recipeConverter.convertToCoreData(recipe: recipe)
        
        do {
            try self.coreDataGateway.managedObjectConext.save()
        }
        catch {
            throw RecipeWritingError.couldNotSave
        }
    }
    
    func updateRecipe(recipe: RecipeProtocol, existingName: String, existingCollection: String) throws {
        print("Updating Recipe \(recipe)")

        // Update if there exists a recipe by this name already
        guard let existingRecipe = recipeReader.getRecipe(collection: existingCollection, name: existingName) else {
            print("Attempted to update a recipe when none exists in the collection with this name")
            throw RecipeWritingError.noRecipeToUpdate
        }

        // Record a history entry for the pre-edit state, but only if this edit
        // actually changes something - no-op saves shouldn't clutter history.
        let oldSnapshot = RecipeSnapshot(from: recipeConverter.convertToExternal(recipe: existingRecipe))
        let newSnapshot = RecipeSnapshot(from: recipe)
        if let summary = RecipeDiff.summarize(from: oldSnapshot, to: newSnapshot) {
            let entry = HistoryEntry(id: UUID(), date: Date(), kind: .version(oldSnapshot), text: summary)
            existingRecipe.addToHistoryEntries(historyEntryConverter.convertToCoreData(entry: entry))
        }

        let _ = recipeConverter.overWriteCoreData(recipe: recipe, existing: existingRecipe)
        
        do {
            try self.coreDataGateway.managedObjectConext.save()
        }
        catch {
            throw RecipeWritingError.couldNotSave
        }
    }
    
    func deleteRecipe(recipe: RecipeProtocol) throws {
        print("Deleting Recipe \(recipe)")
        
        guard let coreDataRecipe = recipeReader.getRecipe(collection: recipe.collection, name: recipe.name) else {
            print("Cannot delete recipe. Recipe not found in core data")
            throw RecipeWritingError.noRecipeToDelete
        }
        
        deleteCoreDataRecipe(coreDataRecipe)
        
        do {
            try self.coreDataGateway.managedObjectConext.save()
        }
        catch {
            print("Failed to delete recipe due to error \(error)")
            throw RecipeWritingError.couldNotSave
        }
    }

    func replaceLibrary(with recipes: [RecipeProtocol]) throws {
        print("Replacing recipe library with \(recipes.count) recipes")

        recipeReader.getRecipes().forEach(deleteCoreDataRecipe)
        recipes.forEach {
            _ = recipeConverter.convertToCoreData(recipe: $0)
        }

        do {
            try self.coreDataGateway.managedObjectConext.save()
        }
        catch {
            print("Failed to replace recipe library due to error \(error)")
            self.coreDataGateway.managedObjectConext.rollback()
            throw RecipeWritingError.couldNotSave
        }
    }

    private func deleteCoreDataRecipe(_ coreDataRecipe: XCRecipe) {
        self.coreDataGateway.managedObjectConext.delete(coreDataRecipe)
        coreDataRecipe.sortedIngredients.forEach {
            self.coreDataGateway.managedObjectConext.delete($0)
        }
        coreDataRecipe.sortedInstructions.forEach {
            self.coreDataGateway.managedObjectConext.delete($0)
        }
        if let preferment = coreDataRecipe.preferment {
            preferment.sortedIngredients.forEach {
                self.coreDataGateway.managedObjectConext.delete($0)
            }
            self.coreDataGateway.managedObjectConext.delete(preferment)
        }
    }

}

enum RecipeWritingError: LocalizedError {
    case recipeExistsDuringWrite
    case noRecipeToUpdate
    case noRecipeToDelete
    case couldNotSave

    var errorDescription: String? {
        switch self {
        case .recipeExistsDuringWrite:
            return String(localized: "recipe_writer.error.recipe_exists", defaultValue: "A recipe with that name already exists in this collection. Please choose a different name.")
        case .noRecipeToUpdate:
            return String(localized: "recipe_writer.error.not_found", defaultValue: "The recipe could not be found. It may have been deleted.")
        case .noRecipeToDelete:
            return String(localized: "recipe_writer.error.delete_missing", defaultValue: "The recipe could not be deleted because it no longer exists.")
        case .couldNotSave:
            return String(localized: "recipe_writer.error.save_failed", defaultValue: "The recipe could not be saved. Please try again.")
        }
    }
}
