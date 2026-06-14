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
        
        self.coreDataGateway.managedObjectConext.delete(coreDataRecipe)
        let ingredients = coreDataRecipe.ingredients!.array as! [XCIngredient]
        ingredients.forEach {
            self.coreDataGateway.managedObjectConext.delete($0)
        }
        let instructions = coreDataRecipe.instructions!.array as! [XCInstruction]
        instructions.forEach {
            self.coreDataGateway.managedObjectConext.delete($0)
        }
        if let preferment = coreDataRecipe.preferment {
            let prefIngredients = preferment.ingredients!.array as! [XCIngredient]
            prefIngredients.forEach {
                self.coreDataGateway.managedObjectConext.delete($0)
            }
            self.coreDataGateway.managedObjectConext.delete(preferment)
        }
        
        do {
            try self.coreDataGateway.managedObjectConext.save()
        }
        catch {
            print("Failed to delete recipe due to error \(error)")
            throw RecipeWritingError.couldNotSave
        }
    }

}

enum RecipeWritingError: Error {
    case recipeExistsDuringWrite
    case noRecipeToUpdate
    case noRecipeToDelete
    case couldNotSave
}
