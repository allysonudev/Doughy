//
//  CalculatedIngredientConverter.swift
//  Doughy
//
//  Created by urickg on 3/30/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class CalculatedIngredientConverter: NSObject {
    private let objectFactory = ObjectFactory.shared
    private let settings = Settings.shared
    
    static let shared = CalculatedIngredientConverter()
    
    private override init() { }
    
    func convertToCoreData(ingredient: CalculatedIngredient) -> XCCalculatedIngredient {
        let coreData = objectFactory.createCalculatedIngredient()
        
        coreData.name = ingredient.name
        coreData.percentage = NSNumber(floatLiteral: ingredient.percentage)
        coreData.totalPercentage = NSNumber(floatLiteral: ingredient.totalPercentage)
        coreData.isFlour = ingredient.isFlour
        if let temperature = ingredient.temperature {
            coreData.temperature = NSNumber(floatLiteral: temperature.value)
        }
        coreData.weight = NSNumber(floatLiteral: ingredient.weight)
        if let extraAmount = ingredient.extraAmount {
            coreData.extraAmount = NSNumber(floatLiteral: extraAmount)
        }
        coreData.extraUnit = ingredient.extraUnit

        return coreData
    }

    func convertToExternal(ingredient: XCCalculatedIngredient) -> CalculatedIngredient {
        let name = ingredient.name!
        let percentage = ingredient.percentage!.doubleValue
        let totalPercentage = ingredient.totalPercentage!.doubleValue
        let isFlour = ingredient.isFlour
        var temperature: Temperature? = nil
        if let temp = ingredient.temperature?.doubleValue {
            temperature = Temperature(value: temp, measurement: settings.preferredTemp())
        }
        let weight = ingredient.weight!.doubleValue
        let extraAmount = ingredient.extraAmount?.doubleValue
        let extraUnit = ingredient.extraUnit

        return CalculatedIngredient(name: name, isFlour: isFlour, percentage: percentage, totalPercentage: totalPercentage, temperature: temperature, weight: weight, extraAmount: extraAmount, extraUnit: extraUnit)
    }
}
