//
//  RecipeScannerTypes.swift
//  Doughy
//

import Foundation
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels

// MARK: - Parsed recipe schema

/// The parsed recipe assembled from the local regex parser and/or the model's
/// `ParsedRecipeEssentials` output. Not itself model-generated, so it carries no
/// `@Generable`/`@Guide` — model-facing guidance belongs on `ParsedRecipeEssentials`.
@available(iOS 26, *)
struct ParsedRecipe: Sendable {
    /// Recipe title, or "" when the source text has none.
    var name: String
    /// True when the recipe contains a preferment (poolish, biga, levain, sponge, starter, etc.).
    var hasPreferment: Bool
    /// Name of the preferment (e.g. "Poolish", "Levain"). Empty string when hasPreferment is false.
    var prefermentName: String
    /// Every ingredient in the recipe, from both the main dough and any preferment.
    var ingredients: [ParsedIngredient]
    /// Recipe steps. Always empty for scans: instruction extraction is intentionally
    /// out of scope for the scanner (ingredients only). Website imports carry their
    /// instructions separately on `WebsiteRecipeDraft`.
    var instructions: [String]
}

@available(iOS 26, *)
@Generable
struct ParsedRecipeEssentials: Sendable {
    @Guide(description: """
        The recipe's title or name, exactly as it appears in the text (e.g. "Sourdough \
        Boule", "Grandma's Rye Bread"). Use an empty string if no recipe title or name \
        is explicitly written — do NOT invent or infer a name from the ingredients. \
        Many scanned photos show only an ingredient list with no title, in which case \
        this must be "".
        """)
    var name: String
    @Guide(description: """
        True only when the recipe contains a preferment — a separately mixed poolish, \
        biga, levain, sponge, starter, or tangzhong section that is added to the main \
        dough later. False when every ingredient goes straight into one dough.
        """)
    var hasPreferment: Bool
    @Guide(description: """
        The preferment's name exactly as the recipe calls it (e.g. "Poolish", "Biga", \
        "Levain"). Empty string when hasPreferment is false.
        """)
    var prefermentName: String
    /// Every ingredient in the recipe, from both the main dough and any preferment.
    var ingredients: [ParsedIngredient]
}

@available(iOS 26, *)
@Generable
enum ParsedVolumeUnit: String, Sendable {
    case none
    case teaspoon
    case tablespoon
    case cup
    case fluidOunce
    case ounce
    case pound
    case kilogram
    case milliliter
    case deciliter
    case liter
    case egg
    case count
}

/// The size of an egg, used to convert an "X eggs" quantity (volumeUnit == .egg) to
/// grams. Mirrors `EggSize` in IngredientDensityStore.swift (same raw values), plus
/// `unspecified` for when the recipe gives no size word.
@available(iOS 26, *)
@Generable
enum ParsedEggSize: String, Sendable {
    case unspecified
    case small
    case medium
    case large
    case extraLarge
    case jumbo
}

/// Which part of an egg a quantity refers to (volumeUnit == .egg). Mirrors `EggPart`
/// in IngredientDensityStore.swift (same raw values).
@available(iOS 26, *)
@Generable
enum ParsedEggPart: String, Sendable {
    case whole
    case white
    case yolk
}

/// A closed set of common baking ingredients with known densities, used to convert
/// volume measurements (cups/tablespoons/teaspoons) to grams without relying on the
/// model to do unit-conversion math. The model maps each ingredient's literal name
/// (e.g. "Wholemeal flour") to the closest category here (e.g. "wholeWheatFlour").
@available(iOS 26, *)
@Generable
enum ParsedIngredientCategory: String, Sendable {
    // Flours
    case breadFlour
    case allPurposeFlour
    case cakeFlour
    case wholeWheatFlour
    case ryeFlour
    case speltFlour
    case semolinaFlour
    case oatFlour
    case cornmeal
    case riceFlour
    case almondFlour
    case buckwheatFlour
    case glutenFreeFlourBlend
    case selfRisingFlour
    case tipo00Flour

    // Sweeteners
    case granulatedSugar
    case brownSugar
    case powderedSugar
    case honey
    case mapleSyrup
    case molasses
    case nonDiastaticMalt

    // Fats and oils
    case butter
    case margarine
    case oliveOil
    case vegetableOil
    case coconutOil
    case shortening

    // Dairy
    case milk
    case buttermilk
    case yogurt
    case cream
    case sourCream

    // Leavening and starters
    case instantYeast
    case activeDryYeast
    case freshYeast
    case sourdoughStarter
    case bakingPowder
    case bakingSoda
    case diastaticMalt

    // Salt
    case tableSalt
    case mortonKosherSalt
    case diamondCrystalKosherSalt
    case seaSalt

