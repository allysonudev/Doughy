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
    /// Recipe name.
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
enum ParsedVolumeUnit: String, Sendable {
    case none
    case teaspoon
    case tablespoon
    case cup
    case ounce
    case milliliter
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

    // Sweeteners
    case granulatedSugar
    case brownSugar
    case powderedSugar
    case honey
    case mapleSyrup
    case molasses

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

    // Salt
    case tableSalt
    case kosherSalt
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
    /// Ingredient name, without quantity, exactly as written in the recipe \
    /// (e.g. "Wholemeal flour", not "4 cups (512 g) bread flour").
    var name: String
    @Guide(description: """
        The closest matching category for this ingredient from the fixed list, based on \
        its name and likely density. Map common synonyms and variants to their closest \
        category rather than falling back to "other", e.g.: "Wholemeal flour" -> \
        wholeWheatFlour, "Diamond Crystal kosher salt" -> kosherSalt, "EVOO" -> oliveOil, \
        "00 flour" or "pizza flour" -> breadFlour, margarine -> butter, "confectioners' \
        sugar" or "icing sugar" -> powderedSugar, "caster sugar" or "superfine sugar" -> \
        granulatedSugar, "demerara sugar", "turbinado sugar", or "raw sugar" -> brownSugar, \
        cocoa or cocoa powder -> cocoaPowder, chocolate chips/chunks/disks/fèves -> \
        chocolateChips. Use "other" only if nothing reasonably matches.
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
        as written — do NOT compute or convert it from the other amount. Set this to 0 \
        only if the recipe gives no gram amount at all for this ingredient.
        """)
    var weightGrams: Double
    @Guide(description: """
        The cup/tablespoon/teaspoon/ounce/milliliter amount stated for this ingredient \
        (e.g. "4 cups" -> 4, "2 to 3 teaspoons" -> 2.5 using the midpoint of the range, \
        "8 1/2 ounces" -> 8.5, "250ml" -> 250). Extract this independently of \
        weightGrams — both fields can be nonzero for the same ingredient (e.g. "4 cups \
        (512 g) flour" has weightGrams: 512 AND volumeAmount: 4). Never put a gram value \
        here — a number followed by "g" or "grams" always belongs in weightGrams instead, \
        even if it's the only quantity given (e.g. "(455 g) lukewarm water" with no cup \
        amount has weightGrams: 455 and volumeAmount: 0, NOT volumeAmount: 455). Set \
        volumeAmount to 0 if the recipe gives no cup/tablespoon/teaspoon/ounce/milliliter \
        amount for this ingredient (e.g. a count like "2 eggs" or "4 cloves garlic", or no \
        measurable quantity at all such as "butter for greasing").
        """)
    var volumeAmount: Double
    @Guide(description: """
        The unit that volumeAmount is measured in. Use "ounce" for weight given in \
        ounces (e.g. "4 ounces chocolate" -> 4, ounce — NOT a gram value). Use \
        "milliliter" for "ml" amounts. Use "none" if volumeAmount is 0.
        """)
    var volumeUnit: ParsedVolumeUnit
    @Guide(description: """
        True only if this ingredient IS a flour (bread flour, all-purpose flour, whole wheat \
        flour, rye flour, semolina, etc.). Water, salt, yeast, sugar, oil, butter, eggs, milk, \
        seeds, and every other ingredient are NOT flour and must be false.
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
    case modelUnavailable
    case noFlourFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:       return "Could not read the selected image."
        case .noTextFound:        return "No readable text was found in the image."
        case .modelUnavailable:   return "Apple Intelligence is not available on this device or region."
        case .noFlourFound:       return "Could not identify any flour in the recipe. Please enter the recipe manually."
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
    var category: ParsedIngredientCategory
    var weightGrams: Double
    var isFlour: Bool
    var isPreferment: Bool
    var isExtra: Bool
    var extraAmount: Double
    var extraUnit: ParsedVolumeUnit
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
    }

    // MARK: - Volume conversion

    /// Approximate grams per US cup, by ingredient category.
    private static let gramsPerCup: [ParsedIngredientCategory: Double] = [
        .breadFlour: 127,
        .allPurposeFlour: 125,
        .cakeFlour: 114,
        .wholeWheatFlour: 113,
        .ryeFlour: 102,
        .speltFlour: 105,
        .semolinaFlour: 167,
        .oatFlour: 92,
        .cornmeal: 138,
        .riceFlour: 158,
        .almondFlour: 96,
        .buckwheatFlour: 120,
        .glutenFreeFlourBlend: 130,

        .granulatedSugar: 200,
        .brownSugar: 220,
        .powderedSugar: 120,
        .honey: 340,
        .mapleSyrup: 322,
        .molasses: 328,

        .butter: 227,
        .oliveOil: 216,
        .vegetableOil: 218,
        .coconutOil: 218,
        .shortening: 205,

        .milk: 240,
        .buttermilk: 245,
        .yogurt: 245,
        .cream: 240,
        .sourCream: 240,

        .instantYeast: 150,
        .activeDryYeast: 150,
        .freshYeast: 180,
        .sourdoughStarter: 240,
        .bakingPowder: 192,
        .bakingSoda: 220,

        .tableSalt: 288,
        .kosherSalt: 240,
        .seaSalt: 240,

        .water: 236,
        .eggs: 240,
        .seeds: 160,
        .nuts: 120,
        .spices: 100,
        .cocoaPowder: 84,
        .chocolateChips: 170,
        .other: 120,
    ]

    /// Grams per US fluid ounce of weight (1 oz = 28.3495 g). This is an exact mass
    /// conversion, independent of ingredient density, unlike cup/tablespoon/teaspoon.
    private static let gramsPerOunce = 28.3495

    /// Volume per US cup, in milliliters, used to convert "ml" amounts via density.
    private static let millilitersPerCup = 236.588

    private static func gramsForVolume(amount: Double, unit: ParsedVolumeUnit, category: ParsedIngredientCategory) -> Double {
        let perCup = gramsPerCup[category] ?? 120
        switch unit {
        case .none:
            return 0
        case .teaspoon:
            return amount * perCup / 48
        case .tablespoon:
            return amount * perCup / 16
        case .cup:
            return amount * perCup
        case .ounce:
            return amount * gramsPerOunce
        case .milliliter:
            return amount * perCup / millilitersPerCup
        }
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
        .teaspoon, .tablespoon, .cup, .milliliter,
    ]

    /// Resolves a parsed ingredient's quantity into either a gram weight or, for
    /// low-confidence ingredients with no gram amount and no learned conversion, an
    /// "extra" quantity left in its original unit.
    ///
    /// weightGrams (the gram amount stated directly in the recipe) is preferred whenever
    /// present, since it's the recipe author's own measurement. volumeAmount/volumeUnit
    /// is only used as a fallback when no gram amount was given.
    private static func resolve(_ ingredient: ParsedIngredient) -> ResolvedIngredient {
        func resolved(weightGrams: Double, isExtra: Bool = false,
                       extraAmount: Double = 0, extraUnit: ParsedVolumeUnit = .none) -> ResolvedIngredient {
            ResolvedIngredient(name: ingredient.name,
                                category: ingredient.category,
                                weightGrams: weightGrams,
                                isFlour: ingredient.isFlour,
                                isPreferment: ingredient.isPreferment,
                                isExtra: isExtra,
                                extraAmount: extraAmount,
                                extraUnit: extraUnit)
        }

        let hasVolume = ingredient.volumeAmount > 0 && ingredient.volumeUnit != .none

        // Low-confidence categories (spices, seeds, nuts, cocoa, chocolate chips, "other")
        // with a density-dependent volume measurement (teaspoon/tablespoon/cup/
        // milliliter): don't trust a model-reported weightGrams here, since the model
        // frequently hallucinates a gram conversion even when the recipe text gives none
        // (e.g. "1 to 2 teaspoons whole rosemary leaves" with no "(X g)"). Prefer a
        // previously learned conversion, or otherwise leave it as an "extra" ingredient
        // in its original unit. Ounce amounts are exact, so they skip this and resolve
        // normally below.
        if hasVolume && lowConfidenceCategories.contains(ingredient.category)
            && densityDependentUnits.contains(ingredient.volumeUnit) {
            if let gramsPerUnit = IngredientConversionStore.shared.gramsPerUnit(name: ingredient.name,
                                                                                  unit: ingredient.volumeUnit.rawValue) {
                return resolved(weightGrams: ingredient.volumeAmount * gramsPerUnit)
            }
            return resolved(weightGrams: 0, isExtra: true,
                             extraAmount: ingredient.volumeAmount, extraUnit: ingredient.volumeUnit)
        }

        if ingredient.weightGrams > 0 {
            return resolved(weightGrams: ingredient.weightGrams)
        }

        // The model sometimes places a gram amount in volumeAmount with volumeUnit "none"
        // instead of weightGrams (e.g. "(455 g) lukewarm water" -> volumeAmount: 455,
        // volumeUnit: none). Treat that as a gram value directly.
        if ingredient.volumeUnit == .none && ingredient.volumeAmount > 0 {
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

        // Use a previously learned conversion (provided by the user) if we have one.
        if let gramsPerUnit = IngredientConversionStore.shared.gramsPerUnit(name: ingredient.name,
                                                                              unit: ingredient.volumeUnit.rawValue) {
            return resolved(weightGrams: ingredient.volumeAmount * gramsPerUnit)
        }

        return resolved(weightGrams: gramsForVolume(amount: ingredient.volumeAmount,
                                                      unit: ingredient.volumeUnit,
                                                      category: ingredient.category))
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
        guard case .available = SystemLanguageModel.default.availability else {
            throw ScanError.modelUnavailable
        }
        let session = LanguageModelSession()
        let prompt = """
        Extract every ingredient from the following bread recipe text, along with its \
        quantity, whether it's a flour, and whether it belongs to a preferment.

        Important:
        - List EVERY ingredient separately, including those inside a preferment/poolish/\
          biga/levain/starter section. Do not group or merge ingredients.
        - Do not compute or guess any percentages, totals, or unit conversions — just \
          report each ingredient's quantity exactly as given. If a gram amount is shown \
          (e.g. "(512 g)"), put it in weightGrams. If a cup/tablespoon/teaspoon amount is \
          also shown (e.g. "4 cups (512 g)"), ALSO put that in volumeAmount/volumeUnit — \
          both fields can be filled in for the same ingredient, each taken from its own \
          number in the text.
        - Extract every numbered or bulleted instruction step as a separate string, in order.

        Recipe text:
        \(text)
        """
        let response = try await session.respond(to: prompt, generating: ParsedRecipe.self)
        return response.content
    }
}
#endif
