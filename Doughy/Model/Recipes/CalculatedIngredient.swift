//
//  CalculatedIngredient.swift
//  Doughy
//
//  Created by urickg on 3/30/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class CalculatedIngredient: NSObject {

    let name: String
    let isFlour: Bool
    var percentage: Double
    var totalPercentage: Double
    let temperature: Temperature?
    let weight: Double
    /// Quantity for "extra" ingredients that aren't converted to grams (e.g. "2 tbsp" of
    /// rosemary), scaled by the recipe's scaling ratio. Nil for normal ingredients.
    let extraAmount: Double?
    /// Unit for extraAmount (e.g. "teaspoon", "tablespoon", "cup"). Nil for normal ingredients.
    let extraUnit: String?

    init(name: String, isFlour: Bool,
         percentage: Double, totalPercentage: Double,
         temperature: Temperature?, weight: Double,
         extraAmount: Double? = nil, extraUnit: String? = nil) {
        self.name = name
        self.isFlour = isFlour
        self.percentage = percentage
        self.totalPercentage = totalPercentage
        self.temperature = temperature
        self.weight = weight
        self.extraAmount = extraAmount
        self.extraUnit = extraUnit
    }
    
}
