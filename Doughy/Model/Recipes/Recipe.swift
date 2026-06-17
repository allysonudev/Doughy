//
//  Recipe.swift
//  Doughy
//
//  Created by urickg on 3/30/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

enum RecipeMeasurementMode: String, Codable {
    case percent
    case weight
}

protocol RecipeProtocol {
    
    var name: String { get }
    var collection: String { get }
    var defaultWeight: Double { get }
    var ingredients: [Ingredient] { get }
    var instructions: [Instruction] { get }
    var measurementMode: RecipeMeasurementMode { get }
    
    func containsVariableTemps() -> Bool
}

class Recipe: NSObject, RecipeProtocol {
    
    let name: String
    let collection: String
    let defaultWeight: Double
    let ingredients: [Ingredient]
    let instructions: [Instruction]
    let measurementMode: RecipeMeasurementMode
    
    init(name: String, collection: String,
         defaultWeight: Double, ingredients: [Ingredient],
         instructions: [Instruction],
         measurementMode: RecipeMeasurementMode = .percent) {
        self.name = name
        self.collection = collection
        self.defaultWeight = defaultWeight
        self.ingredients = ingredients
        self.instructions = instructions
        self.measurementMode = measurementMode
    }
    
    func containsVariableTemps() -> Bool {
        for ingredient in ingredients {
            if ingredient.temperature != nil {
                return true
            }
        }
        return false
    }
    
}

class PrefermentRecipe: NSObject, RecipeProtocol {
    
    let preferment: Preferment
    
    let name: String
    let collection: String
    let defaultWeight: Double
    let ingredients: [Ingredient]
    let instructions: [Instruction]
    let measurementMode: RecipeMeasurementMode
    
    init(name: String, collection: String,
         defaultWeight: Double, ingredients: [Ingredient],
         preferment: Preferment, instructions: [Instruction],
         measurementMode: RecipeMeasurementMode = .percent) {
        self.name = name
        self.collection = collection
        self.defaultWeight = defaultWeight
        self.ingredients = ingredients
        self.preferment = preferment
        self.instructions = instructions
        self.measurementMode = measurementMode
    }
    
    func containsVariableTemps() -> Bool {
        for ingredient in ingredients {
            if ingredient.temperature != nil {
                return true
            }
        }
        for ingredient in preferment.ingredients {
            if ingredient.temperature != nil {
                return true
            }
        }
        return false
    }
}
