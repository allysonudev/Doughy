//
//  RecipeBuilder.swift
//  Doughy
//
//  Created by urickg on 3/29/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

class RecipeBuilder: NSObject {
    
    private(set) var isModified: Bool = false
    private(set) var existingName: String?
    private(set) var existingCollection: String?
    
    var name: String? {
        didSet {
            isModified = true
        }
    }
    var collection: String? {
        didSet {
            isModified = true
        }
    }
    var defaultWeight: Double? {
        didSet {
            isModified = true
        }
    }
    var sourceURL: URL? {
        didSet {
            isModified = true
        }
    }
    var measurementMode: RecipeMeasurementMode = .percent
    var instructions: [Instruction]? {
        didSet {
            isModified = true
        }
    }
    var containsPreferment: Bool = false
    var prefermentBuilder = PrefermentBuilder()
    var mainDoughBuilder = MainDoughBuilder()
    
    override init() { }

    init(recipe: RecipeProtocol) {
        self.existingName = recipe.name
        self.name = recipe.name
        self.existingCollection = recipe.collection
        self.collection = recipe.collection
        self.defaultWeight = recipe.defaultWeight
        self.sourceURL = recipe.sourceURL
        self.measurementMode = recipe.measurementMode
        self.instructions = recipe.instructions
        if recipe is PrefermentRecipe {
            let totalPercent = recipe.ingredients
                .map { $0.defaultPercentage }
                .reduce(0, +)
            let totalFlourPercent = recipe.ingredients
                .filter { $0.isFlour }
                .map { $0.defaultPercentage }
                .reduce(0, +)
            let totalFlourWeight = (totalFlourPercent / totalPercent) * recipe.defaultWeight
            self.containsPreferment = true
            let prefermentRecipe = recipe as! PrefermentRecipe
            self.prefermentBuilder = PrefermentBuilder(preferment: prefermentRecipe.preferment, totalFlourWeight: totalFlourWeight)
            let ingredients = recipe.ingredients
            self.mainDoughBuilder = MainDoughBuilder(ingredients: ingredients)
        }
        let ingredients = recipe.ingredients
        self.mainDoughBuilder = MainDoughBuilder(ingredients: ingredients)
    }
    
    func build() throws -> RecipeProtocol {
        guard let collection = collection else {
            throw RecipeBuilderError.missingCollection
        }
        guard let name = name else {
            throw RecipeBuilderError.missingName
        }
        guard let defaultWeight = defaultWeight else {
            throw RecipeBuilderError.missingDefaultWeight
        }
        guard let instructions = instructions else {
            throw RecipeBuilderError.missingInstructions
        }
        guard measurementMode == .weight || !mainDoughBuilder.flourBuilders.isEmpty else {
            throw RecipeBuilderError.invalidIngredients
        }
        var ingredients = [Ingredient]()
        let flours = try mainDoughBuilder.flourBuilders.map { try $0.build() }
        ingredients.append(contentsOf: flours)
        
        guard !mainDoughBuilder.flourBuilders.isEmpty || !mainDoughBuilder.ingredientBuilders.isEmpty else {
            throw RecipeBuilderError.invalidIngredients
        }
        let flourWeight = measurementMode == .weight
            ? mainDoughBuilder.flourBuilders.map { $0.weight ?? 0 }.reduce(0, +)
            : calculateDefaultFlourWeight()
        let remainingIngredients = try mainDoughBuilder.ingredientBuilders.map {
            try $0.build(totalFlourWeight: flourWeight)
        }
        ingredients.append(contentsOf: remainingIngredients)
        if containsPreferment {
            let preferment = try prefermentBuilder.build(totalFlourWeight: flourWeight)
            let result = PrefermentRecipe(name: name, collection: collection,
                                    defaultWeight: defaultWeight, ingredients: ingredients,
                                    preferment: preferment, instructions: instructions,
                                    measurementMode: measurementMode,
                                    sourceURL: sourceURL)
            try Self.validatePrefermentRecipe(recipe: result)
            return result
        }
        
        return Recipe(name: name, collection: collection,
                      defaultWeight: defaultWeight, ingredients: ingredients,
                      instructions: instructions,
                      measurementMode: measurementMode,
                      sourceURL: sourceURL)
    }
    
    /// Shared with `PrefermentTool` (the Adjust tab's add/remove-preferment feature) so both
    /// entry points enforce the same rule: baker's percentages on the main dough list already
    /// represent the recipe's total (main dough + preferment combined), so no preferment
    /// ingredient can claim more than the matching main dough ingredient's total.
    static func validatePrefermentRecipe(recipe: PrefermentRecipe) throws {
        let preferment = recipe.preferment
        let multiplier = preferment.flourPercentage / 100
        try preferment.ingredients.forEach { prefIng in
            guard let match = recipe.ingredients.first(where: { $0.name == prefIng.name }) else {
                throw RecipeBuilderError.mainDoughMissingPreferment(ingredient: prefIng)
            }
            if prefIng.defaultPercentage * multiplier > match.defaultPercentage {
                throw RecipeBuilderError.mainDoughLessThanPreferment(mainDough: match, prefermentIngredient: prefIng)
            }
        }
    }
    