    // Other
    case water
    case eggs
    case seeds
    case nuts
    case spices
    case cocoaPowder
    case chocolateChips
    /// Use when no other category is a reasonable match.
    case other
}

@available(iOS 26, *)
@Generable
struct ParsedIngredient: Sendable {
    @Guide(description: """
        True only when this ingredient's own text directly states a gram amount with \
        "g", "gram", or "grams" (e.g. "325 grams flour" or "flour (325 g)"). False for \
        weights you computed from cups, tablespoons, teaspoons, ounces, milliliters, egg \
        counts, or any other unit.
        """)
    var hasExplicitWeightGrams: Bool
    @Guide(description: """
        Ingredient name, without quantity, exactly as written (e.g. "Wholemeal flour", \
        not "4 cups (512 g) bread flour"). If the recipe offers a choice of two \
        ingredients, put only the primary/recommended one here with notes stripped, and \
        the other in alternativeName. E.g. "4 cups (512 g) all-purpose flour or bread \
        flour, see notes above" -> name: "All-purpose flour", alternativeName: "Bread \
        flour".
        """)
    var name: String
    @Guide(description: """
        The other option if name is a choice between two ingredients (e.g. name: \
        "All-purpose flour", alternativeName: "Bread flour"). Empty string if none.
        """)
    var alternativeName: String
    @Guide(description: """
        The closest matching category for this ingredient from the fixed list, based on \
        its name and likely density. Map common synonyms and variants to their closest \
        category rather than falling back to "other", e.g.: "Wholemeal flour" -> \
        wholeWheatFlour, "Diamond Crystal kosher salt" -> diamondCrystalKosherSalt, "Morton \
        kosher salt" -> mortonKosherSalt, plain "kosher salt" -> mortonKosherSalt, \
        "EVOO" -> oliveOil, \
        "00 flour" or "pizza flour" -> breadFlour, margarine -> margarine, "confectioners' \
        sugar" or "icing sugar" -> powderedSugar, "caster sugar" or "superfine sugar" -> \
        granulatedSugar, "demerara sugar", "turbinado sugar", or "raw sugar" -> brownSugar, \
        cocoa or cocoa powder -> cocoaPowder, chocolate chips/chunks/disks/fèves -> \
        chocolateChips, "masa harina", "masa de maíz", "harina de maíz", or any nixtamalized \
        corn flour (e.g. Maseca) -> cornmeal. Use "other" only if nothing reasonably matches.
        """)
    var category: ParsedIngredientCategory
    @Guide(description: """
        The gram amount stated DIRECTLY in the recipe text for this ingredient — look \
        for a number followed by "g" or "grams", anywhere in the ingredient's text, not \
        just in parentheses (e.g. "(512 g)" -> 512, "1,000 grams" -> 1000, "(10 to 15 \
        grams)" -> 12.5 using the midpoint of the range, "2 cups (455 g) lukewarm water" \
        -> 455). A gram value ALWAYS belongs in weightGrams, never in volumeAmount, even \
        if no other unit is given for this ingredient. Extract this independently of \
        volumeAmount: if the recipe shows both a cup/tablespoon/teaspoon/ounce amount AND \
        a gram amount for the same ingredient, set weightGrams to the gram value exactly \
        as written — do NOT compute or convert it from the other amount. Ignore gram \
        amounts that belong to a secondary "plus" aside such as "plus more for \
        dusting" or "plus 30 g for greasing the pan" — those are not part of this \
        ingredient's amount, and if the only gram amount is such an aside, weightGrams \
        is 0 (e.g. "4 cups flour, plus 30 g for dusting" -> weightGrams: 0, \
        volumeAmount: 4). CRITICAL: never \
        compute, estimate, or infer a gram value from a volume — if the recipe text \
        contains no "g" or "grams" for this ingredient, weightGrams MUST be exactly 0, \
        even if you can calculate an approximate weight from the volume.
        """)
    var weightGrams: Double
    @Guide(description: """
        The cup/tablespoon/teaspoon/ounce/milliliter/egg amount stated for this \
        ingredient (e.g. "4 cups" -> 4, "2 to 3 teaspoons" -> 2.5 using the midpoint of \
        the range, "8 1/2 ounces" -> 8.5, "250ml" -> 250, "2 large eggs" -> 2). Extract \
        this independently of weightGrams — both fields can be nonzero for the same \
        ingredient (e.g. "4 cups (512 g) flour" has weightGrams: 512 AND volumeAmount: \
        4). Never put a gram value here — a number followed by "g" or "grams" always \
        belongs in weightGrams instead, even if it's the only quantity given (e.g. \
        "(455 g) lukewarm water" with no cup amount has weightGrams: 455 and \
        volumeAmount: 0, NOT volumeAmount: 455). Set volumeAmount to 0 if the recipe \
        gives no cup/tablespoon/teaspoon/ounce/milliliter/deciliter/liter/egg amount for this ingredient \
        (e.g. "4 cloves garlic", or no measurable quantity at all such as "butter for \
        greasing").
        """)
    var volumeAmount: Double
    @Guide(description: """
        The unit that volumeAmount is measured in. Use "ounce", "pound", or "kilogram" \
        for weights given in those units (e.g. "4 ounces chocolate" -> 4, ounce; "1 1/4 \
        pounds chocolate" -> 1.25, pound — NOT a gram value). Fluid ounces are a volume, \
        never the mass "ounce": "8 fl oz milk" -> volumeAmount: 8, volumeUnit: \
        fluidOunce. Use "milliliter" for "ml" \
        amounts. Use "deciliter" for "dl"/"deciliter"/"decilitre" amounts (common in \
        Nordic and Icelandic recipes, e.g. "2 dl mjöl" -> 2, deciliter). Use "liter" \
        for "l"/"liter"/"litre" amounts. Use "egg" when the quantity is a count of eggs, \
        egg whites, or egg yolks (e.g. "2 large eggs" -> volumeAmount: 2, volumeUnit: \
        egg). Use "count" for clear counts of non-egg ingredients such as oranges, \
        lemons, cloves, or basil leaves. Use "none" if volumeAmount is 0. \
        When the recipe uses a non-English unit name, map it to the closest standard unit \
        and keep volumeAmount as the EXACT number written before that unit — do NOT \
        convert the quantity to ml or any other unit, do NOT divide or scale it. The \
        number in the recipe is always volumeAmount; only the unit name changes \
        (e.g. "1 cucharadita sal" -> volumeAmount: 1, volumeUnit: teaspoon — NOT \
        volumeAmount: 0.04 or 5; "1.5 tazas agua" -> volumeAmount: 1.5, volumeUnit: cup \
        — NOT volumeAmount: 354 or 150). Common mappings: Spanish taza/tazas -> cup, \
        cucharada/cucharadas -> tablespoon, cucharadita/cucharaditas -> teaspoon; French \
        tasse -> cup, cuillère à soupe -> tablespoon, cuillère à café -> teaspoon; \
        German Tasse -> cup, Esslöffel -> tablespoon, Teelöffel -> teaspoon; Italian \
        tazza -> cup, cucchiaio -> tablespoon, cucchiaino -> teaspoon; Portuguese \
        xícara/chávena -> cup, colher de sopa -> tablespoon, colher de chá -> teaspoon; \
        Icelandic bolli -> cup, matskeið -> tablespoon, teskeið/teskeiðar -> teaspoon; \
        Japanese カップ -> cup, 大さじ/大匙 -> tablespoon, 小さじ/小匙 -> teaspoon; \
        Korean 컵 -> cup, 큰술 -> tablespoon, 작은술 -> teaspoon.
        """)
    var volumeUnit: ParsedVolumeUnit
    @Guide(description: """
        The size of egg specified, only relevant when volumeUnit is "egg" (e.g. "2 \
        large eggs" -> large, "3 extra-large egg whites" -> extraLarge). If the recipe \
        gives an egg quantity with no size word (e.g. "3 eggs"), use "unspecified" — \
        do not guess a size.
        """)
    var eggSize: ParsedEggSize
    @Guide(description: """
        Which part of the egg this quantity refers to, only relevant when volumeUnit \
        is "egg". Use "white" for "egg whites"/"whites" (e.g. "3 egg whites" -> \
        volumeAmount: 3, volumeUnit: egg, eggPart: white), "yolk" for "egg \
        yolks"/"yolks", and "whole" for whole eggs (e.g. plain "2 eggs").
        """)
    var eggPart: ParsedEggPart
    @Guide(description: """
        True only if this ingredient IS a flour (bread flour, all-purpose flour, whole wheat \
        flour, rye flour, semolina, self-rising flour, etc.). Water, salt, yeast, sugar, oil, \
        butter, eggs, milk, seeds, and every other ingredient are NOT flour and must be false.
        """)
    var isFlour: Bool
    @Guide(description: """
        True if this ingredient is part of a preferment (poolish, biga, levain, sponge, \
        starter, sourdough starter, tangzhong, etc.) that is mixed ahead of time and added \
        to the main dough later. False if it's mixed directly into the final/main dough.
        """)
    var isPreferment: Bool
}

