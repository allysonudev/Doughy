//
//  PrefermentTool.swift
//  Doughy
//

import Foundation

/// Adds or removes a preferment from a recipe from the Adjust tab.
///
/// This doesn't need to rebalance the main dough's ingredient percentages: a
/// `Recipe`'s `ingredients` already store the recipe-wide total for each
/// ingredient (main dough + preferment combined - see `Calculator.calculate`,
/// which nets out the preferment's share for display). So adding a preferment
/// is just attaching a new `Preferment` object, and removing one is just
/// dropping it; the totals - and therefore the recipe's overall hydration -
/// never change.
enum PrefermentTool {

    struct FlourAllocation: Identifiable, Equatable {
        let id = UUID()
        let name: String
        var percentOfPrefermentFlour: Double
    }

    static func waterIngredient(in recipe: any RecipeProtocol) -> Ingredient? {
        recipe.ingredients.first { $0.name.localizedCaseInsensitiveContains("water") }
    }

    static func yeastIngredient(in recipe: any RecipeProtocol) -> Ingredient? {
        recipe.ingredients.first { $0.name.localizedCaseInsensitiveContains("yeast") }
    }

    static func flourIngredients(in recipe: any RecipeProtocol) -> [Ingredient] {
        recipe.ingredients.filter { $0.isFlour }
    }

    /// Whether `recipe` has flour, water, and yeast to carve a preferment out
    /// of, independent of whether one is already attached. Session-scoped
    /// add/remove state in `CalculatorView` can make a recipe's *effective*
    /// preferment-having-ness diverge from `recipe is PrefermentRecipe`, so
    /// that check is kept separate in `canAddPreferment` below.
    static func hasFlourWaterYeast(_ recipe: any RecipeProtocol) -> Bool {
        !flourIngredients(in: recipe).isEmpty
            && waterIngredient(in: recipe) != nil
            && yeastIngredient(in: recipe) != nil
    }

    /// Whether the Adjust tab should offer to add a preferment: the recipe has
    /// flour, water, and yeast to carve a portion out of, and isn't already
    /// built around one.
    static func canAddPreferment(to recipe: any RecipeProtocol) -> Bool {
        guard !(recipe is PrefermentRecipe) else { return false }
        return hasFlourWaterYeast(recipe)
    }

    /// The main dough's flours mirrored onto their own 100%-of-preferment-flour
    /// basis - the starting point for the flour blend editor when a recipe has
    /// more than one flour.
    static func defaultFlourAllocations(for recipe: any RecipeProtocol) -> [FlourAllocation] {
        flourIngredients(in: recipe).map {
            FlourAllocation(name: $0.name, percentOfPrefermentFlour: $0.defaultPercentage)
        }
    }

    static func buildPreferment(
        name: String,
        flourPercentOfTotal: Double,
        flourAllocations: [FlourAllocation],
        hydrationPercent: Double,
        waterName: String,
        yeastPercent: Double?,
        yeastName: String?
    ) -> Preferment {
        var ingredients = flourAllocations.map {
            Ingredient(name: $0.name, isFlour: true, defaultPercentage: $0.percentOfPrefermentFlour, temperature: nil)
        }
        ingredients.append(Ingredient(name: waterName, isFlour: false, defaultPercentage: hydrationPercent, temperature: nil))
        if let yeastPercent, yeastPercent > 0, let yeastName {
            ingredients.append(Ingredient(name: yeastName, isFlour: false, defaultPercentage: yeastPercent, temperature: nil))
        }
        return Preferment(name: name, flourPercentage: flourPercentOfTotal, ingredients: ingredients)
    }

    /// Attaches `preferment` to `recipe`. When `removingYeastNamed` is set, that
    /// ingredient is dropped from the main dough list entirely - used when a
    /// sourdough starter replaces the recipe's commercial yeast rather than
    /// sharing it.
    static func addPreferment(
        _ preferment: Preferment,
        to recipe: any RecipeProtocol,
        removingYeastNamed yeastName: String?
    ) throws -> PrefermentRecipe {
        var ingredients = recipe.ingredients
        if let yeastName {
            ingredients.removeAll { $0.name == yeastName }
        }
        let result = PrefermentRecipe(
            name: recipe.name,
            collection: recipe.collection,
            defaultWeight: recipe.defaultWeight,
            ingredients: ingredients,
            preferment: preferment,
            instructions: recipe.instructions,
            measurementMode: recipe.measurementMode
        )
        try RecipeBuilder.validatePrefermentRecipe(recipe: result)
        return result
    }

    static func removePreferment(from recipe: PrefermentRecipe) -> Recipe {
        Recipe(
            name: recipe.name,
            collection: recipe.collection,
            defaultWeight: recipe.defaultWeight,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            measurementMode: recipe.measurementMode
        )
    }

    /// Distinct preferment names already used across the library, ranked by
    /// frequency then alphabetically, for the name field's suggestion chips.
    static func prefermentNameSuggestions(in store: RecipeStore) -> [String] {
        var counts: [String: Int] = [:]
        var displayNames: [String: String] = [:]
        for collection in store.collections {
            for recipe in collection.recipes {
                guard let preferment = (recipe as? PrefermentRecipe)?.preferment else { continue }
                let key = preferment.name.lowercased()
                counts[key, default: 0] += 1
                displayNames[key] = preferment.name
            }
        }
        return counts.keys
            .sorted { a, b in
                let ca = counts[a] ?? 0, cb = counts[b] ?? 0
                return ca != cb ? ca > cb : a < b
            }
            .compactMap { displayNames[$0] }
    }

    /// The first preferment in the library with the given name (case-insensitive),
    /// used to copy its flour/hydration/yeast settings when the user picks a
    /// library-sourced suggestion chip rather than one of the three seed presets.
    static func existingPreferment(named name: String, in store: RecipeStore) -> Preferment? {
        for collection in store.collections {
            for recipe in collection.recipes {
                if let preferment = (recipe as? PrefermentRecipe)?.preferment,
                   preferment.name.localizedCaseInsensitiveCompare(name) == .orderedSame {
                    return preferment
                }
            }
        }
        return nil
    }
}
