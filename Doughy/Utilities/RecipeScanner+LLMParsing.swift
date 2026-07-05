//
//  RecipeScanner+LLMParsing.swift
//  Doughy
//

import Foundation
import UIKit
import Vision
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
extension RecipeScanner {
    // MARK: - LLM parsing

    func parseRecipe(from text: String) async throws -> ParsedRecipe {
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

    static func shouldUseLocalRecipe(_ recipe: ParsedRecipe) -> Bool {
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

    static func usefulIngredientCount(in recipe: ParsedRecipe) -> Int {
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

    static func repairedIngredientLines(from text: String) -> [String] {
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

    static func startsWithUnitWithoutAmount(_ line: String) -> Bool {
        line.range(of: #"(?i)^\s*(?:cups?|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|pounds?|lbs?\.?|kilograms?|kg|ml|milliliters?)\b"#,
                   options: .regularExpression) != nil
            && line.range(of: #"(?i)^\s*(?:cups?|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|pounds?|lbs?\.?|kilograms?|kg|ml|milliliters?)\s*\)?\s*$"#,
                          options: .regularExpression) == nil
            && leadingAmountRange(in: line) == nil
    }

    static func isAmountOnlyLine(_ line: String) -> Bool {
        line.range(of: #"^\s*(?:(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|(?:\d+/\d+)|[¼½¾⅓⅔⅛⅜⅝⅞])(?:\s*(?:to|[-–—])\s*(?:(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|(?:\d+/\d+)|[¼½¾⅓⅔⅛⅜⅝⅞]))?\s*$"#,
                   options: .regularExpression) != nil
    }

    static func isClosingMeasurementContinuation(_ line: String) -> Bool {
        line.range(of: #"(?i)^\s*(?:g|grams?|ml|milliliters?|cups?|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?)\s*\)\s*$"#,
                   options: .regularExpression) != nil
    }

    static func leadingAmountRange(in line: String) -> Range<String.Index>? {
        line.range(of: #"^\s*((?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|(?:\d+/\d+)|[¼½¾⅓⅔⅛⅜⅝⅞])\b"#,
                   options: .regularExpression)
    }

    static func shouldAppendAsContinuation(_ line: String, after previous: String?) -> Bool {
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

    /// Removes secondary "plus …" asides whose amount is not part of the ingredient's
    /// measurement, e.g. "480 g flour, plus more for dusting" or "4 cups flour, plus
    /// 30 g for greasing the pan" — otherwise the aside's gram value can be picked up
    /// as the ingredient's weight. Compound amounts like "1 cup plus 2 tablespoons
    /// sugar" contain none of the aside keywords and pass through untouched.
    static func strippedSecondaryAmounts(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"(?i)[,;]?\s*\bplus\b[^,;]*\b(?:more|extra|dusting|greasing|kneading|rolling|sprinkling|shaping|serving|the\s+pan|the\s+bowl|work\s+surface)\b[^,;]*"#,
            with: "",
            options: .regularExpression)
    }

    static func isSectionHeader(_ line: String) -> Bool {
        // Yield notes in parentheses ("For the poolish (makes 250 g)") don't make a
        // header an ingredient line — strip them before the no-digits check so the
        // 250 doesn't disqualify it. A measured line like "100 g poolish" still has
        // its digits outside parentheses and stays an ingredient.
        let withoutParentheticals = line
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\([^)]*$"#, with: "", options: .regularExpression)
        return withoutParentheticals.range(of: #"\b(for the|to assemble|biga|poolish|levain|starter|preferment|tangzhong|yudane|dough|filling|glaze|frosting|ingredients?)\b"#,
                                           options: [.regularExpression, .caseInsensitive]) != nil
            && withoutParentheticals.range(of: #"(?:\d|[¼½¾⅓⅔⅛⅜⅝⅞])"#, options: .regularExpression) == nil
    }

    static func parseIngredientLine(_ line: String, section: String) -> ParsedIngredient? {
        let cleaned = strippedSecondaryAmounts(
            line
                .trimmingCharacters(in: CharacterSet(charactersIn: "•-* \t"))
                .replacingOccurrences(of: "º", with: "°")
        )
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
        var packageYeastGrams = 0.0
        if isUnmeasuredYeastPackage {
            // "2 packages active dry yeast" — the leading amount is the package count.
            var packageCount = 1.0
            if let range = leadingAmountRange(in: cleaned),
               let amount = parseAmount(String(cleaned[range]).trimmingCharacters(in: .whitespaces)),
               amount > 0 {
                packageCount = amount
            }
            packageYeastGrams = 7.0 * packageCount
        }
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

    static func firstAmount(in text: String, beforeUnitPattern unitPattern: String) -> Double? {
        let amountPattern = #"(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])"#
        // (?<![0-9A-Za-z]) instead of \b: a line can start with a Unicode vulgar
        // fraction ("½ cup olive oil"), and \b never matches before a non-word char.
        let pattern = #"(?i)(?<![0-9A-Za-z])"# + amountPattern + #"(?:\s*(?:to|[-–—])\s*"# + amountPattern + #")?\s*"# + unitPattern + #"\b"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        return parseAmountRange(String(text[match]))
    }

    struct VolumeMeasurement {
        var range: Range<String.Index>
        var amount: Double
        var unit: ParsedVolumeUnit
    }

    static func firstVolumeMeasurement(in text: String) -> VolumeMeasurement? {
        // Fluid ounces are a volume, not the mass "ounce" — listed before plain ounce,
        // though the mass pattern can't match "8 fl oz" anyway ("fl" sits between the
        // amount and "oz", and only whitespace/hyphens are allowed there).
        let patterns: [(String, ParsedVolumeUnit)] = [
            (#"(?:fl\.?\s*oz\.?|fluid\s+ounces?)"#, .fluidOunce),
            (#"(?:ml|milliliters?)"#, .milliliter),
            (#"(?:dl|deciliters?|decilitres?)"#, .deciliter),
            (#"(?:l|liters?|litres?)"#, .liter),
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
            let pattern = #"(?i)(?<![0-9A-Za-z])"# + amountPattern + #"(?:\s*(?:to|[-–—])\s*"# + amountPattern + #")?\s*-?\s*"# + unitPattern + #"\b"#
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

    static func firstCountMeasurement(in text: String) -> Double? {
        let amountPattern = #"(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])"#
        let pattern = #"(?i)(?<![0-9A-Za-z])"# + amountPattern + #"(?:\s*(?:to|[-–—])\s*"# + amountPattern + #")?\s+(?:oranges?|lemons?|limes?|cloves?|(?:[a-z]+\s+)?leaves)\b"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        return parseAmountRange(String(text[match]))
    }

    static func leadingOCRGramAmount(in text: String) -> Double? {
        let pattern = #"^\s*(\d+(?:[.,]\d+)?)\s+9\b"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        let matched = String(text[match])
        guard let amountRange = matched.range(of: #"\d+(?:[.,]\d+)?"#, options: .regularExpression) else {
            return nil
        }
        return Double(matched[amountRange].replacingOccurrences(of: ",", with: ""))
    }

    static func parseAmount(_ raw: String) -> Double? {
        let trimmed = normalizedDecimalSeparators(raw.trimmingCharacters(in: .whitespacesAndNewlines))
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

    static func parseAmountRange(_ raw: String) -> Double? {
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

    static func parseSlashFraction(_ raw: String) -> Double? {
        let pieces = raw.split(separator: "/")
        guard pieces.count == 2,
              let numerator = Double(pieces[0]),
              let denominator = Double(pieces[1]),
              denominator != 0 else {
            return nil
        }
        return numerator / denominator
    }

    /// "1,000 grams" uses a thousands comma but European recipes write decimals with a
    /// comma ("1,5 dl"). Exactly one or two digits after the comma means decimal;
    /// anything else is treated as a thousands separator and dropped.
    static func normalizedDecimalSeparators(_ raw: String) -> String {
        if raw.range(of: #"^\d+,\d{1,2}$"#, options: .regularExpression) != nil {
            return raw.replacingOccurrences(of: ",", with: ".")
        }
        return raw.replacingOccurrences(of: ",", with: "")
    }

    static func ingredientName(from line: String) -> String {
        var working = line
            // A leading "Label:" (e.g. "Additional toppings:", "Optional:", "For the filling:")
            // is a section/category tag, not part of the ingredient name - unlike `isSectionHeader`,
            // this fires even when the rest of the line has a quantity, since it only strips the
            // prefix rather than requiring the whole line to be header-only. Anchored to the start
            // and requiring the label to be letters only (no digits) so it never touches a
            // quantity-first line like "2 TBSP/17g Kosher Salt".
            .replacingOccurrences(of: #"(?i)^\s*[a-z][a-z\s'-]{0,38}:\s*(?=\S)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\([^)]*$"#, with: "", options: .regularExpression)
            // Bracketed asides like "[or whatever you like]" - same treatment as parens above.
            .replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\[[^\]]*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\d+(?:[.,]\d+)?\s+9\b"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*one\s+"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b\d+\s+(?=(?:small|medium|large|extra-large|extra large|jumbo)?\s*eggs?\b)"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])\s*(?:to|[-–—])\s*(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])\s*-?\s*(?:g|grams?|ml|milliliters?|dl|deciliters?|decilitres?|l|liters?|litres?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\.?\s*oz\.?|pounds?|lbs?\.?|kilograms?|kg)\b"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?\s*-?\s*(?:g|grams?|ml|milliliters?|dl|deciliters?|decilitres?|l|liters?|litres?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\.?\s*oz\.?|pounds?|lbs?\.?|kilograms?|kg)\b"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b\d+/\d+\s*-?\s*(?:g|grams?|ml|milliliters?|dl|deciliters?|decilitres?|l|liters?|litres?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\.?\s*oz\.?|pounds?|lbs?\.?|kilograms?|kg)\b"#,
                                  with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\b[¼½¾⅓⅔⅛⅜⅝⅞]\s*-?\s*(?:g|grams?|ml|milliliters?|dl|deciliters?|decilitres?|l|liters?|litres?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\.?\s*oz\.?|pounds?|lbs?\.?|kilograms?|kg)\b"#,
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
                .replacingOccurrences(of: #"(?i)^\s*(?:cups?|cup|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|fl\.?\s*oz\.?|pounds?|lbs?\.?|kilograms?|kg|dl|deciliters?|decilitres?|liters?|litres?|packages?|packets?)\s*(?:of\s+)?/?\s*"#,
                                      with: "",
                                      options: .regularExpression)
                .replacingOccurrences(of: #"(?i)\b(?:warmed|melted|softened|creamy|beaten|chopped|packed|spooned|minced|sifted|free-range|free range)\b"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                // "." included for unit-dot residue: stripping "4 fl. oz." backtracks
                // off the final dot (the pattern ends \b), leaving ". water".
                .trimmingCharacters(in: CharacterSet(charactersIn: " -/,.\t\n"))
        }

        let lower = working.lowercased()
        if lower.contains("zest") {
            if lower.contains("orange") { return "orange zest" }
            if lower.contains("lemon") { return "lemon zest" }
            if lower.contains("lime") { return "lime zest" }
        }

        return working
    }

    static func ingredientNameChoice(from name: String, line: String) -> (name: String, alternativeName: String) {
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

    static func trimmedAtPreparationComma(_ name: String) -> String {
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

    static func category(forIngredientName name: String) -> ParsedIngredientCategory {
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
        if lower.contains("margarine") { return .margarine }
        // "buttermilk" must be checked before "butter" and "milk", which are substrings of it.
        if lower.contains("buttermilk") { return .buttermilk }
        if lower.contains("butter") { return .butter }
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

    static func isKnownNoQuantityIngredient(_ name: String, category: ParsedIngredientCategory) -> Bool {
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

    static func isFlourName(_ name: String, category: ParsedIngredientCategory) -> Bool {
        switch category {
        case .breadFlour, .allPurposeFlour, .cakeFlour, .wholeWheatFlour, .ryeFlour,
             .speltFlour, .semolinaFlour, .oatFlour, .cornmeal, .riceFlour, .almondFlour,
             .buckwheatFlour, .glutenFreeFlourBlend, .tipo00Flour:
            return true
        default:
            return name.lowercased().contains("flour")
        }
    }

    static func eggSize(forIngredientName name: String) -> ParsedEggSize {
        let lower = name.lowercased()
        if lower.contains("extra large") || lower.contains("extra-large") { return .extraLarge }
        if lower.contains("jumbo") { return .jumbo }
        if lower.contains("large") { return .large }
        if lower.contains("medium") { return .medium }
        if lower.contains("small") { return .small }
        return .unspecified
    }

    static func eggPart(forIngredientName name: String) -> ParsedEggPart {
        let lower = name.lowercased()
        if lower.contains("white") { return .white }
        if lower.contains("yolk") { return .yolk }
        return .whole
    }

    static func isPrefermentSection(_ section: String) -> Bool {
        section.range(of: #"\b(biga|poolish|levain|starter|preferment|tangzhong|yudane)\b"#,
                      options: [.regularExpression, .caseInsensitive]) != nil
    }

    func parseRecipeEssentials(from text: String) async throws -> ParsedRecipe {
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

    func parseRecipeEssentialsInChunks(from text: String) async throws -> ParsedRecipe {
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

    func parseRecipeEssentialsResponse(from text: String, isExcerpt: Bool) async throws -> ParsedRecipeEssentials {
        let session = LanguageModelSession()
        let scope = isExcerpt
            ? "This text may be only one excerpt from a longer recipe. Extract ingredient lines visible in this excerpt."
            : "Extract every ingredient from the following bread recipe text, along with its quantity, whether it's a flour, and whether it belongs to a preferment."
        let prompt = """
        \(scope)

        Important:
        - List EVERY ingredient separately, including those inside a preferment/poolish/\
          biga/levain/starter/tangzhong section. Do not group or merge ingredients.
        - If this text contains no ingredient lines, return an empty ingredients list.
        - Do not compute or guess any percentages, totals, or unit conversions — just \
          report each ingredient's quantity exactly as given. If a gram amount is shown \
          (e.g. "(512 g)"), put it in weightGrams. If a cup/tablespoon/teaspoon amount is \
          also shown (e.g. "4 cups (512 g)"), ALSO put that in volumeAmount/volumeUnit — \
          both fields can be filled in for the same ingredient, each taken from its own \
          number in the text.
        - If an ingredient gives a range such as "1/2 to 1 tablespoon" or "10 to 15 \
          grams", use the midpoint for that field.
        - Ignore amounts that are only a "plus" aside — "plus more for dusting", \
          "plus extra for the pan", "plus 30 g for greasing" — and report just the \
          main amount (e.g. "4 cups flour, plus 30 g for dusting" -> volumeAmount 4, \
          volumeUnit cup, weightGrams 0).
        - Treat packages/packets of active dry yeast or instant yeast as 7 grams \
          each — "1 package" -> weightGrams 7, "2 packages" -> weightGrams 14 — with \
          volumeAmount 0 and volumeUnit none, even though the gram value is implied \
          by the package.
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

    /// A lightweight on-device pass over an already-parsed ingredient list: cleans up any
    /// leftover formatting artifacts in each name (category labels, OCR noise) and flags
    /// entries that don't look like real ingredients at all (e.g. leaked instruction text),
    /// so those can be surfaced for the user to confirm or remove rather than silently kept
    /// or dropped. Quantities/units are left untouched - the local parser already gets those
    /// right; this pass only touches names and validity.
    func cleanIngredientNames(_ ingredients: [ParsedIngredient]) async throws -> [IngredientNameReview] {
        let session = LanguageModelSession()
        let itemsList = ingredients.enumerated()
            .map { index, ingredient in "\(index). \(ingredient.name)" }
            .joined(separator: "\n")

        let prompt = """
        Here is a list of ingredient names extracted from a scanned bread recipe. Some may \
        still have leftover text that doesn't belong: a category label like "Additional \
        toppings:", stray words from OCR noise, or (rarely) a fragment of instruction text \
        that was mistakenly captured as an ingredient. Review each one and, for every index, \
        return a cleaned name and whether it's a genuine ingredient.

        Rules:
        - Only remove text that clearly is not part of the ingredient name itself.
        - Never reword, translate, abbreviate, or expand a name; keep its spelling as-is.
        - Keep brand and variety words that identify the ingredient — "Diamond Crystal \
          Kosher Salt" keeps "Diamond Crystal", "bread flour" stays "bread flour".
        - Return exactly one review per listed index.

        Ingredients:
        \(itemsList)
        """
        let response = try await session.respond(to: prompt, generating: IngredientNameReviewBatch.self)
        return response.content.reviews
    }

    static func chunkedLines(from text: String, maxCharacters: Int = 1_500) -> [String] {
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

    static func splitLongLine(_ line: String, maxCharacters: Int) -> [String] {
        var pieces: [String] = []
        var start = line.startIndex
        while start < line.endIndex {
            let end = line.index(start, offsetBy: maxCharacters, limitedBy: line.endIndex) ?? line.endIndex
            pieces.append(String(line[start..<end]))
            start = end
        }
        return pieces
    }

    static func isContextLimitError(_ error: Error) -> Bool {
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
