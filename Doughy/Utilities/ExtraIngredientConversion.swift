//
//  ExtraIngredientConversion.swift
//  Doughy
//

import Foundation

/// A suggested gram conversion for an "additional ingredient" (e.g. "2 large eggs"
/// or "1/2 cup chocolate chips"), used to offer folding it into the recipe's
/// percentage/weight-based ingredients so it contributes to the dough's total weight.
struct ExtraIngredientConversionSuggestion {
    let grams: Double
    let description: String
}

/// Matches "additional ingredients" (eggs, volume measurements) against known gram
/// conversions so a weight-conscious baker can fold them into the dough's total weight.
enum ExtraIngredientConversion {

    /// Count-based extras like eggs, leaves, or zest should not be treated as
    /// volume-to-weight conversion candidates.
    static func isCountBasedUnit(_ unit: String) -> Bool {
        unit == "count" || unit == "egg"
    }

    /// The unknown-conversion prompt is for volume units, not count-based extras.
    static func canLearnGramConversion(for unit: String) -> Bool {
        !isCountBasedUnit(unit)
    }

    /// The optional convert-to-weight sheet should also skip count-based extras.
    static func canSuggestWeightConversion(for unit: String) -> Bool {
        !isCountBasedUnit(unit)
    }

    /// Returns a suggested gram conversion for `name`/`amount`/`unit`, or `nil` if no
    /// known conversion applies.
    static func suggest(name: String, amount: Double, unit: String) -> ExtraIngredientConversionSuggestion? {
        let lowerName = name.lowercased()

        if unit == "count" {
            return eggSuggestion(lowerName: lowerName, amount: amount)
        }

        if unit == "ounce" {
            let grams = amount * UnitConversion.gramsPerOunce
            return ExtraIngredientConversionSuggestion(
                grams: grams,
                description: String(
                    format: String(localized: "conversion.suggestion.volume", defaultValue: "%@ %@ \u{2248} %d g"),
                    VolumeUnitFormatter.format(amount: amount, unit: unit),
                    name,
                    Int(grams.rounded())
                )
            )
        }

        guard let densityUnit = DensityUnit(rawValue: unit), let category = category(forName: lowerName) else {
            return nil
        }
        let cups = amount / densityUnit.unitsPerCup
        let gramsPerCup = IngredientDensityStore.shared.gramsPerCup(for: category)
        let grams = cups * gramsPerCup
        return ExtraIngredientConversionSuggestion(
            grams: grams,
            description: String(
                format: String(localized: "conversion.suggestion.volume", defaultValue: "%@ %@ \u{2248} %d g"),
                VolumeUnitFormatter.format(amount: amount, unit: unit),
                name,
                Int(grams.rounded())
            )
        )
    }

    private static func eggSuggestion(lowerName: String, amount: Double) -> ExtraIngredientConversionSuggestion? {
        guard let part = eggPart(from: lowerName) else { return nil }

        let size = eggSize(from: lowerName) ?? IngredientDensityStore.shared.defaultEggSize()
        let gramsPerEgg = IngredientDensityStore.shared.gramsPerEgg(for: size, part: part)
        let grams = amount * gramsPerEgg

        let amountText = amount == amount.rounded() ? String(Int(amount)) : String(format: "%.2g", amount)
        let noun: String
        switch part {
        case .whole:
            noun = amount == 1
                ? String(localized: "egg.noun.whole.one", defaultValue: "egg")
                : String(localized: "egg.noun.whole.many", defaultValue: "eggs")
        case .white:
            noun = amount == 1
                ? String(localized: "egg.noun.white.one", defaultValue: "egg white")
                : String(localized: "egg.noun.white.many", defaultValue: "egg whites")
        case .yolk:
            noun = amount == 1
                ? String(localized: "egg.noun.yolk.one", defaultValue: "egg yolk")
                : String(localized: "egg.noun.yolk.many", defaultValue: "egg yolks")
        }
        return ExtraIngredientConversionSuggestion(
            grams: grams,
            description: String(
                format: String(localized: "conversion.suggestion.egg", defaultValue: "%@ %@ %@ \u{2248} %d g"),
                amountText,
                size.localizedDisplayName.lowercased(),
                noun,
                Int(grams.rounded())
            )
        )
    }

    /// Returns the egg part for `lowerName`, or nil if the name doesn't refer to eggs.
    /// Checks English keywords first, then localized egg nouns so non-English names
    /// (e.g. "Eigelb", "blanc d'œuf", "달걀 노른자") are recognized.
    /// Yolk and white are checked before whole so "egg yolk" / "Eigelb" don't
    /// accidentally match the shorter whole-egg noun ("egg" / "Ei").
    private static func eggPart(from lowerName: String) -> EggPart? {
        if lowerName.contains("yolk") { return .yolk }
        if [String(localized: "egg.noun.yolk.one"), String(localized: "egg.noun.yolk.many")]
            .contains(where: { lowerName.contains($0.lowercased()) }) { return .yolk }

        if lowerName.contains("white") { return .white }
        if [String(localized: "egg.noun.white.one"), String(localized: "egg.noun.white.many")]
            .contains(where: { lowerName.contains($0.lowercased()) }) { return .white }

        if lowerName.contains("egg") { return .whole }
        if [String(localized: "egg.noun.whole.one"), String(localized: "egg.noun.whole.many")]
            .contains(where: { lowerName.contains($0.lowercased()) }) { return .whole }

        return nil
    }

