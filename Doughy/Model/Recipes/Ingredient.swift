//
//  Ingredient.swift
//  Doughy
//
//  Created by urickg on 3/30/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class Ingredient: NSObject {
    
    let name: String
    let isFlour: Bool
    var defaultPercentage: Double
    let temperature: Temperature?
    /// Quantity for "extra" ingredients that aren't converted to grams (e.g. "2 tbsp" of
    /// rosemary). Nil for normal ingredients.
    let extraAmount: Double?
    /// Unit for extraAmount (e.g. "teaspoon", "tablespoon", "cup"). Nil for normal ingredients.
    let extraUnit: String?

    init(name: String, isFlour: Bool, defaultPercentage: Double, temperature: Temperature?,
         extraAmount: Double? = nil, extraUnit: String? = nil) {
        self.name = name
        self.isFlour = isFlour
        self.defaultPercentage = defaultPercentage
        self.temperature = temperature
        self.extraAmount = extraAmount
        self.extraUnit = extraUnit
    }

}
