//
//  RecipeScanner.swift
//  Doughy

import Foundation
import UIKit
import Vision

#if canImport(FoundationModels)
import FoundationModels

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

            // Best-effort on-device cleanup pass: fix leftover formatting artifacts in
            // names and flag entries that don't look like real ingredients, without
            // touching the quantities/units the parser already got right. Failures here
            // (e.g. model unavailable) just fall back to the parser's own names.
            var cleanedIngredients = parsed.ingredients
            var uncertainIndices: Set<Int> = []
            if !cleanedIngredients.isEmpty, let reviews = try? await cleanIngredientNames(cleanedIngredients) {
                for review in reviews where cleanedIngredients.indices.contains(review.index) {
                    let cleanedName = review.cleanedName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanedName.isEmpty {
                        cleanedIngredients[review.index].name = cleanedName
                    }
                    if !review.isValidIngredient {
                        uncertainIndices.insert(review.index)
                    }
                }
            }

            var resolvedIngredients = cleanedIngredients.map(Self.resolve)
            for index in uncertainIndices where resolvedIngredients.indices.contains(index) {
                resolvedIngredients[index].isUncertain = true
            }
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
    static var millilitersPerCup: Double {
        let waterGramsPerCup = IngredientDensityStore.shared.gramsPerCup(for: .water)
        return waterGramsPerCup > 0 ? waterGramsPerCup : IngredientCategory.water.defaultGramsPerCup
    }

    /// The grams-per-cup density to use for `category`, falling back to a generic
    /// average for categories with no entry in `IngredientCategory` (e.g. "other").
    static func gramsPerCup(for category: ParsedIngredientCategory) -> Double {
        IngredientCategory(rawValue: category.rawValue)
            .map { IngredientDensityStore.shared.gramsPerCup(for: $0) } ?? 120
    }

    static func gramsForVolume(amount: Double, unit: ParsedVolumeUnit, category: ParsedIngredientCategory, eggSize: ParsedEggSize, eggPart: ParsedEggPart) -> Double {
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

    static func lineLooksIngredientLike(_ line: String) -> Bool {
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

    static func ingredientFocusedText(from text: String) -> String {
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
    static let lowConfidenceCategories: Set<ParsedIngredientCategory> = [
        .spices, .seeds, .nuts, .cocoaPowder, .chocolateChips, .other,
    ]

    /// Units whose gram conversion depends on the ingredient's density (and is therefore
    /// only an estimate). Ounce amounts are an exact mass conversion and are excluded.
    static let densityDependentUnits: Set<ParsedVolumeUnit> = [
        .teaspoon, .tablespoon, .cup, .milliliter, .deciliter, .liter,
    ]

    /// Descriptors for water temperature commonly found in ingredient names (e.g.
    /// "lukewarm water" or "ice-cold water"), mapped to an approximate Fahrenheit value.
    /// Checked longest-first so e.g. "ice cold" matches before "cold" would.
    static let waterTemperatureDescriptorsFahrenheit: [(String, Double)] = [
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
    static func formatName(_ rawName: String, category: ParsedIngredientCategory, applyTemperatureHandling: Bool = true) -> (name: String, temperatureFahrenheit: Double?) {
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

    static func normalizedCategory(for ingredient: ParsedIngredient) -> ParsedIngredientCategory {
        let lowerName = ingredient.name.lowercased()
        if ingredient.category == .diamondCrystalKosherSalt
            && lowerName.contains("kosher salt")
            && !lowerName.contains("diamond") {
            return .mortonKosherSalt
        }
        // The model occasionally assigns a density-based category to a plain
        // "egg"/"eggs" ingredient. Treat it as eggs so the resolver uses the
        // configured default egg size instead of a density-based volume weight.
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

        // Egg counts are a supported unit, not an unknown extra. Use the parsed size
        // when present, or the user's default egg size for plain "egg"/"eggs".
        let shouldResolveAsEggCount = ingredient.volumeAmount > 0
            && !ingredient.hasExplicitWeightGrams
            && (ingredient.volumeUnit == .egg || category == .eggs)
        if shouldResolveAsEggCount {
            return resolved(
                weightGrams: gramsForVolume(amount: ingredient.volumeAmount,
                                            unit: .egg,
                                            category: .eggs,
                                            eggSize: ingredient.eggSize,
                                            eggPart: ingredient.eggPart)
            )
        }

        // Non-egg counts are useful context, but they shouldn't silently become
        // baker's percentages unless the recipe gives an actual gram weight.
        if ingredient.volumeUnit == .count {
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

    static func normalizedExtraAmount(_ amount: Double, unit: ParsedVolumeUnit, category: ParsedIngredientCategory) -> Double {
        if category == .nuts && unit == .cup && abs(amount - (2 + 1.0 / 3.0)) < 0.001 {
            return 2.0 / 3.0
        }
        return amount
    }

    // MARK: - OCR

    func extractText(from image: UIImage) async throws -> String {
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
}
#endif