    private static func eggSize(from lowerName: String) -> EggSize? {
        // English keywords first; extra large before large to avoid substring collision.
        if lowerName.contains("extra large") || lowerName.contains("extra-large") || lowerName.contains(" xl") {
            return .extraLarge
        }
        if lowerName.contains("jumbo") { return .jumbo }
        if lowerName.contains("large") { return .large }
        if lowerName.contains("medium") { return .medium }
        if lowerName.contains("small") { return .small }

        // Fallback: localized size names, longest first so e.g. "Extra Groß" is matched
        // before "Groß" when both are substrings of the input.
        return EggSize.allCases
            .map { ($0, $0.localizedDisplayName.lowercased()) }
            .sorted { $0.1.count > $1.1.count }
            .first { lowerName.contains($0.1) }?
            .0
    }

    /// Returns the `IngredientCategory` for the given ingredient display name, or `nil`
    /// if it doesn't match any known density category. Used by the result view to offer
    /// volume-unit alternatives for gram-based ingredients.
    static func ingredientCategory(forName name: String) -> IngredientCategory? {
        category(forName: name.lowercased())
    }

    /// Maps common ingredient-name keywords to an `IngredientCategory` for
    /// density-based volume conversions. Order matters - more specific keywords are
    /// checked before their more general fallbacks (e.g. "brown sugar" before "sugar").
    private static func category(forName name: String) -> IngredientCategory? {
        let keywordMap: [(IngredientCategory, [String])] = [
            (.breadFlour, ["bread flour"]),
            (.allPurposeFlour, ["all-purpose flour", "all purpose flour", "ap flour"]),
            (.cakeFlour, ["cake flour"]),
            (.wholeWheatFlour, ["whole wheat flour", "whole-wheat flour"]),
            (.ryeFlour, ["rye flour"]),
            (.speltFlour, ["spelt flour"]),
            (.semolinaFlour, ["semolina"]),
            (.oatFlour, ["oat flour"]),
            (.cornmeal, ["cornmeal", "corn meal"]),
            (.riceFlour, ["rice flour"]),
            (.almondFlour, ["almond flour"]),
            (.buckwheatFlour, ["buckwheat flour"]),
            (.glutenFreeFlourBlend, ["gluten-free flour", "gluten free flour"]),
            (.selfRisingFlour, ["self-rising flour", "self rising flour", "self-raising flour", "self raising flour"]),
            (.brownSugar, ["brown sugar"]),
            (.powderedSugar, ["powdered sugar", "confectioners sugar", "confectioner's sugar"]),
            (.granulatedSugar, ["granulated sugar", "white sugar", "sugar"]),
            (.honey, ["honey"]),
            (.mapleSyrup, ["maple syrup"]),
            (.molasses, ["molasses"]),
            (.margarine, ["margarine"]),
            (.butter, ["butter"]),
            (.oliveOil, ["olive oil"]),
            (.vegetableOil, ["vegetable oil", "canola oil"]),
            (.coconutOil, ["coconut oil"]),
            (.shortening, ["shortening"]),
            (.buttermilk, ["buttermilk"]),
            (.sourCream, ["sour cream"]),
            (.yogurt, ["yogurt", "yoghurt"]),
            (.cream, ["cream"]),
            (.milk, ["milk"]),
            (.instantYeast, ["instant yeast"]),
            (.activeDryYeast, ["active dry yeast", "active yeast"]),
            (.freshYeast, ["fresh yeast", "cake yeast"]),
            (.sourdoughStarter, ["sourdough starter", "starter"]),
            (.bakingPowder, ["baking powder"]),
            (.bakingSoda, ["baking soda"]),
            (.mortonKosherSalt, ["morton kosher salt", "morton's kosher salt", "morton kosher", "morton's kosher"]),
            (.diamondCrystalKosherSalt, ["diamond crystal kosher salt", "diamond crystal"]),
            // Unbranded "kosher salt" defaults to Morton (the more common brand in home kitchens).
            // Must come after the Diamond Crystal entry, whose full name also contains "kosher salt".
            (.mortonKosherSalt, ["kosher salt"]),
            (.seaSalt, ["sea salt"]),
            (.tableSalt, ["table salt", "salt"]),
            (.water, ["water"]),
            (.cocoaPowder, ["cocoa powder", "cocoa"]),
            (.chocolateChips, ["chocolate chips", "chocolate chunks", "chocolate"]),
            (.nuts, ["almonds", "walnuts", "pecans", "hazelnuts", "cashews", "pistachios", "peanuts", "nuts"]),
            (.seeds, ["sesame seeds", "poppy seeds", "chia seeds", "flax seeds", "sunflower seeds", "seeds"]),
            (.spices, ["cinnamon", "nutmeg", "cardamom", "ginger", "spices"]),
        ]

        for (category, keywords) in keywordMap {
            if keywords.contains(where: { name.contains($0) }) {
                return category
            }
        }

        // Fallback: match against each category's localized display name so ingredient
        // names entered in non-English locales (e.g. "Smjör", "Beurre") still resolve.
        return IngredientCategory.allCases.first {
            name.contains($0.localizedDisplayName.lowercased())
        }
    }
}
