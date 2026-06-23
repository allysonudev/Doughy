//
//  CalculatedRecipeConverter.swift
//  Doughy
//
//  Created by urickg on 3/30/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class CalculatedRecipeConverter: NSObject {
    
    let objectFactory = ObjectFactory.shared
    let ingredientConverter = CalculatedIngredientConverter.shared
    let prefermentConverter = CalculatedPrefermentConverter.shared
    let instructionConverter = InstructionConverter.shared
    
    static let shared = CalculatedRecipeConverter()
    
    private override init() { }
    
    func convertToCoreData(recipe: CalculatedRecipeProtocol) -> XCCalculatedRecipe {
        let coreData = objectFactory.createCalculatedRecipe()
        
        coreData.name = recipe.name
        coreData.collection = recipe.collection
        coreData.weight = NSNumber(floatLiteral: recipe.weight)
        recipe.ingredients.enumerated().forEach { index, ingredient in
            let xcIng = ingredientConverter.convertToCoreData(ingredient: ingredient)
            xcIng.sortOrder = Int16(index)
            coreData.addToIngredients(xcIng)
        }
        if recipe is CalculatedPrefermentRecipe {
            let preferment = (recipe as! CalculatedPrefermentRecipe).preferment
            coreData.preferment = prefermentConverter.convertToCoreData(preferment: preferment)
        }
        recipe.instructions.enumerated().forEach { index, instruction in
            let xcStep = instructionConverter.convertToCoreData(instruction: instruction)
            xcStep.sortOrder = Int16(index)
            coreData.addToInstructions(xcStep)
        }
        
        
        return coreData
    }
    
    func convertToExternal(recipe: XCCalculatedRecipe) -> CalculatedRecipeProtocol {
        let name = recipe.name!
        let collection = recipe.collection!
        let weight = recipe.weight!.doubleValue
        let ingredients = recipe.sortedIngredients.map {
            ingredientConverter.convertToExternal(ingredient: $0)
        }
        let instructions = recipe.sortedInstructions.map {
            instructionConverter.convertToExternal(instruction: $0)
        }
        if let xcPreferment = recipe.preferment {
            let preferment = prefermentConverter.convertToExternal(preferment: xcPreferment)
            return CalculatedPrefermentRecipe(name: name, collection: collection, weight: weight, ingredients: ingredients, preferment: preferment, instructions: instructions)
        }
        
        return CalculatedRecipe(name: name, collection: collection, weight: weight, ingredients: ingredients, instructions: instructions)
        
    }
}