// MARK: - Ingredient name cleanup pass

/// A single entry from the on-device cleanup pass over an already-parsed ingredient list
/// (see `RecipeScanner.cleanIngredientNames`). Reviews names for leftover formatting
/// artifacts the local regex parser missed, and flags entries that don't look like real
/// ingredients at all - without touching quantities/units, which the parser already gets right.
@available(iOS 26, *)
@Generable
struct IngredientNameReview: Sendable {
    @Guide(description: """
        The index of this ingredient in the list provided, matching its position exactly \
        (0 for the first ingredient, 1 for the second, and so on).
        """)
    var index: Int
    @Guide(description: """
        The ingredient name with any leftover formatting artifacts removed: a category or \
        section label (e.g. "Additional toppings:", "Optional:", "For the crust:"), OCR \
        noise, or stray quantity words that don't belong in the name. Keep it as close to \
        the original as possible - only remove things that clearly aren't part of the \
        ingredient itself. Leave the name unchanged if it already looks correct.
        """)
    var cleanedName: String
    @Guide(description: """
        False only when this entry is clearly NOT a real ingredient - e.g. it reads like a \
        fragment of cooking instructions, a section header, or scanner noise rather than \
        something a baker would add to the dough. True for anything that's plausibly a real \
        ingredient, even an unusual one - when in doubt, use true.
        """)
    var isValidIngredient: Bool
}

