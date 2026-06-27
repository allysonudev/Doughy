//
//  RecipeScanner.swift
//  Doughy

import Foundation
import UIKit
import Vision

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Parsed recipe schema

@available(iOS 26, *)
@Generable
struct ParsedRecipe: Sendable {
    @Guide(description: """
        The recipe's title or name, exactly as it appears in the text (e.g. "Sourdough \
        Boule", "Grandma's Rye Bread"). Use an empty string if no recipe title or name \
        is explicitly written — do NOT invent or infer a name from the ingredients or \
        instructions. Most recipe screenshots show only an ingredient list with no title, \
        in which case this must be "".
        """)
    var name: String
    /// True when the recipe contains a preferment (poolish, biga, levain, sponge, starter, etc.).
    var hasPreferment: Bool
    /// Name of the preferment (e.g. "Poolish", "Levain"). Empty string when hasPreferment is false.
    var prefermentName: String
    /// Every ingredient in the recipe, from both the main dough and any preferment, each with its weight in grams.
    var ingredients: [ParsedIngredient]
    /// Numbered recipe steps.
    var instructions: [String]
}

@available(iOS 26, *)
@Generable
struct ParsedRecipeEssentials: Sendable {
    /// Recipe name.
    var name: String
    /// True when the recipe contains a preferment (poolish, biga, levain, sponge, starter, etc.).
    var hasPreferment: Bool
    /// Name of the preferment (e.g. "Poolish", "Levain"). Empty string when hasPreferment is false.
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
        "00 flour" or "pizza flour" -> breadFlour, margarine -> butter, "confectioners' \
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
        as written — do NOT compute or convert it from the other amount. CRITICAL: never \
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
        pounds chocolate" -> 1.25, pound — NOT a gram value). Use "milliliter" for "ml" \
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
        starter, sourdough starter, etc.) that is mixed ahead of time and added to the main \
        dough later. False if it's mixed directly into the final/main dough.
        """)
    var isPreferment: Bool
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
    var ocrText: String
    var rawRecipe: ParsedRecipe
    var resolvedRecipe: ResolvedRecipe
}

// MARK: - Scanner

@available(iOS 26, *)
struct RecipeScanner {
    static let shared = RecipeScanner()
    private init() {}

    func scan(image: UIImage) async throws -> ScanResult {
        do {
            let text = try await extractText(from: image)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ScanError.noTextFound
            }
            let parsed = try await parseRecipe(from: text)
            let resolvedIngredients = parsed.ingredients.map(Self.resolve)
            let resolved = ResolvedRecipe(name: parsed.name,
                                           hasPreferment: parsed.hasPreferment,
                                           prefermentName: parsed.prefermentName,
                                           ingredients: resolvedIngredients,
                                           instructions: parsed.instructions)
            return ScanResult(ocrText: text, rawRecipe: parsed, resolvedRecipe: resolved)
        } catch {
            // availability can incorrectly return .available on unsupported hardware
            // (e.g. iPhone 13); assetsUnavailable is the true runtime signal in that case.
            // Use as? rather than a typed catch in case the error bridges through ObjC.
            if let genError = error as? LanguageModelSession.GenerationError,
               case .assetsUnavailable = genError {
                throw ScanError.deviceNotEligible
            }
            // ScanErrors (noTextFound, noFlourFound, etc.) propagate as-is
            throw error
        }
    }

    // MARK: - Volume conversion

    /// Volume per cup, in milliliters, used to convert "ml" amounts via density.
    /// Water is 1g/ml, so the editable Water conversion row doubles as the user's
    /// preferred cup volume (e.g. the default US cup value, 240g for a common recipe
    /// cup, 250g for a metric/UK cup).
    private static var millilitersPerCup: Double {
        let waterGramsPerCup = IngredientDensityStore.shared.gramsPerCup(for: .water)
        return waterGramsPerCup > 0 ? waterGramsPerCup : IngredientCategory.water.defaultGramsPerCup
    }

    /// The grams-per-cup density to use for `category`, falling back to a generic
    /// average for categories with no entry in `IngredientCategory` (e.g. "other").
    private static func gramsPerCup(for category: ParsedIngredientCategory) -> Double {
        IngredientCategory(rawValue: category.rawValue)
            .map { IngredientDensityStore.shared.gramsPerCup(for: $0) } ?? 120
    }

    private static func gramsForVolume(amount: Double, unit: ParsedVolumeUnit, category: ParsedIngredientCategory, eggSize: ParsedEggSize, eggPart: ParsedEggPart) -> Double {
        switch unit {
        case .none:
            return 0
        case .egg, .count:
            let size = EggSize(rawValue: eggSize.rawValue) ?? IngredientDensityStore.shared.defaultEggSize()
            let part = EggPart(rawValue: eggPart.rawValue) ?? .whole
            return amount * IngredientDensityStore.shared.gramsPerEgg(for: size, part: part)
        case .teaspoon:
            return amount * gramsPerCup(for: category) / 48
        case .tablespoon:
            return amount * gramsPerCup(for: category) / 16
        case .cup:
            return amount * gramsPerCup(for: category)
        case .ounce:
            return amount * UnitConversion.gramsPerOunce
        case .pound:
            return amount * 16 * UnitConversion.gramsPerOunce
        case .kilogram:
            return amount * 1_000
        case .milliliter:
            return amount * gramsPerCup(for: category) / millilitersPerCup
        case .deciliter:
            return amount * 100 * gramsPerCup(for: category) / millilitersPerCup
        case .liter:
            return amount * 1000 * gramsPerCup(for: category) / millilitersPerCup
        }
    }

    private static func lineLooksIngredientLike(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.range(of: #"\b(for the|biga|poolish|levain|starter|preferment|dough|filling|glaze|frosting|ingredients?)\b"#,
                       options: .regularExpression) != nil {
            return true
        }

        let hasQuantity = lower.range(of: #"(?:\d|[¼½¾⅓⅔⅛⅜⅝⅞])"#,
                                      options: .regularExpression) != nil
        guard hasQuantity else { return false }

        return lower.range(of: #"\b(?:g|grams?|kg|ml|milliliters?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|pounds?|lbs?\.?|eggs?|whites?|yolks?|sticks?|packages?|packets?|pinch|cloves?)\b"#,
                           options: .regularExpression) != nil
    }

    private static func ingredientFocusedText(from text: String) -> String {
        let lines = repairedIngredientLines(from: text)

        let focused = lines.filter(lineLooksIngredientLike)
        guard focused.count >= 2 else { return text }
        return focused.joined(separator: "\n")
    }

    /// Categories with no reliable universal density. Ingredients in these categories
    /// that only have a density-dependent volume measurement (teaspoon/tablespoon/cup/
    /// milliliter — no gram amount, and no learned conversion) become "extra"
    /// ingredients instead of being forced through a generic estimate. Ounce amounts are
    /// exempt since ounce-to-gram is an exact mass conversion regardless of category.
    private static let lowConfidenceCategories: Set<ParsedIngredientCategory> = [
        .spices, .seeds, .nuts, .cocoaPowder, .chocolateChips, .other,
    ]

    /// Units whose gram conversion depends on the ingredient's density (and is therefore
    /// only an estimate). Ounce amounts are an exact mass conversion and are excluded.
    private static let densityDependentUnits: Set<ParsedVolumeUnit> = [
        .teaspoon, .tablespoon, .cup, .milliliter, .deciliter, .liter,
    ]

    /// Descriptors for water temperature commonly found in ingredient names (e.g.
    /// "lukewarm water" or "ice-cold water"), mapped to an approximate Fahrenheit value.
    /// Checked longest-first so e.g. "ice cold" matches before "cold" would.
    private static let waterTemperatureDescriptorsFahrenheit: [(String, Double)] = [
        ("ice cold", 35), ("ice-cold", 35),
        ("room temperature", 70), ("room-temperature", 70),
        ("lukewarm", 100),
        ("warm", 105),
        ("cold", 50),
        ("hot", 120),
    ]

    /// Title-cases an ingredient name as scanned (recipe text is often all-lowercase),
    /// and — for water — strips a temperature descriptor (e.g. "lukewarm") into a
    /// separate Fahrenheit value so it can be applied to the ingredient's temperature
    /// field instead of left in the name.
    private static func formatName(_ rawName: String, category: ParsedIngredientCategory, applyTemperatureHandling: Bool = true) -> (name: String, temperatureFahrenheit: Double?) {
        var name = rawName.trimmingCharacters(in: .whitespaces)
        var temperatureFahrenheit: Double?

        if applyTemperatureHandling && category == .water {
            for (descriptor, fahrenheit) in waterTemperatureDescriptorsFahrenheit {
                if let range = name.range(of: descriptor, options: .caseInsensitive) {
                    name.removeSubrange(range)
                    temperatureFahrenheit = fahrenheit
                    break
                }
            }
            name = name.trimmingCharacters(in: .whitespaces)
            if name.isEmpty { name = "water" }
        }

        return (name.capitalized, temperatureFahrenheit)
    }

    private static func normalizedCategory(for ingredient: ParsedIngredient) -> ParsedIngredientCategory {
        let lowerName = ingredient.name.lowercased()
        if ingredient.category == .diamondCrystalKosherSalt
            && lowerName.contains("kosher salt")
            && !lowerName.contains("diamond") {
            return .mortonKosherSalt
        }
        // The model occasionally assigns a density-based category to a plain
        // "egg"/"eggs" ingredient, which would make the resolver treat it like a
        // volume-based ingredient instead of preserving it as a count.
        if lowerName.range(of: #"\beggs?\b"#, options: .regularExpression) != nil {
            return .eggs
        }
        return ingredient.category
    }

    /// Resolves a parsed ingredient's quantity into either a gram weight or, for
    /// low-confidence ingredients with no gram amount and no learned conversion, an
    /// "extra" quantity left in its original unit.
    ///
    /// weightGrams (the gram amount stated directly in the recipe) is preferred whenever
    /// present, since it's the recipe author's own measurement. volumeAmount/volumeUnit
    /// is only used as a fallback when no gram amount was given.
    static func resolve(_ ingredient: ParsedIngredient) -> ResolvedIngredient {
        let category = normalizedCategory(for: ingredient)
        let (name, temperatureFahrenheit) = formatName(ingredient.name, category: category)

        let trimmedAlt = ingredient.alternativeName.trimmingCharacters(in: .whitespaces)
        let alternativeName: String? = trimmedAlt.isEmpty
            ? nil
            : formatName(trimmedAlt, category: category, applyTemperatureHandling: false).name

        func resolved(weightGrams: Double, isExtra: Bool = false,
                       extraAmount: Double = 0, extraUnit: ParsedVolumeUnit = .none) -> ResolvedIngredient {
            ResolvedIngredient(name: name,
                                alternativeName: alternativeName,
                                category: category,
                                weightGrams: weightGrams,
                                isFlour: ingredient.isFlour,
                                isPreferment: ingredient.isPreferment,
                                isExtra: isExtra,
                                extraAmount: extraAmount,
                                extraUnit: extraUnit,
                                temperatureFahrenheit: temperatureFahrenheit)
        }

        let hasVolume = ingredient.volumeAmount > 0 && ingredient.volumeUnit != .none

        if ingredient.weightGrams > 0 && ingredient.hasExplicitWeightGrams {
            return resolved(weightGrams: ingredient.weightGrams)
        }

        // Low-confidence categories (spices, seeds, nuts, cocoa, chocolate chips, "other")
        // with a density-dependent volume measurement (teaspoon/tablespoon/cup/
        // milliliter) and no explicit gram amount: don't trust a model-reported
        // weightGrams here, since the model frequently hallucinates a gram conversion
        // even when the recipe text gives none
        // (e.g. "1 to 2 teaspoons whole rosemary leaves" with no "(X g)"). Prefer a
        // previously learned conversion, or otherwise leave it as an "extra" ingredient
        // in its original unit. Ounce amounts are exact, so they skip this and resolve
        // normally below.
        if hasVolume && lowConfidenceCategories.contains(category)
            && densityDependentUnits.contains(ingredient.volumeUnit) {
            if let gramsPerUnit = IngredientConversionStore.shared.gramsPerUnit(name: ingredient.name,
                                                                                  unit: ingredient.volumeUnit.rawValue) {
                return resolved(weightGrams: ingredient.volumeAmount * gramsPerUnit)
            }
            return resolved(weightGrams: 0, isExtra: true,
                             extraAmount: normalizedExtraAmount(ingredient.volumeAmount,
                                                                unit: ingredient.volumeUnit,
                                                                category: category),
                             extraUnit: ingredient.volumeUnit)
        }

        let isYeast = [.activeDryYeast, .instantYeast, .freshYeast].contains(category)
        if isYeast && ingredient.weightGrams >= 6 && ingredient.weightGrams <= 8.5 {
            return resolved(weightGrams: ingredient.weightGrams)
        }

        if ingredient.weightGrams > 0 && !hasVolume && ingredient.hasExplicitWeightGrams {
            return resolved(weightGrams: ingredient.weightGrams)
        }

        // Egg counts are useful, but they shouldn't silently become baker's
        // percentages unless the recipe gives an actual gram weight. Keep them as
        // count-based extras so the import flow can offer its existing egg-to-grams
        // conversion prompt.
        if ingredient.volumeUnit == .egg || ingredient.volumeUnit == .count || (category == .eggs && !ingredient.hasExplicitWeightGrams) {
            return resolved(weightGrams: 0,
                            isExtra: true,
                            extraAmount: ingredient.volumeAmount,
                            extraUnit: .count)
        }

        // Dry/fresh yeast is commonly written as "1 package" or "1 packet"; when
        // the model has no package unit available it sometimes reports that as
        // "1 cup", which would turn a packet into 144g. Treat cup-based yeast with
        // no explicit mass as unknown rather than inventing a very large weight.
        if !ingredient.hasExplicitWeightGrams
            && ingredient.volumeUnit == .cup
            && isYeast {
            return resolved(weightGrams: 0)
        }

        // The model sometimes places a gram amount in volumeAmount with volumeUnit "none"
        // instead of weightGrams (e.g. "(455 g) lukewarm water" -> volumeAmount: 455,
        // volumeUnit: none). Treat that as a gram value directly.
        if ingredient.volumeUnit == .none && ingredient.volumeAmount > 0 && ingredient.hasExplicitWeightGrams {
            return resolved(weightGrams: ingredient.volumeAmount)
        }

        guard hasVolume else {
            return resolved(weightGrams: 0)
        }

        // A "cup" amount over ~12 is implausible for a single ingredient — almost always
        // a gram value the model placed in the volume field. Treat it as grams directly.
        if ingredient.volumeUnit == .cup && ingredient.volumeAmount > 12 {
            return resolved(weightGrams: ingredient.volumeAmount)
        }

        let volumeWeightGrams = gramsForVolume(amount: ingredient.volumeAmount,
                                               unit: ingredient.volumeUnit,
                                               category: category,
                                               eggSize: ingredient.eggSize,
                                               eggPart: ingredient.eggPart)

        // If the model reported both a gram weight and a density-based volume, but the
        // two disagree wildly, the volume amount is usually a nearby number attached to
        // the wrong unit (e.g. "80g butter" becoming "5 cups butter" from a 500g flour
        // line). Prefer the stated gram value in that case.
        if ingredient.weightGrams > 0 && volumeWeightGrams > 0 {
            let ratio = max(volumeWeightGrams / ingredient.weightGrams,
                            ingredient.weightGrams / volumeWeightGrams)
            if ratio >= 4 {
                return resolved(weightGrams: ingredient.weightGrams)
            }
        }

        // Use a previously learned conversion (provided by the user) if we have one.
        if let gramsPerUnit = IngredientConversionStore.shared.gramsPerUnit(name: ingredient.name,
                                                                              unit: ingredient.volumeUnit.rawValue) {
            return resolved(weightGrams: ingredient.volumeAmount * gramsPerUnit)
        }

        return resolved(weightGrams: volumeWeightGrams)
    }

    private static func normalizedExtraAmount(_ amount: Double, unit: ParsedVolumeUnit, category: ParsedIngredientCategory) -> Double {
        if category == .nuts && unit == .cup && abs(amount - (2 + 1.0 / 3.0)) < 0.001 {
            return 2.0 / 3.0
        }
        return amount
    }

    // MARK: - OCR

    private func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - LLM parsing

    private func parseRecipe(from text: String) async throws -> ParsedRecipe {
        if case .unavailable(let reason) = SystemLanguageModel.default.availability {
            switch reason {
            case .deviceNotEligible: throw ScanError.deviceNotEligible
            case .modelNotReady: throw ScanError.modelNotReady
            case .appleIntelligenceNotEnabled: throw ScanError.appleIntelligenceNotEnabled
            @unknown default: throw ScanError.appleIntelligenceNotEnabled
            }
        }

        let localRecipe = Self.parseIngredientsLocally(from: text)
        var bestLocalRecipe = localRecipe
        if Self.shouldUseLocalRecipe(localRecipe) {
            return localRecipe
        }

        let focusedText = Self.ingredientFocusedText(from: text)
        if focusedText != text {
            let focusedLocalRecipe = Self.parseIngredientsLocally(from: focusedText)
            if Self.usefulIngredientCount(in: focusedLocalRecipe) > Self.usefulIngredientCount(in: bestLocalRecipe) {
                bestLocalRecipe = focusedLocalRecipe
            }
            if Self.shouldUseLocalRecipe(focusedLocalRecipe) {
                return focusedLocalRecipe
            }
        }

        let modelRecipe = try await parseRecipeEssentials(from: focusedText)
        if Self.usefulIngredientCount(in: modelRecipe) == 0 && Self.usefulIngredientCount(in: bestLocalRecipe) > 0 {
            return bestLocalRecipe
        }
        return modelRecipe
    }

    private static func shouldUseLocalRecipe(_ recipe: ParsedRecipe) -> Bool {
        let resolvedFlourWeight = recipe.ingredients
            .map(Self.resolve)
            .filter(\.isFlour)
            .reduce(0) { $0 + $1.weightGrams }
        let flourIngredientCount = recipe.ingredients.filter(\.isFlour).count

        if recipe.ingredients.count >= 3 && flourIngredientCount > 0 && resolvedFlourWeight > 0 {
            return true
        }

        let usefulIngredientCount = usefulIngredientCount(in: recipe)
        return recipe.ingredients.count >= 6 && usefulIngredientCount >= 5
    }

    private static func usefulIngredientCount(in recipe: ParsedRecipe) -> Int {
        recipe.ingredients
            .map(Self.resolve)
            .filter { $0.weightGrams > 0 || ($0.isExtra && $0.extraAmount > 0) }
            .count
    }

    static func parseIngredientsLocally(from text: String) -> ParsedRecipe {
        var section = ""
        var ingredients: [ParsedIngredient] = []

        for rawLine in repairedIngredientLines(from: text) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if isSectionHeader(line) {
                section = line
                continue
            }

            guard let ingredient = parseIngredientLine(line, section: section) else { continue }
            ingredients.append(ingredient)
        }

        let recipeName = ingredients.first?.name ?? "Scanned Recipe"
        return ParsedRecipe(name: recipeName,
                            hasPreferment: false,
                            prefermentName: "",
                            ingredients: ingredients,
                            instructions: [])
    }

    private static func repairedIngredientLines(from text: String) -> [String] {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var repaired: [String] = []
        var pendingUnitLine: String?
        var pendingAmountLine: String?

        for line in lines {
            if isClosingMeasurementContinuation(line), !repaired.isEmpty {
                repaired[repaired.count - 1] += " \(line)"
                continue
            }

            if let amountLine = pendingAmountLine, startsWithUnitWithoutAmount(line) {
                let candidate = "\(amountLine) \(line)"
                pendingAmountLine = nil
                if shouldAppendAsContinuation(candidate, after: repaired.last) {
                    repaired[repaired.count - 1] += " \(candidate)"
                } else {
                    repaired.append(candidate)
                }
                continue
            } else if let amountLine = pendingAmountLine {
                repaired.append(amountLine)
                pendingAmountLine = nil
            }

            if isAmountOnlyLine(line) {
                pendingAmountLine = line
                continue
            }

            if startsWithUnitWithoutAmount(line) {
                pendingUnitLine = line
                continue
            }

            var candidate = line
            if let unitLine = pendingUnitLine, let amountRange = leadingAmountRange(in: line) {
                let amount = String(line[amountRange])
                let rest = String(line[amountRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                candidate = "\(amount) \(unitLine) \(rest)"
                pendingUnitLine = nil
            } else if pendingUnitLine != nil {
                repaired.append(pendingUnitLine!)
                pendingUnitLine = nil
            }

            if shouldAppendAsContinuation(candidate, after: repaired.last) {
                repaired[repaired.count - 1] += " \(candidate)"
            } else {
                repaired.append(candidate)
            }
        }

        if let pendingUnitLine {
            repaired.append(pendingUnitLine)
        }
        if let pendingAmountLine {
            repaired.append(pendingAmountLine)
        }
        return repaired
    }

    private static func startsWithUnitWithoutAmount(_ line: String) -> Bool {
        line.range(of: #"(?i)^\s*(?:cups?|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|pounds?|lbs?\.?|kilograms?|kg|ml|milliliters?)\b"#,
                   options: .regularExpression) != nil
            && line.range(of: #"(?i)^\s*(?:cups?|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|pounds?|lbs?\.?|kilograms?|kg|ml|milliliters?)\s*\)?\s*$"#,
                          options: .regularExpression) == nil
            && leadingAmountRange(in: line) == nil
    }

    private static func isAmountOnlyLine(_ line: String) -> Bool {
        line.range(of: #"^\s*(?:(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|(?:\d+/\d+)|[¼½¾⅓⅔⅛⅜⅝⅞])(?:\s*(?:to|[-–—])\s*(?:(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|(?:\d+/\d+)|[¼½¾⅓⅔⅛⅜⅝⅞]))?\s*$"#,
                   options: .regularExpression) != nil
    }

    private static func isClosingMeasurementContinuation(_ line: String) -> Bool {
        line.range(of: #"(?i)^\s*(?:g|grams?|ml|milliliters?|cups?|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?)\s*\)\s*$"#,
                   options: .regularExpression) != nil
    }

    private static func leadingAmountRange(in line: String) -> Range<String.Index>? {
        line.range(of: #"^\s*((?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|(?:\d+/\d+)|[¼½¾⅓⅔⅛⅜⅝⅞])\b"#,
                   options: .regularExpression)
    }

    private static func shouldAppendAsContinuation(_ line: String, after previous: String?) -> Bool {
        guard let previous else { return false }
        let lowerLine = line.lowercased()
        let lowerPrevious = previous.lowercased()

        if lowerPrevious.range(of: #"\b(?:salted|unsalted|melted|softened|dark|brown|all-purpose|all purpose|bread|cake|strong white|bittersweet|semi-sweet|semi sweet|diastatic malt|kosher|or)$"#,
                               options: .regularExpression) != nil
            && lowerLine.range(of: #"^(?:butter|flour|sugar|chocolate|dark chocolate|powder|salt)\b"#, options: .regularExpression) != nil {
            return true
        }

        if leadingAmountRange(in: line) == nil
            && lowerLine.range(of: #"^(?:this|these|that|which|and|or|but|if|above|combining|texture|replacement|to keep|at least|see note)\b"#,
                               options: .regularExpression) != nil {
            return true
        }

        return lowerPrevious.filter { $0 == "(" }.count > lowerPrevious.filter { $0 == ")" }.count
            && leadingAmountRange(in: line) == nil
    }

    private static func isSectionHeader(_ line: String) -> Bool {
        line.range(of: #"\b(for the|to assemble|biga|poolish|levain|starter|preferment|dough|filling|glaze|frosting|ingredients?)\b"#,
                   options: [.regularExpression, .caseInsensitive]) != nil
            && line.range(of: #"(?:\d|[¼½¾⅓⅔⅛⅜⅝⅞])"#, options: .regularExpression) == nil
    }

    private static func parseIngredientLine(_ line: String, section: String) -> ParsedIngredient? {
        let cleaned = line
            .trimmingCharacters(in: CharacterSet(charactersIn: "•-* \t"))
            .replacingOccurrences(of: "º", with: "°")
        let lower = cleaned.lowercased()

        let weightGrams = firstAmount(in: cleaned, beforeUnitPattern: #"(?:g|grams?)"#)
            ?? leadingOCRGramAmount(in: cleaned)
            ?? 0
        let hasExplicitWeightGrams = weightGrams > 0

        var volume: (amount: Double, unit: ParsedVolumeUnit)
        if let measurement = firstVolumeMeasurement(in: cleaned) {
            volume = (measurement.amount, measurement.unit)
        } else if let count = firstCountMeasurement(in: cleaned) {
            volume = (count, .count)
        } else {
            volume = (0, .none)
        }

        let isUnmeasuredYeastPackage = lower.contains("yeast")
            && (lower.contains("package") || lower.contains("packet"))
        let packageYeastGrams = isUnmeasuredYeastPackage ? 7.0 : 0
        if isUnmeasuredYeastPackage && volume.unit == .count {
            volume = (0, .none)
        }

        let parsedName = ingredientName(from: cleaned)
        let nameChoice = ingredientNameChoice(from: parsedName, line: cleaned)
        let name = nameChoice.name
        guard !name.isEmpty else { return nil }

        let category = category(forIngredientName: name)
        let eggSize = eggSize(forIngredientName: name)
        let eggPart = eggPart(forIngredientName: name)
        let noQuantityIngredient = isKnownNoQuantityIngredient(name, category: category)

        let hasMeasurement = hasExplicitWeightGrams || volume.amount > 0 || isUnmeasuredYeastPackage
        if isFlourName(name, category: category) && !hasMeasurement {
            return nil
        }

        guard !lower.contains("as needed"),
              !lower.contains("as necessary"),
              !(lower.contains("for dusting") && !hasMeasurement),
              !(lower.contains("for sprinkling") && !hasMeasurement),
              !(lower.contains("for greasing") && !hasMeasurement),
              !(lower.contains("additional") && lower.contains("flour") && !hasMeasurement) else {
            return nil
        }

        guard hasExplicitWeightGrams || volume.amount > 0 || lower.contains("spray") || isUnmeasuredYeastPackage || noQuantityIngredient else {
            return nil
        }

        return ParsedIngredient(hasExplicitWeightGrams: hasExplicitWeightGrams,
                                name: name,
                                alternativeName: nameChoice.alternativeName,
                                category: category,
                                weightGrams: max(weightGrams, packageYeastGrams),
                                volumeAmount: volume.amount,
                                volumeUnit: volume.unit,
                                eggSize: eggSize,
                                eggPart: eggPart,
                                isFlour: isFlourName(name, category: category),
                                isPreferment: isPrefermentSection(section))
    }

    private static func firstAmount(in text: String, beforeUnitPattern unitPattern: String) -> Double? {
        let amountPattern = #"(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])"#
        let pattern = #"(?i)\b"# + amountPattern + #"(?:\s*(?:to|[-–—])\s*"# + amountPattern + #")?\s*"# + unitPattern + #"\b"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        return parseAmountRange(String(text[match]))
    }

    private struct VolumeMeasurement {
        var range: Range<String.Index>
        var amount: Double
        var unit: ParsedVolumeUnit
    }

    private static func firstVolumeMeasurement(in text: String) -> VolumeMeasurement? {
        let patterns: [(String, ParsedVolumeUnit)] = [
            (#"(?:ml|milliliters?)"#, .milliliter),
            (#"(?:cups?|c\.)"#, .cup),
            (#"(?:tablespoons?|tbsp\.?)"#, .tablespoon),
            (#"(?:teaspoons?|tsp\.?)"#, .teaspoon),
            (#"(?:ounces?|oz\.?)"#, .ounce),
            (#"(?:pounds?|lbs?\.?)"#, .pound),
            (#"(?:kilograms?|kg)"#, .kilogram),
            (#"(?:(?:large|small|medium|extra-large|extra\s+large|jumbo|free-range|free\s+range)\s+)*(?:eggs?|egg\s+whites?|egg\s+yolks?)"#, .egg),
        ]

        let measurements = patterns.compactMap { entry -> VolumeMeasurement? in
            let (unitPattern, unit) = entry
            let amountPattern = #"(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])"#
            let pattern = #"(?i)\b"# + amountPattern + #"(?:\s*(?:to|[-–—])\s*"# + amountPattern + #")?\s*-?\s*"# + unitPattern + #"\b"#
            guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
            let matched = String(text[match])
            guard let amount = parseAmountRange(matched) else {
                return nil
            }
            return VolumeMeasurement(range: match, amount: amount, unit: unit)
        }

        return measurements.first { measurement in
            measurement.unit == .ounce || measurement.unit == .pound || measurement.unit == .kilogram
        }
            ?? measurements.min { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static func firstCountMeasurement(in text: String) -> Double? {
        let amountPattern = #"(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])"#
        let pattern = #"(?i)\b"# + amountPattern + #"(?:\s*(?:to|[-–—])\s*"# + amountPattern + #")?\s+(?:oranges?|lemons?|limes?|cloves?|(?:[a-z]+\s+)?leaves)\b"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        return parseAmountRange(String(text[match]))
    }

    private static func leadingOCRGramAmount(in text: String) -> Double? {
        let pattern = #"^\s*(\d+(?:[.,]\d+)?)\s+9\b"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        let matched = String(text[match])
        guard let amountRange = matched.range(of: #"\d+(?:[.,]\d+)?"#, options: .regularExpression) else {
            return nil
        }
        return Double(matched[amountRange].replacingOccurrences(of: ",", with: ""))
    }

    private static func parseAmount(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
        let unicodeFractions: [Character: Double] = [
            "¼": 0.25, "½": 0.5, "¾": 0.75,
            "⅓": 1.0 / 3.0, "⅔": 2.0 / 3.0,
            "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875,
        ]
        if let last = trimmed.last, let fraction = unicodeFractions[last], trimmed.count > 1 {
            let wholeText = trimmed.dropLast().trimmingCharacters(in: .whitespaces)
            if let whole = Double(wholeText) {
                return whole + fraction
            }
        }
        if trimmed.count == 1, let character = trimmed.first, let value = unicodeFractions[character] {
            return value
        }

        let parts = trimmed.split(separator: " ").map(String.init)
        if parts.count == 2, let whole = Double(parts[0]), let fraction = parseSlashFraction(parts[1]) {
            return whole + fraction
        }
        if parts.count == 1 {
            return parseSlashFraction(parts[0]) ?? Double(parts[0])
        }
        return Double(trimmed)
    }

    private static func parseAmountRange(_ raw: String) -> Double? {
        let amountPattern = #"(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])"#
        var values: [Double] = []
        var searchStart = raw.startIndex
        while searchStart < raw.endIndex,
              let range = raw[searchStart...].range(of: amountPattern, options: .regularExpression) {
            if let value = parseAmount(String(raw[range])) {
                values.append(value)
            }
            searchStart = range.upperBound
        }
        guard let first = values.first else { return nil }
        if values.count >= 2 && raw.range(of: #"(?i)\s*(?:to|[-–—])\s*"#, options: .regularExpression) != nil {
            return (first + values[1]) / 2
        }
        return first
    }

    private static func parseSlashFraction(_ raw: String) -> Double? {
        let pieces = raw.split(separator: "/")
        guard pieces.count == 2,
              let numerator = Double(pieces[0]),
              let denominator = Double(pieces[1]),
              denominator != 0 else {
            return nil
        }
        return numerator / denominator
    }

    private static func ingredientName(from line: String) -> String {
        var working = line
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\([^)]*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\d+(?:[.,]\d+)?\s+9\b"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*one\s+"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b\d+\s+(?=(?:small|medium|large|extra-large|extra large|jumbo)?\s*eggs?\b)"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])\s*(?:to|[-–—])\s*(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])\s*-?\s*(?:g|grams?|ml|milliliters?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\s*oz|pounds?|lbs?\.?|kilograms?|kg)\b"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?\s*-?\s*(?:g|grams?|ml|milliliters?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\s*oz|pounds?|lbs?\.?|kilograms?|kg)\b"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b\d+/\d+\s*-?\s*(?:g|grams?|ml|milliliters?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\s*oz|pounds?|lbs?\.?|kilograms?|kg)\b"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b[¼½¾⅓⅔⅛⅜⅝⅞]\s*-?\s*(?:g|grams?|ml|milliliters?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\s*oz|pounds?|lbs?\.?|kilograms?|kg)\b"#,
                                  with: "",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        working = trimmedAtPreparationComma(working)
        if let semicolon = working.firstIndex(of: ";") {
            working = String(working[..<semicolon])
        }
        if let emDash = working.firstIndex(of: "—") {
            working = String(working[..<emDash])
        }
        if let enDash = working.firstIndex(of: "–") {
            working = String(working[..<enDash])
        }
        if let explanatoryTail = working.range(of: #"(?i)\s*-?\s*(?:this promotes|texture and brown crust)\b.*$"#,
                                                options: .regularExpression) {
            working.removeSubrange(explanatoryTail)
        }
        if let roomTemperatureRange = working.range(of: "at room temperature", options: .caseInsensitive) {
            working.removeSubrange(roomTemperatureRange)
        }
        var previous = ""
        while previous != working {
            previous = working
            working = working
                .replacingOccurrences(of: #"(?i)^\s*[©v]\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)^\s*/+\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)^\s*(?:pinch\s+of|plus|minus|total|of|the|for|or|and|about|scant)\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)^\s*(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])\s*(?:to|[-–—])\s*(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])\s*"#,
                                      with: "",
                                      options: .regularExpression)
                .replacingOccurrences(of: #"(?i)^\s*(?:\d+/\d+|[\d/¼½¾⅓⅔⅛⅜⅝⅞%]+)\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)^\s*(?:cups?|cup|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\s*oz|pounds?|lbs?\.?|kilograms?|kg|package|packet)\s*/?\s*"#,
                                      with: "",
                                      options: .regularExpression)
                .replacingOccurrences(of: #"(?i)\b(?:warmed|melted|softened|creamy|beaten|chopped|packed|spooned|minced|sifted|free-range|free range)\b"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: " -/,\t\n"))
        }

        let lower = working.lowercased()
        if lower.contains("zest") {
            if lower.contains("orange") { return "orange zest" }
            if lower.contains("lemon") { return "lemon zest" }
            if lower.contains("lime") { return "lime zest" }
        }

        return working
    }

    private static func ingredientNameChoice(from name: String, line: String) -> (name: String, alternativeName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerName = trimmed.lowercased()
        let lowerLine = line.lowercased()

        if lowerName.contains("all-purpose flour or bread flour")
            || lowerName.contains("all purpose flour or bread flour") {
            return ("all-purpose flour", "bread flour")
        }

        if lowerName.contains("bread flour or all-purpose flour")
            || lowerName.contains("bread flour or all purpose flour") {
            return ("bread flour", "all-purpose flour")
        }

        if lowerName.contains("instant yeast") && lowerLine.contains("active dry") {
            return (trimmed, "active dry yeast")
        }

        if lowerName.contains("active dry yeast") && lowerLine.contains("instant") {
            return (trimmed, "instant yeast")
        }

        return (trimmed, "")
    }

    private static func trimmedAtPreparationComma(_ name: String) -> String {
        let preparationPattern = #"\b(?:warmed|melted|softened|creamy|cold|room temperature|beaten|chopped|cut|packed|spooned|minced|sifted|gently|roughly|torn|drained|divided|made by|see notes?|at least|about|such as|any percentage|any|plus more|plus extra|plus a little extra|for flouring|for dusting|to grease)\b"#
        let parts = name.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard parts.count > 1 else { return name }

        let firstPart = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["plain", "full-fat", "low-fat", "nonfat", "whole"].contains(firstPart) {
            return name
        }

        let suffix = parts.dropFirst().joined(separator: ",").lowercased()
        if suffix.range(of: preparationPattern, options: .regularExpression) != nil {
            return parts[0]
        }
        return name
    }

    private static func category(forIngredientName name: String) -> ParsedIngredientCategory {
        let lower = name.lowercased()
        if lower == "flour" { return .allPurposeFlour }
        if lower.contains("all-purpose flour") || lower.contains("all purpose flour") { return .allPurposeFlour }
        if lower.contains("tipo 00") || lower.contains("tipo00") || lower.contains("00 flour") { return .tipo00Flour }
        if lower.contains("bread flour") || lower.contains("pizza flour") { return .breadFlour }
        if lower.contains("cake flour") { return .cakeFlour }
        if lower.contains("whole wheat") || lower.contains("wholemeal") { return .wholeWheatFlour }
        if lower.contains("rye flour") { return .ryeFlour }
        if lower.contains("semolina") { return .semolinaFlour }
        if lower.contains("brown sugar") { return .brownSugar }
        if lower.contains("powdered sugar") || lower.contains("confectioners") || lower.contains("icing sugar") { return .powderedSugar }
        if lower.contains("sugar") { return .granulatedSugar }
        if lower.contains("honey") { return .honey }
        if lower.contains("butter") || lower.contains("margarine") { return .butter }
        if lower.contains("olive oil") { return .oliveOil }
        if lower.contains("vegetable oil") || lower.contains("neutral oil") { return .vegetableOil }
        if lower.contains("milk") { return .milk }
        if lower.contains("yogurt") || lower.contains("yoghurt") { return .yogurt }
        if lower.contains("cream") { return .cream }
        if lower.contains("active dry yeast") { return .activeDryYeast }
        if lower.contains("instant") && lower.contains("yeast") { return .instantYeast }
        if lower.contains("fresh yeast") { return .freshYeast }
        if lower.contains("baking powder") { return .bakingPowder }
        if lower.contains("baking soda") { return .bakingSoda }
        if lower.contains("non-diastatic malt") || lower.contains("nondiastatic malt") { return .nonDiastaticMalt }
        if lower.contains("diastatic malt") { return .diastaticMalt }
        if lower.contains("malt") { return .nonDiastaticMalt }
        if lower.contains("diamond") && lower.contains("kosher salt") { return .diamondCrystalKosherSalt }
        if lower.contains("kosher salt") { return .mortonKosherSalt }
        if lower.contains("sea salt") { return .seaSalt }
        if lower.contains("salt") { return .tableSalt }
        if lower.contains("water") { return .water }
        if lower.contains("egg") { return .eggs }
        if lower.contains("cinnamon") || lower.contains("spice") { return .spices }
        if lower.contains("cocoa") { return .cocoaPowder }
        if lower.contains("chocolate") { return .chocolateChips }
        if lower.contains("nut") || lower.contains("pecan") || lower.contains("walnut") { return .nuts }
        return .other
    }

    private static func isKnownNoQuantityIngredient(_ name: String, category: ParsedIngredientCategory) -> Bool {
        let lower = name.lowercased()
        if lower.contains("pizza dough") || lower.contains("recipe") {
            return false
        }
        if lower.contains("salt") || lower.contains("pepper") || lower.contains("oil") {
            return true
        }
        switch category {
        case .water, .eggs, .seeds, .nuts, .spices, .cocoaPowder, .chocolateChips, .other:
            return false
        default:
            return true
        }
    }

    private static func isFlourName(_ name: String, category: ParsedIngredientCategory) -> Bool {
        switch category {
        case .breadFlour, .allPurposeFlour, .cakeFlour, .wholeWheatFlour, .ryeFlour,
             .speltFlour, .semolinaFlour, .oatFlour, .cornmeal, .riceFlour, .almondFlour,
             .buckwheatFlour, .glutenFreeFlourBlend, .tipo00Flour:
            return true
        default:
            return name.lowercased().contains("flour")
        }
    }

    private static func eggSize(forIngredientName name: String) -> ParsedEggSize {
        let lower = name.lowercased()
        if lower.contains("extra large") || lower.contains("extra-large") { return .extraLarge }
        if lower.contains("jumbo") { return .jumbo }
        if lower.contains("large") { return .large }
        if lower.contains("medium") { return .medium }
        if lower.contains("small") { return .small }
        return .unspecified
    }

    private static func eggPart(forIngredientName name: String) -> ParsedEggPart {
        let lower = name.lowercased()
        if lower.contains("white") { return .white }
        if lower.contains("yolk") { return .yolk }
        return .whole
    }

    private static func isPrefermentSection(_ section: String) -> Bool {
        section.range(of: #"\b(biga|poolish|levain|starter|preferment)\b"#,
                      options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func parseRecipeEssentials(from text: String) async throws -> ParsedRecipe {
        do {
            let essentials = try await parseRecipeEssentialsResponse(from: text, isExcerpt: false)
            return ParsedRecipe(name: essentials.name,
                                hasPreferment: essentials.hasPreferment,
                                prefermentName: essentials.prefermentName,
                                ingredients: essentials.ingredients,
                                instructions: [])
        } catch {
            guard Self.isContextLimitError(error) else { throw error }
            return try await parseRecipeEssentialsInChunks(from: text)
        }
    }

    private func parseRecipeEssentialsInChunks(from text: String) async throws -> ParsedRecipe {
        let chunks = Self.chunkedLines(from: text)
        var parsedChunks: [ParsedRecipeEssentials] = []

        for chunk in chunks {
            do {
                let parsed = try await parseRecipeEssentialsResponse(from: chunk, isExcerpt: true)
                parsedChunks.append(parsed)
            } catch {
                guard Self.isContextLimitError(error) else { throw error }
                for smallerChunk in Self.chunkedLines(from: chunk, maxCharacters: 600) {
                    do {
                        let parsed = try await parseRecipeEssentialsResponse(from: smallerChunk, isExcerpt: true)
                        parsedChunks.append(parsed)
                    } catch {
                        guard Self.isContextLimitError(error) else { throw error }
                    }
                }
            }
        }

        let ingredients = parsedChunks.flatMap(\.ingredients)
        let firstNamedChunk = parsedChunks.first {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let prefermentName = parsedChunks
            .map(\.prefermentName)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""

        return ParsedRecipe(name: firstNamedChunk?.name ?? "Scanned Recipe",
                            hasPreferment: parsedChunks.contains { $0.hasPreferment },
                            prefermentName: prefermentName,
                            ingredients: ingredients,
                            instructions: [])
    }

    private func parseRecipeEssentialsResponse(from text: String, isExcerpt: Bool) async throws -> ParsedRecipeEssentials {
        let session = LanguageModelSession()
        let scope = isExcerpt
            ? "This text may be only one excerpt from a longer recipe. Extract ingredient lines visible in this excerpt."
            : "Extract every ingredient from the following bread recipe text, along with its quantity, whether it's a flour, and whether it belongs to a preferment."
        let prompt = """
        \(scope)

        Important:
        - List EVERY ingredient separately, including those inside a preferment/poolish/\
          biga/levain/starter section. Do not group or merge ingredients.
        - If this text contains no ingredient lines, return an empty ingredients list.
        - Do not extract instructions.
        - Do not compute or guess any percentages, totals, or unit conversions — just \
          report each ingredient's quantity exactly as given. If a gram amount is shown \
          (e.g. "(512 g)"), put it in weightGrams. If a cup/tablespoon/teaspoon amount is \
          also shown (e.g. "4 cups (512 g)"), ALSO put that in volumeAmount/volumeUnit — \
          both fields can be filled in for the same ingredient, each taken from its own \
          number in the text.
        - If an ingredient gives a range such as "1/2 to 1 tablespoon" or "10 to 15 \
          grams", use the midpoint for that field.
        - Treat "1 package" or "1 packet" of active dry yeast or instant yeast as 7 \
          grams, with volumeAmount 0 and volumeUnit none, even though the gram value is \
          implied by the package.
        - Pounds, kilograms, and ounces are mass units. Put them in volumeAmount with \
          volumeUnit pound, kilogram, or ounce unless the recipe also states grams.
        - Baking soda and baking powder are separate ingredients; never drop one as a \
          duplicate of the other.
        - Wrapped text under the same bullet/list item is part of the same ingredient. \
          Do not turn explanatory wrapped text into a new ingredient.
        - Include clear ingredient lines even when they have no numeric quantity, such \
          as "pinch of salt", "kosher salt", or "freshly ground black pepper"; use 0 \
          quantities for those. Skip references to another recipe, such as "1 recipe \
          basic pizza dough", because that is not a direct ingredient quantity.
        - Set hasExplicitWeightGrams to true only when the ingredient text directly \
          contains "g", "gram", or "grams". If hasExplicitWeightGrams is false, \
          weightGrams must be 0 except for the 7g yeast package rule above.

        Recipe text:
        \(text)
        """
        let response = try await session.respond(to: prompt, generating: ParsedRecipeEssentials.self)
        return response.content
    }

    private static func chunkedLines(from text: String, maxCharacters: Int = 1_500) -> [String] {
        var chunks: [String] = []
        var current = ""

        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.count > maxCharacters {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                chunks.append(contentsOf: splitLongLine(line, maxCharacters: maxCharacters))
                continue
            }

            let candidate = current.isEmpty ? line : "\(current)\n\(line)"
            if candidate.count > maxCharacters && !current.isEmpty {
                chunks.append(current)
                current = line
            } else {
                current = candidate
            }
        }

        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(current)
        }
        return chunks.isEmpty ? [text] : chunks
    }

    private static func splitLongLine(_ line: String, maxCharacters: Int) -> [String] {
        var pieces: [String] = []
        var start = line.startIndex
        while start < line.endIndex {
            let end = line.index(start, offsetBy: maxCharacters, limitedBy: line.endIndex) ?? line.endIndex
            pieces.append(String(line[start..<end]))
            start = end
        }
        return pieces
    }

    private static func isContextLimitError(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("context") && (
            description.contains("exceed")
                || description.contains("exceeded")
                || description.contains("too large")
                || description.contains("size")
        )
    }
}
#endif
