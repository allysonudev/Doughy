//
//  IngredientWithPercentage.swift
//  Doughy
//
//  Created by urickg on 3/20/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class MeasuredIngredient {
    let ingredient: Ingredient
    let percent: Double
    let temperature: Temperature?
    /// Overrides `ingredient.extraAmount` (at the recipe's default weight) when the
    /// user has tweaked an "extra" ingredient's amount. Nil to use the ingredient's
    /// own `extraAmount`.
    let extraAmountOverride: Double?

    init(ingredient: Ingredient, percent: Double, temperature: Temperature?, extraAmountOverride: Double? = nil) {
        self.ingredient = ingredient
        self.percent = percent
        self.temperature = temperature
        self.extraAmountOverride = extraAmountOverride
    }
}

class MeasuredPreferment {
    let ingredients: [MeasuredIngredient]
    let name: String
    let flourPercentage: Double
    
    init(ingredients: [MeasuredIngredient], name: String, flourPercentage: Double) {
        self.ingredients = ingredients
        self.name = name
        self.flourPercentage = flourPercentage
    }
}
