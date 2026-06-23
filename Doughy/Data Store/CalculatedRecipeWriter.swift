//
//  RecipesDataStore.swift
//  Doughy
//
//  Created by urickg on 3/20/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit
import CoreData

class CalculatedRecipeWriter: NSObject {
    
    private let objectFactory = ObjectFactory.shared
    private let coreDataGateway = CoreDataGateway.shared
    private let recipeConverter = CalculatedRecipeConverter.shared
    private let recipeReader = CalculatedRecipeReader.shared
    
    static let shared = CalculatedRecipeWriter()
    
    private override init() { }
    
    func writeRecipe(recipe: CalculatedRecipeProtocol) throws {
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
    
    func deleteRecipe(recipe: RecipeProtocol) throws {
        print("Deleting Recipe \(recipe)")
        
        guard let coreDataRecipe = recipeReader.getRecipe(collection: recipe.collection, name: recipe.name) else {
            print("Cannot delete recipe. Recipe not found in core data")
            throw RecipeWritingError.noRecipeToDelete
        }
        
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
        
        do {
            try self.coreDataGateway.managedObjectConext.save()
        }
        catch {
            print("Failed to delete recipe due to error \(error)")
            throw RecipeWritingError.couldNotSave
        }
    }
}
