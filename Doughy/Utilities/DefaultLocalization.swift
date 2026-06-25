//
//  DefaultLocalization.swift
//  Doughy
//
//  Resolves the canonical English names used in the built-in default recipes
//  (ingredient names, preferment names, and collection names) to localized
//  display strings. Resolution happens at display time, mirroring how default
//  recipe names are localized in RecipeConverter.
//
//  Lookups are keyed by the canonical English string that the factory seeds.
//  If there's no matching key, or the active locale has no translation for it,
//  the stored string is returned unchanged — so user-created or user-edited
//  names are always left as-is.
//

import Foundation

enum DefaultLocalization {

    /// Ingredient and preferment names used by the default recipes. Where an
    /// equivalent name already ships as a density key, that key is reused so the
    /// same translation appears in recipes and in the conversions settings.
    private static let ingredientKeys: [String: String] = [
        "Tipo 00 Flour":      "density.ingredient.tipo_00_flour",
        "Bread Flour":        "density.ingredient.bread_flour",
        "Water":              "density.ingredient.water",
        "Instant Yeast":      "density.ingredient.instant_yeast",
        "Olive Oil":          "density.ingredient.olive_oil",
        "Non-Diastatic Malt": "density.ingredient.non_diastatic_malt",
        "Fine Sea Salt":      "default_ingredient.fine_sea_salt",
        "Sugar":              "default_ingredient.sugar",
        "Poolish":            "default_ingredient.poolish",
    ]

    private static let collectionKeys: [String: String] = [
        "Pizza":  "default_collection.pizza",
        "Bagels": "default_collection.bagels",
    ]

    /// Localized display name for a stored ingredient (or preferment) name.
    static func ingredientName(_ storedName: String) -> String {
        resolve(storedName, in: ingredientKeys)
    }

    /// Localized display name for a stored collection name.
    static func collectionName(_ storedName: String) -> String {
        resolve(storedName, in: collectionKeys)
    }

    /// Resolves a recipe's display name from its stored (canonical) name and its
    /// optional defaultKey: built-in recipes show a localized name, everything
    /// else shows the stored name as entered. This is the single source of truth
    /// used both when presenting a recipe and when matching a stored recipe back
    /// from a possibly-localized name (see RecipeReader.getRecipe).
    static func recipeDisplayName(storedName: String, defaultKey: String?) -> String {
        guard let key = defaultKey else { return storedName }
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? storedName : localized
    }

    /// Localized text for a default-recipe instruction step. The canonical
    /// English step text is itself the lookup key, so a step the user has edited
    /// (no longer matching) simply falls through to the stored text.
    static func instructionStep(_ storedStep: String) -> String {
        let localized = NSLocalizedString(storedStep, comment: "")
        return localized == storedStep ? storedStep : localized
    }

    private static func resolve(_ storedName: String, in keys: [String: String]) -> String {
        guard let key = keys[storedName] else { return storedName }
        let localized = NSLocalizedString(key, comment: "")
        return localized == key ? storedName : localized
    }
}
