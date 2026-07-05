//
//  RecipeConverter.swift
//  Doughy
//
//  Created by urickg on 3/30/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class RecipeConverter: NSObject {
    
    let objectFactory = ObjectFactory.shared
    let ingredientConverter = IngredientConverter.shared
    let prefermentConverter = PrefermentConverter.shared
    let instructionConverter = InstructionConverter.shared
    let coreDataGateway = CoreDataGateway.shared
    
    static let shared = RecipeConverter()
    
    private override init() { }
    
    func convertToCoreData(recipe: RecipeProtocol) -> XCRecipe {
        let coreData = objectFactory.createRecipe()
        
        coreData.name = recipe.name
        coreData.collection = recipe.collection
        coreData.defaultWeight = NSNumber(floatLiteral: recipe.defaultWeight)
        coreData.setValue(recipe.measurementMode.rawValue, forKey: "measurementMode")
        coreData.setValue(recipe.sourceURL?.absoluteString, forKey: "sourceURL")
        recipe.ingredients.enumerated().forEach { index, ingredient in
            let xcIng = ingredientConverter.convertToCoreData(ingredient: ingredient)
            xcIng.sortOrder = Int16(index)
            coreData.addToIngredients(xcIng)
        }
        recipe.instructions.enumerated().forEach { index, instruction in
            let xcStep = instructionConverter.convertToCoreData(instruction: instruction)
            xcStep.sortOrder = Int16(index)
            coreData.addToInstructions(xcStep)
        }
        if recipe is PrefermentRecipe {
            let preferment = (recipe as! PrefermentRecipe).preferment
            coreData.preferment = prefermentConverter.convertToCoreData(preferment: preferment)
        }
        
        return coreData
    }
    
    func overWriteCoreData(recipe: RecipeProtocol, existing: XCRecipe) -> XCRecipe {
        // Clear the localization key if the user has renamed the recipe.
        if existing.name != recipe.name {
            existing.setValue(nil, forKey: "defaultKey")
        }

        existing.name = recipe.name
        existing.collection = recipe.collection
        existing.defaultWeight = NSNumber(floatLiteral: recipe.defaultWeight)
        existing.setValue(recipe.measurementMode.rawValue, forKey: "measurementMode")
        existing.setValue(recipe.sourceURL?.absoluteString, forKey: "sourceURL")
        self.replaceIngredients(recipe: recipe, existing: existing)
        self.replaceInstructions(recipe: recipe, existing: existing)
        
        if recipe is PrefermentRecipe {
            let preferment = (recipe as! PrefermentRecipe).preferment
            if let existingPreferment = existing.preferment {
                self.coreDataGateway.managedObjectConext.delete(existingPreferment)
            }
            existing.preferment = prefermentConverter.convertToCoreData(preferment: preferment)
        }
        
        return existing
    }
    
    private func replaceIngredients(recipe: RecipeProtocol, existing: XCRecipe) {
        let ingredients = existing.sortedIngredients
        if let set = existing.ingredients { existing.removeFromIngredients(set) }
        ingredients.forEach {
            self.coreDataGateway.managedObjectConext.delete($0)
        }
        recipe.ingredients.enumerated().forEach { index, ingredient in
            let xcIng = ingredientConverter.convertToCoreData(ingredient: ingredient)
            xcIng.sortOrder = Int16(index)
            existing.addToIngredients(xcIng)
        }
    }

    private func replaceInstructions(recipe: RecipeProtocol, existing: XCRecipe) {
        let instructions = existing.sortedInstructions
        if let set = existing.instructions { existing.removeFromInstructions(set) }
        instructions.forEach {
            self.coreDataGateway.managedObjectConext.delete($0)
        }
        recipe.instructions.enumerated().forEach { index, instruction in
            let xcStep = instructionConverter.convertToCoreData(instruction: instruction)
            xcStep.sortOrder = Int16(index)
            existing.addToInstructions(xcStep)
        }
    }
    
    func convertToExternal(recipe: XCRecipe) -> RecipeProtocol {
        let storedName = recipe.name!
        // A non-nil defaultKey marks an unmodified built-in recipe. Only these get
        // their name, ingredients, and collection localized; user recipes are kept
        // exactly as the user entered them.
        let defaultKey = recipe.value(forKey: "defaultKey") as? String
        let isDefault = defaultKey != nil
        let name = DefaultLocalization.recipeDisplayName(storedName: storedName, defaultKey: defaultKey)
        // Collection stays canonical in the model so grouping is consistent and an
        // edit never rewrites it; it's localized for display at the view layer.
        let collection = recipe.collection!
        let defaultWeight = recipe.defaultWeight!.doubleValue
        let measurementModeRaw = recipe.value(forKey: "measurementMode") as? String
        let measurementMode = RecipeMeasurementMode(rawValue: measurementModeRaw ?? "") ?? .percent
        let sourceURL = (recipe.value(forKey: "sourceURL") as? String).flatMap(URL.init(string:))
        let ingredients = recipe.sortedIngredients.map {
            ingredientConverter.convertToExternal(ingredient: $0, localizeName: isDefault)
        }
        let instructions = recipe.sortedInstructions.map {
            instructionConverter.convertToExternal(instruction: $0, localize: isDefault)
        }
        if let xcPreferment = recipe.preferment {
            let preferment = prefermentConverter.convertToExternal(preferment: xcPreferment, localizeName: isDefault)
            return PrefermentRecipe(name: name, collection: collection,
                                    defaultWeight: defaultWeight, ingredients: ingredients,
                                    preferment: preferment, instructions: instructions,
                                    measurementMode: measurementMode,
                                    sourceURL: sourceURL)
        }
        
        return Recipe(name: name, collection: collection, defaultWeight: defaultWeight, ingredients: ingredients, instructions: instructions, measurementMode: measurementMode, sourceURL: sourceURL)
        
    }
}
