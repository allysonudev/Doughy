//
//  IngredientConverter.swift
//  Doughy
//
//  Created by urickg on 3/30/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class IngredientConverter: NSObject {
    
    private let objectFactory = ObjectFactory.shared
    
    static let shared = IngredientConverter()
    
    private override init() { }
    
    func convertToCoreData(ingredient: Ingredient) -> XCIngredient {
        let coreData = objectFactory.createIngredient()
        
        coreData.name = ingredient.name
        coreData.isFlour = ingredient.isFlour
        coreData.defaultPercentage = NSNumber(floatLiteral: ingredient.defaultPercentage)
        if let defaultWeight = ingredient.defaultWeight {
            coreData.setValue(NSNumber(floatLiteral: defaultWeight), forKey: "defaultWeight")
        }
        if let temperature = ingredient.temperature {
            coreData.temperature = NSNumber(floatLiteral: temperature.value)
        }
        if let extraAmount = ingredient.extraAmount {
            coreData.extraAmount = NSNumber(floatLiteral: extraAmount)
        }
        coreData.extraUnit = ingredient.extraUnit

        return coreData
    }

    /// - Parameter localizeName: When true, a default-recipe ingredient name is
    ///   resolved to the user's language. Only set for the app's built-in default
    ///   recipes — never for user-created recipes, so their input is preserved.
    func convertToExternal(ingredient: XCIngredient, localizeName: Bool = false) -> Ingredient {
        let storedName = ingredient.name!
        let name = localizeName ? DefaultLocalization.ingredientName(storedName) : storedName
        let defaultPercentage = ingredient.defaultPercentage!.doubleValue
        let defaultWeight = (ingredient.value(forKey: "defaultWeight") as? NSNumber)?.doubleValue
        let isFlour = ingredient.isFlour
        var temperature: Temperature? = nil
        if let temp = ingredient.temperature?.doubleValue {
            temperature = Temperature(value: temp, measurement: Settings.shared.preferredTemp())
        }
        let extraAmount = ingredient.extraAmount?.doubleValue
        let extraUnit = ingredient.extraUnit

        return Ingredient(name: name, isFlour: isFlour, defaultPercentage: defaultPercentage, temperature: temperature, defaultWeight: defaultWeight, extraAmount: extraAmount, extraUnit: extraUnit)
    }
}
