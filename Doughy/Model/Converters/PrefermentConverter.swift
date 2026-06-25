//
//  PrefermentConverter.swift
//  Doughy
//
//  Created by urickg on 3/30/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class PrefermentConverter: NSObject {
    
    let objectFactory = ObjectFactory.shared
    let ingredientConverter = IngredientConverter.shared
    
    static let shared = PrefermentConverter()
    
    private override init() { }
    
    func convertToCoreData(preferment: Preferment) -> XCPreferment {
        let coreData = objectFactory.createPreferment()
        
        coreData.name = preferment.name
        coreData.flourPercentage = NSNumber(floatLiteral: preferment.flourPercentage)
        preferment.ingredients.enumerated().forEach { index, ingredient in
            let xcIng = ingredientConverter.convertToCoreData(ingredient: ingredient)
            xcIng.sortOrder = Int16(index)
            coreData.addToIngredients(xcIng)
        }
        
        return coreData
    }
    
    /// - Parameter localizeName: When true, the preferment name and its ingredient
    ///   names are localized. Only set for the app's built-in default recipes.
    func convertToExternal(preferment: XCPreferment, localizeName: Bool = false) -> Preferment {
        let storedName = preferment.name!
        let name = localizeName ? DefaultLocalization.ingredientName(storedName) : storedName
        let flourPercentage = preferment.flourPercentage!.doubleValue
        let ingredients = preferment.sortedIngredients.map {
            ingredientConverter.convertToExternal(ingredient: $0, localizeName: localizeName)
        }
        
        return Preferment(name: name, flourPercentage: flourPercentage, ingredients: ingredients)
    }
    
    

}