    func calculateDefaultFlourWeight() -> Double {
        let totalUnknownWeight = self.mainDoughBuilder.ingredientBuilders
            .filter { $0.mode == .weight }
            .map { $0.weight ?? 0 }
            .reduce(0, +)
        let totalKnownPercent = self.mainDoughBuilder.ingredientBuilders
            .filter { $0.mode == .percent }
            .map { $0.percent ?? 0 }
            // Start at 100 because flour equals 100
            .reduce(100, +)
        let totalKnownWeight = defaultWeight! - totalUnknownWeight
        return (100 / totalKnownPercent) * totalKnownWeight
    }
    
    func calculateWeight(ingredientBuilder: IngredientBuilder) -> Double {
        if ingredientBuilder.weight != nil { return ingredientBuilder.weight! }
        let flourWeight = calculateDefaultFlourWeight()
        return (ingredientBuilder.percent! / 100) * flourWeight
    }
    
    func calculateWeight(flourBuilder: FlourBuilder) -> Double {
        let flourWeight = calculateDefaultFlourWeight()
        return (flourBuilder.percent! / 100) * flourWeight
    }
}

/// Extension to add support for adding and removing ingredient builders.
extension RecipeBuilder {
    func prepareForTransitionToMainDough() {
        if !containsPreferment { return }
        if !prefermentBuilder.isReady() {
            print("Preparing for transition although preferment not ready")
            return
        }
        for prefFlour in prefermentBuilder.flourBuilders {
            let needsToAddToMainDough = !self.mainDoughBuilder.flourBuilders.contains(where: {
                if $0.name == nil { return false }
                return prefFlour.name! == $0.name!
            })
            if needsToAddToMainDough {
                let flourCopy = prefFlour.copy() as! FlourBuilder
                flourCopy.percent = flourCopy.percent! * (prefermentBuilder.totalFlourPercent! / 100)
                self.mainDoughBuilder.flourBuilders.append(flourCopy)
            }
        }
        
        for prefIngredient in prefermentBuilder.ingredientBuilders {
            if prefIngredient.name == nil { continue }
            let needsToAddToMainDough = !self.mainDoughBuilder.ingredientBuilders.contains(where: {
                if $0.name == nil { return false }
                return prefIngredient.name! == $0.name!
            })
            if needsToAddToMainDough {
                let ingredientCopy = prefIngredient.copy() as! IngredientBuilder
                ingredientCopy.percent = ingredientCopy.percent! * (prefermentBuilder.totalFlourPercent! / 100)
                self.mainDoughBuilder.ingredientBuilders.append(ingredientCopy)
            }
        }
    }

    func addFlour(flourBuilder: FlourBuilder) {
        self.mainDoughBuilder.flourBuilders.append(flourBuilder)
        self.isModified = true
    }
    
    func addPrefermentIngredient(ingredientBuilder: PrefermentIngredientBuilder) {
        if ingredientBuilder.isFlour {
            self.prefermentBuilder.flourBuilders.append(ingredientBuilder)
        }
        else {
            self.prefermentBuilder.ingredientBuilders.append(ingredientBuilder)
        }
        self.isModified = true
    }

    func addIngredient(ingredientBuilder: IngredientBuilder) {
        self.mainDoughBuilder.ingredientBuilders.append(ingredientBuilder)
        self.isModified = true
    }
    
    func removeFlour(flourBuilder: FlourBuilder) {
        self.mainDoughBuilder.flourBuilders.removeAll { $0 == flourBuilder }
        self.isModified = true
    }
    
    func removeIngredient(ingredientBuilder: IngredientBuilder) {
        self.mainDoughBuilder.ingredientBuilders.removeAll { $0 == ingredientBuilder }
        self.isModified = true
    }

    func removePrefermentIngredient(ingredientBuilder: PrefermentIngredientBuilder) {
        if ingredientBuilder.isFlour {
            self.prefermentBuilder.flourBuilders.removeAll { $0 == ingredientBuilder }
        }
        else {
            self.prefermentBuilder.ingredientBuilders.removeAll { $0 == ingredientBuilder }
        }
        self.isModified = true
    }
}

/// Readiness predicate methods for RecipeBuilder
extension RecipeBuilder {
    func isReadyToAddIngredients() -> Bool {
        return name != nil && collection != nil && defaultWeight != nil
    }
    
    func isFlourReady() -> Bool {
        var totalPercent = 0.0
        for flour in mainDoughBuilder.flourBuilders {
            if !flour.isReady() {
                return false
            }
            totalPercent += flour.percent!
        }
        return totalPercent == 100
    }
    
    func isIngredientsReady() -> Bool {
        for ingredient in mainDoughBuilder.ingredientBuilders {
            if !ingredient.isReady() {
                return false
            }
        }
        return true
    }

    func isPrefermentIngredientsReady() -> Bool {
        for ingredient in prefermentBuilder.ingredientBuilders {
            if !ingredient.isReady() {
                return false
            }
        }
        return true
    }
}

enum RecipeBuilderError: Error {
    case missingName
    case missingCollection
    case missingDefaultWeight
    case missingInstructions
    case invalidIngredients
    case mainDoughLessThanPreferment(mainDough: Ingredient, prefermentIngredient: Ingredient)
    case mainDoughMissingPreferment(ingredient: Ingredient)
}
