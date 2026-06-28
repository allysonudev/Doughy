//
//  RecipeWebsiteImporter.swift
//  Doughy
//

import Foundation

struct WebsiteRecipeImportRequest: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    init(url: URL) {
        self.url = url
    }

    init?(incomingURL url: URL) {
        if Self.isWebURL(url) {
            self.init(url: url)
            return
        }

        guard url.scheme?.lowercased() == "doughy",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host?.lowercased() == "import",
              let rawURL = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let recipeURL = RecipeWebsiteImporter.normalizedURL(from: rawURL) else {
            return nil
        }
        self.init(url: recipeURL)
    }

    private static func isWebURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }
}

struct WebsiteRecipeDraft: Equatable {
    var sourceURL: URL
    var name: String
    var ingredientLines: [String]
    var instructions: [String]
    var resolvedIngredients: [WebsiteResolvedIngredient]
}

struct WebsiteResolvedIngredient: Equatable {
    var originalLine: String
    var name: String
    var weightGrams: Double
    var isFlour: Bool
    var isExtra: Bool
    var extraAmount: Double
    var extraUnit: String
}

enum WebsiteRecipeImportError: LocalizedError, Equatable {
    case invalidURL
    case requestFailed
    case noRecipeData
    case missingIngredients

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "website_import.error.invalid_url", defaultValue: "Enter a valid recipe URL.")
        case .requestFailed:
            return String(localized: "website_import.error.request_failed", defaultValue: "Could not load that page. Check the URL and try again.")
        case .noRecipeData:
            return String(localized: "website_import.error.no_recipe_data", defaultValue: "That page doesn't include structured recipe data that Doughy can import yet.")
        case .missingIngredients:
            return String(localized: "website_import.error.missing_ingredients", defaultValue: "Doughy found a recipe on that page, but it did not include an ingredient list.")
        }
    }
}

struct RecipeWebsiteImporter {
    static let shared = RecipeWebsiteImporter()

    private init() {}

    func importRecipe(from url: URL) async throws -> WebsiteRecipeDraft {
        guard WebsiteRecipeImportRequest(incomingURL: url) != nil || Self.normalizedURL(from: url.absoluteString) != nil else {
            throw WebsiteRecipeImportError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Doughy/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
                throw WebsiteRecipeImportError.requestFailed
            }
            guard let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else {
                throw WebsiteRecipeImportError.requestFailed
            }
            return try Self.parse(html: html, sourceURL: url)
        } catch let error as WebsiteRecipeImportError {
            throw error
        } catch {
            throw WebsiteRecipeImportError.requestFailed
        }
    }

    static func normalizedURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.range(of: #"^[a-z][a-z0-9+\-.]*://"#, options: [.regularExpression, .caseInsensitive]) == nil
            ? "https://\(trimmed)"
            : trimmed
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            return nil
        }
        return url
    }

    static func parse(html: String, sourceURL: URL) throws -> WebsiteRecipeDraft {
        guard let recipeObject = recipeJSONObject(in: html) else {
            throw WebsiteRecipeImportError.noRecipeData
        }

        let name = cleanText(recipeObject["name"] as? String)
        let ingredientLines = strings(from: recipeObject["recipeIngredient"])
            .map(cleanText)
            .filter { !$0.isEmpty }
        guard !ingredientLines.isEmpty else {
            throw WebsiteRecipeImportError.missingIngredients
        }

        let instructions = instructionTexts(from: recipeObject["recipeInstructions"])
            .map(cleanText)
            .filter { !$0.isEmpty }

        let resolved = ingredientLines.compactMap(resolveIngredientLine)

        return WebsiteRecipeDraft(
            sourceURL: sourceURL,
            name: name.isEmpty
                ? String(localized: "website_import.default_recipe_name", defaultValue: "Imported Recipe")
                : name,
            ingredientLines: ingredientLines,
            instructions: instructions,
            resolvedIngredients: resolved
        )
    }
}

private extension RecipeWebsiteImporter {
    enum ImportUnit: String, Hashable {
        case gram
        case teaspoon
        case tablespoon
        case cup
        case ounce
        case pound
        case kilogram
        case milliliter
        case deciliter
        case liter
        case count
    }

    struct Measurement {
        var amount: Double
        var unit: ImportUnit
    }

    static let lowConfidenceVolumeCategories: Set<IngredientCategory> = [
        .spices, .seeds, .nuts, .cocoaPowder, .chocolateChips,
    ]