@available(iOS 26, *)
@Generable
struct IngredientNameReviewBatch: Sendable {
    var reviews: [IngredientNameReview]
}

// MARK: - Errors

@available(iOS 26, *)
enum ScanError: LocalizedError {
    case invalidImage
    case noTextFound
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case noFlourFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return String(localized: "scan.error.invalid_image", defaultValue: "Could not read the selected image.")
        case .noTextFound:
            return String(localized: "scan.error.no_text_found", defaultValue: "No readable text was found in the image.")
        case .deviceNotEligible:
            return String(localized: "scan.error.device_not_eligible", defaultValue: "Recipe scanning requires iPhone 15 or later.")
        case .appleIntelligenceNotEnabled:
            return String(localized: "scan.error.apple_intelligence_not_enabled", defaultValue: "Apple Intelligence is not enabled. Turn it on in Settings > Apple Intelligence & Siri.")
        case .modelNotReady:
            return String(localized: "scan.error.model_not_ready", defaultValue: "Apple Intelligence is still setting up. Please try again in a few minutes.")
        case .noFlourFound:
            return String(localized: "scan.error.no_flour_found", defaultValue: "Could not identify any flour in the recipe. Please enter the recipe manually.")
        }
    }
}

// MARK: - Resolved recipe

/// An ingredient after volume-to-grams resolution. Most ingredients end up with a
/// `weightGrams` value. Ingredients in low-confidence categories (spices, seeds, nuts,
/// "other") that only have a volume measurement and no learned conversion become
/// "extra" ingredients: they're left in their original unit (`extraAmount`/`extraUnit`)
/// rather than forced through a generic density estimate.
@available(iOS 26, *)
struct ResolvedIngredient: Sendable {
    var name: String
    /// The alternative ingredient name when the recipe presents this ingredient as a
    /// choice between two options (e.g. "all-purpose flour or bread flour"). Title-cased
    /// the same way as `name`. `nil` if the recipe gave only one name.
    var alternativeName: String?
    var category: ParsedIngredientCategory
    var weightGrams: Double
    var isFlour: Bool
    var isPreferment: Bool
    var isExtra: Bool
    var extraAmount: Double
    var extraUnit: ParsedVolumeUnit
    /// The water temperature implied by a descriptor in the original ingredient name
    /// (e.g. "lukewarm water"), in Fahrenheit. Only set for `.water` ingredients whose
    /// name matched a known descriptor; that descriptor is stripped from `name`.
    var temperatureFahrenheit: Double?
    /// Set when the on-device cleanup pass (`RecipeScanner.cleanIngredientNames`) flagged
    /// this entry as possibly not being a real ingredient (e.g. leaked instruction text).
    /// Surfaced to the user in the scan review step rather than silently kept or dropped.
    var isUncertain: Bool = false
}

@available(iOS 26, *)
struct ResolvedRecipe: Sendable {
    var name: String
    var hasPreferment: Bool
    var prefermentName: String
    var ingredients: [ResolvedIngredient]
    var instructions: [String]
}

// MARK: - Scan result

/// Bundles the raw OCR text and both the model's raw output and the post-processed
/// (volume-to-grams resolved) recipe, so the full pipeline can be inspected for debugging.
@available(iOS 26, *)
struct ScanResult: Sendable {
    struct PageOCR: Sendable {
        var imageIndex: Int
        var text: String
    }

    var ocrText: String
    var pageOCR: [PageOCR]
    var rawRecipe: ParsedRecipe
    var resolvedRecipe: ResolvedRecipe
}

#endif