    static func recipeJSONObject(in html: String) -> [String: Any]? {
        for block in jsonLDBlocks(in: html) {
            guard let data = block.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                continue
            }
            if let recipe = recipeObject(in: object) {
                return recipe
            }
        }
        return nil
    }

    static func jsonLDBlocks(in html: String) -> [String] {
        let pattern = #"<script\b[^>]*type\s*=\s*["'][^"']*application/ld\+json[^"']*["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: html) else {
                return nil
            }
            return html[range]
                .replacingOccurrences(of: "<![CDATA[", with: "")
                .replacingOccurrences(of: "]]>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func recipeObject(in value: Any) -> [String: Any]? {
        if let array = value as? [Any] {
            for item in array {
                if let recipe = recipeObject(in: item) {
                    return recipe
                }
            }
            return nil
        }

        guard let dict = value as? [String: Any] else { return nil }
        if isRecipe(dict) {
            return dict
        }

        let preferredKeys = ["mainEntity", "@graph", "itemListElement"]
        for key in preferredKeys {
            if let nested = dict[key], let recipe = recipeObject(in: nested) {
                return recipe
            }
        }

        for nested in dict.values {
            if let recipe = recipeObject(in: nested) {
                return recipe
            }
        }
        return nil
    }

    static func isRecipe(_ dict: [String: Any]) -> Bool {
        guard let type = dict["@type"] else { return false }
        if let type = type as? String {
            return type.lowercased().split(separator: "/").contains("recipe")
                || type.caseInsensitiveCompare("Recipe") == .orderedSame
        }
        if let types = type as? [Any] {
            return types.contains { item in
                guard let item = item as? String else { return false }
                return item.caseInsensitiveCompare("Recipe") == .orderedSame
            }
        }
        return false
    }

    static func strings(from value: Any?) -> [String] {
        if let string = value as? String {
            return [string]
        }
        if let array = value as? [Any] {
            return array.flatMap { strings(from: $0) }
        }
        return []
    }

    static func instructionTexts(from value: Any?) -> [String] {
        guard let value else { return [] }
        if let string = value as? String {
            return splitInstructionString(string)
        }
        if let array = value as? [Any] {
            return array.flatMap { instructionTexts(from: $0) }
        }
        guard let dict = value as? [String: Any] else { return [] }

        if let nested = dict["itemListElement"] {
            return instructionTexts(from: nested)
        }
        if let nested = dict["steps"] {
            return instructionTexts(from: nested)
        }
        if let text = dict["text"] as? String {
            return splitInstructionString(text)
        }
        if let name = dict["name"] as? String {
            return splitInstructionString(name)
        }
        return []
    }

    static func splitInstructionString(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: #"</(?:p|li|br|div|h\d)>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .components(separatedBy: .newlines)
            .map(cleanText)
            .filter { !$0.isEmpty }
    }

    static func cleanText(_ raw: String?) -> String {
        guard let raw else { return "" }
        let withoutTags = raw
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        return decodeHTMLEntities(in: withoutTags)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeHTMLEntities(in text: String) -> String {
        var decoded = text
        let namedEntities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&rsquo;": "'",
            "&lsquo;": "'",
            "&rdquo;": "\"",
            "&ldquo;": "\"",
            "&ndash;": "-",
            "&mdash;": "-",
        ]
        for (entity, replacement) in namedEntities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }

        guard let regex = try? NSRegularExpression(pattern: #"&#(?:x[0-9a-fA-F]+|\d+);"#) else {
            return decoded
        }
        var result = ""
        var currentIndex = decoded.startIndex
        let nsRange = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
        for match in regex.matches(in: decoded, range: nsRange) {
            guard let range = Range(match.range, in: decoded) else { continue }
            result += decoded[currentIndex..<range.lowerBound]
            let entity = String(decoded[range])
            let scalarValue: UInt32?
            if entity.lowercased().hasPrefix("&#x") {
                scalarValue = UInt32(entity.dropFirst(3).dropLast(), radix: 16)
            } else {
                scalarValue = UInt32(entity.dropFirst(2).dropLast(), radix: 10)
            }
            if let scalarValue, let scalar = UnicodeScalar(scalarValue) {
                result.unicodeScalars.append(scalar)
            } else {
                result += entity
            }
            currentIndex = range.upperBound
        }
        result += decoded[currentIndex...]
        return result
    }

    static func resolveIngredientLine(_ line: String) -> WebsiteResolvedIngredient? {
        let cleaned = cleanIngredientLine(line)
        guard !cleaned.isEmpty else { return nil }

        let lower = cleaned.lowercased()
        let name = ingredientName(from: cleaned)
        guard !name.isEmpty else { return nil }

        let category = ExtraIngredientConversion.ingredientCategory(forName: name)
        let isFlour = isFlourName(name, category: category)

        if lower.contains("yeast"),
           (lower.contains("package") || lower.contains("packet")),
           firstMeasurement(in: cleaned, units: [.gram, .kilogram, .ounce, .pound]) == nil {
            return WebsiteResolvedIngredient(originalLine: line, name: name, weightGrams: 7, isFlour: false, isExtra: false, extraAmount: 0, extraUnit: "count")
        }

        if let weight = firstMeasurement(in: cleaned, units: [.gram, .kilogram])
            ?? firstMeasurement(in: cleaned, units: [.ounce, .pound]) {
            return WebsiteResolvedIngredient(originalLine: line, name: name, weightGrams: grams(forWeight: weight), isFlour: isFlour, isExtra: false, extraAmount: 0, extraUnit: "count")
        }

        if let eggCount = firstEggMeasurement(in: cleaned) {
            let grams = ExtraIngredientConversion.suggest(name: name, amount: eggCount, unit: "count")?.grams
                ?? eggCount * IngredientDensityStore.shared.gramsPerEgg(for: IngredientDensityStore.shared.defaultEggSize())
            return WebsiteResolvedIngredient(originalLine: line, name: name, weightGrams: grams, isFlour: false, isExtra: false, extraAmount: 0, extraUnit: "count")
        }

        if let count = firstCountMeasurement(in: cleaned) {
            return WebsiteResolvedIngredient(originalLine: line, name: name, weightGrams: 0, isFlour: false, isExtra: true, extraAmount: count, extraUnit: "count")
        }

        guard let volume = firstMeasurement(in: cleaned, units: [.teaspoon, .tablespoon, .cup, .milliliter, .deciliter, .liter]) else {
            return nil
        }

        let extraUnit = volume.unit.rawValue
        if let gramsPerUnit = IngredientConversionStore.shared.gramsPerUnit(name: name, unit: extraUnit) {
            return WebsiteResolvedIngredient(originalLine: line, name: name, weightGrams: volume.amount * gramsPerUnit, isFlour: isFlour, isExtra: false, extraAmount: 0, extraUnit: extraUnit)
        }

        guard let category else {
            return WebsiteResolvedIngredient(originalLine: line, name: name, weightGrams: 0, isFlour: false, isExtra: true, extraAmount: volume.amount, extraUnit: extraUnit)
        }

        if lowConfidenceVolumeCategories.contains(category)
            || IngredientConversionStore.shared.isAlwaysExtra(name: name, unit: extraUnit) {
            return WebsiteResolvedIngredient(originalLine: line, name: name, weightGrams: 0, isFlour: false, isExtra: true, extraAmount: volume.amount, extraUnit: extraUnit)
        }

        return WebsiteResolvedIngredient(
            originalLine: line,
            name: name,
            weightGrams: grams(forVolume: volume, category: category),
            isFlour: isFlour,
            isExtra: false,
            extraAmount: 0,
            extraUnit: extraUnit
        )
    }

    static func cleanIngredientLine(_ line: String) -> String {
        cleanText(line)
            .trimmingCharacters(in: CharacterSet(charactersIn: "•-* \t"))
            .replacingOccurrences(of: "º", with: "°")
    }

    static func ingredientName(from line: String) -> String {
        var working = cleanIngredientLine(line)
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: measurementRemovalPattern(excludingEggs: true), with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"(?i)^\s*(?:one|about|approximately|approx\.?|plus|minus|of|the|for|or|and|scant)\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])\s+"#, with: "", options: .regularExpression)

        if let comma = working.firstIndex(of: ",") {
            working = String(working[..<comma])
        }
        if let semicolon = working.firstIndex(of: ";") {
            working = String(working[..<semicolon])
        }

        working = working
            .replacingOccurrences(of: #"(?i)\b(?:warmed|melted|softened|beaten|chopped|packed|spooned|minced|sifted|divided|room temperature|at room temperature)\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*(?:pinch\s+of)\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -/,\t\n"))

        let lowerLine = line.lowercased()
        if working.isEmpty {
            if lowerLine.contains("egg white") { return "Egg Whites" }
            if lowerLine.contains("egg yolk") { return "Egg Yolks" }
            if lowerLine.contains("egg") { return "Eggs" }
        }

        return working.capitalized
    }

    static func measurementRemovalPattern(excludingEggs: Bool) -> String {
        let amount = #"(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])"#
        let units = excludingEggs
            ? #"(?:g|grams?|kg|kilograms?|ml|milliliters?|dl|deciliters?|decilitres?|l|liters?|litres?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|pounds?|lbs?\.?)"#
            : #"(?:g|grams?|kg|kilograms?|ml|milliliters?|dl|deciliters?|decilitres?|l|liters?|litres?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|ounces?|oz\.?|pounds?|lbs?\.?|eggs?|egg\s+whites?|egg\s+yolks?)"#
        // Leading guard is a negative look-behind (not \b): a line can start with a Unicode
        // vulgar fraction (¼, ½, …) which isn't a word character, so \b never matches before it
        // and the unit would be left stuck in the ingredient name (e.g. "Teaspoon Cream Of Tartar").
        return #"(?<![0-9A-Za-z])"# + amount + #"(?:\s*(?:to|[-–—])\s*"# + amount + #")?\s*-?\s*"# + units + #"\b"#
    }

    static func firstMeasurement(in text: String, units: Set<ImportUnit>) -> Measurement? {
        let candidates = units.compactMap { unit -> (Measurement, Range<String.Index>)? in
            guard let pattern = pattern(for: unit),
                  let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
                  let amount = parseAmountRange(String(text[range])) else {
                return nil
            }
            return (Measurement(amount: amount, unit: unit), range)
        }
        return candidates.min { $0.1.lowerBound < $1.1.lowerBound }?.0
    }

    static func firstEggMeasurement(in text: String) -> Double? {
        let amount = amountPattern
        let pattern = #"\b"# + amount + #"(?:\s*(?:to|[-–—])\s*"# + amount + #")?\s*(?:small|medium|large|extra-large|extra\s+large|jumbo)?\s*(?:eggs?|egg\s+whites?|egg\s+yolks?|whites?|yolks?)\b"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        return parseAmountRange(String(text[range]))
    }

    static func firstCountMeasurement(in text: String) -> Double? {
        let amount = amountPattern
        let pattern = #"\b"# + amount + #"(?:\s*(?:to|[-–—])\s*"# + amount + #")?\s+(?:oranges?|lemons?|limes?|cloves?|(?:[a-z]+\s+)?leaves)\b"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        return parseAmountRange(String(text[range]))
    }

    static var amountPattern: String {
        #"(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])"#
    }

    static func pattern(for unit: ImportUnit) -> String? {
        let unitPattern: String
        switch unit {
        case .gram: unitPattern = #"(?:g|grams?)"#
        case .kilogram: unitPattern = #"(?:kg|kilograms?)"#
        case .ounce: unitPattern = #"(?:ounces?|oz\.?)"#
        case .pound: unitPattern = #"(?:pounds?|lbs?\.?)"#
        case .milliliter: unitPattern = #"(?:ml|milliliters?)"#
        case .deciliter: unitPattern = #"(?:dl|deciliters?|decilitres?)"#
        case .liter: unitPattern = #"(?:l|liters?|litres?)"#
        case .cup: unitPattern = #"(?:cups?|c\.)"#
        case .tablespoon: unitPattern = #"(?:tablespoons?|tbsp\.?)"#
        case .teaspoon: unitPattern = #"(?:teaspoons?|tsp\.?)"#
        case .count: return nil
        }
        return #"\b"# + amountPattern + #"(?:\s*(?:to|[-–—])\s*"# + amountPattern + #")?\s*-?\s*"# + unitPattern + #"\b"#
    }

    static func parseAmountRange(_ raw: String) -> Double? {
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

    static func parseAmount(_ raw: String) -> Double? {
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

    static func grams(forWeight measurement: Measurement) -> Double {
        switch measurement.unit {
        case .gram: return measurement.amount
        case .kilogram: return measurement.amount * 1_000
        case .ounce: return measurement.amount * UnitConversion.gramsPerOunce
        case .pound: return measurement.amount * 16 * UnitConversion.gramsPerOunce
        default: return 0
        }
    }

    static func grams(forVolume measurement: Measurement, category: IngredientCategory) -> Double {
        guard let densityUnit = DensityUnit(rawValue: measurement.unit.rawValue) else { return 0 }
        let cups = measurement.amount / densityUnit.unitsPerCup
        return cups * IngredientDensityStore.shared.gramsPerCup(for: category)
    }

    static func isFlourName(_ name: String, category: IngredientCategory?) -> Bool {
        if category?.group == .flours { return true }
        return name.lowercased().contains("flour")
    }
}
