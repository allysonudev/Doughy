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
    var structuredRecipeJSON: String?
    var name: String
    var ingredientLines: [String]
    var instructions: [String]
    var resolvedIngredients: [WebsiteResolvedIngredient]
    /// Display name of the detected preferment (e.g. "Poolish", "Biga"), or `nil` if the
    /// recipe doesn't appear to use one. See `WebsiteResolvedIngredient.isPreferment`.
    var prefermentName: String?
    /// Ingredient lines that are back-references to the preferment rather than real
    /// ingredients (e.g. "all of the poolish") and should be dropped entirely - not shown
    /// as an ingredient, resolved or otherwise.
    var ignoredIngredientLines: Set<String> = []
}

struct WebsiteResolvedIngredient: Equatable {
    var originalLine: String
    var name: String
    var weightGrams: Double
    var isFlour: Bool
    var isExtra: Bool
    var extraAmount: Double
    var extraUnit: String
    var isPreferment: Bool = false
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
        // JSON-LD first (the modern, structured path); fall back to microdata
        // attributes for older sites (WordPress recipe plugins, hRecipe-era themes).
        guard let recipeObject = recipeJSONObject(in: html) ?? microdataRecipeObject(in: html) else {
            throw WebsiteRecipeImportError.noRecipeData
        }

        let name = cleanText(recipeObject["name"] as? String)
        // flatMap through the line-block splitter: some sites publish recipeIngredient
        // as one "500g flour<br>320g water" HTML string instead of an array, which
        // would otherwise collapse the whole recipe into a single mega-ingredient.
        let ingredientLines = strings(from: recipeObject["recipeIngredient"])
            .flatMap(splitHTMLLineBlocks)
        guard !ingredientLines.isEmpty else {
            throw WebsiteRecipeImportError.missingIngredients
        }

        let instructions = instructionTexts(from: recipeObject["recipeInstructions"])
            .map(cleanText)
            .filter { !$0.isEmpty }

        // Structured recipe data (JSON-LD) has no concept of ingredient groups, so a
        // preferment (poolish, biga, starter, ...) and the main dough end up as one flat
        // list with the preferment's ingredients duplicated by name - which both loses the
        // "this recipe uses a preferment" structure and produces two same-named ingredients
        // in one list. Try the site's own rendered HTML grouping first (most reliable, and
        // gives the preferment's real name); fall back to detecting a plain-text
        // back-reference line like "all of the poolish" between the two ingredient groups.
        let preferment = prefermentLines(fromHTML: html, ingredientLines: ingredientLines)
            ?? prefermentLines(fromBackReferenceIn: ingredientLines)
        let ignoredLines = backReferenceLines(in: ingredientLines)

        var resolved: [WebsiteResolvedIngredient] = []
        for line in ingredientLines where !ignoredLines.contains(line) {
            guard var ingredient = resolveIngredientLine(line) else { continue }
            if preferment?.lines.contains(line) == true {
                ingredient.isPreferment = true
            }
            resolved.append(ingredient)
        }

        return WebsiteRecipeDraft(
            sourceURL: sourceURL,
            structuredRecipeJSON: prettyJSONString(from: recipeObject),
            name: name.isEmpty
                ? String(localized: "website_import.default_recipe_name", defaultValue: "Imported Recipe")
                : name,
            ingredientLines: ingredientLines,
            instructions: instructions,
            resolvedIngredients: resolved,
            prefermentName: preferment?.name,
            ignoredIngredientLines: ignoredLines
        )
    }
}

private extension RecipeWebsiteImporter {
    enum ImportUnit: String, Hashable {
        case gram
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
        case count
    }

    struct Measurement {
        var amount: Double
        var unit: ImportUnit
    }

    static let lowConfidenceVolumeCategories: Set<IngredientCategory> = [
        .spices, .seeds, .nuts, .cocoaPowder, .chocolateChips,
    ]

    /// Ingredient brand names some sites (King Arthur, notably) prepend to every
    /// ingredient, e.g. "King Arthur Unbleached All-Purpose Flour". Deliberately a curated
    /// list rather than a category-keyword match: swapping in a category's generic display
    /// name for any fuzzy keyword hit would mangle real compound ingredient names
    /// (e.g. "Cream Cheese" contains "cream" but isn't the `.cream` category; "Almond Meal
    /// or Almond Flour" would collapse to "Almond Flour" and lose the "meal" alternative).
    static let knownIngredientBrandPrefixes: [String] = [
        "King Arthur Baking Company", "King Arthur Flour", "King Arthur",
        "Bob's Red Mill", "Gold Medal", "Pillsbury", "Red Star", "Fleischmann's",
        "Domino", "C&H", "Land O'Lakes", "Hodgson Mill", "Arrowhead Mills",
        "Antimo Caputo", "Caputo",
    ]

    /// Marketing descriptors that add no baking-relevant meaning once a brand prefix (or
    /// nothing) has been stripped, e.g. "Unbleached All-Purpose Flour" -> "All-Purpose Flour".
    static let genericIngredientMarketingWords: [String] = [
        "Unbleached", "Bleached", "Organic", "Non-GMO", "Enriched", "Natural", "Pure",
    ]

    /// Strips a leading brand-name prefix and/or marketing descriptor from a scraped
    /// ingredient name, e.g. "King Arthur Unbleached All-Purpose Flour" -> "All-Purpose
    /// Flour". Both lists are anchored to the *start* of the name so a real ingredient word
    /// that happens to match elsewhere in the string is never touched.
    static func stripBrandingAndMarketing(from name: String) -> String {
        var working = stripLeadingMatch(knownIngredientBrandPrefixes, from: name, repeated: false)
        working = stripLeadingMatch(genericIngredientMarketingWords, from: working, repeated: true)
        let trimmed = working.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? name : trimmed
    }

    private static func stripLeadingMatch(_ candidates: [String], from name: String, repeated: Bool) -> String {
        let alternation = candidates.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let pattern = repeated ? "^(?:(?:\(alternation))\\s+)+" : "^(?:\(alternation))\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return name
        }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return regex.stringByReplacingMatches(in: name, range: range, withTemplate: "")
    }

    // MARK: - Preferment detection

    struct PrefermentLines {
        var name: String
        var lines: Set<String>
    }

    /// Matches the common English preferment/pre-ferment nouns. Used both to find a
    /// heading like "Poolish" in a site's rendered HTML and to recognize a plain-text
    /// back-reference line like "all of the poolish" in the flat ingredient list.
    static let prefermentNounPattern = #"(?:sourdough\s+starter|p[aâ]te\s+ferment[ée]e|old\s+dough|poolish|biga|sponge|levain|preferment|starter|tangzhong|yudane)"#

    /// A line is a preferment back-reference (not a real ingredient) only if it also fails
    /// to resolve as a measured ingredient - guarding against a real, measured entry like
    /// "1/4 cup (60g) sourdough starter, fed" being mistaken for a reference to a poolish
    /// made earlier in the same recipe.
    static func isPrefermentReferenceLine(_ line: String) -> Bool {
        guard resolveIngredientLine(line) == nil else { return false }
        let cleaned = cleanIngredientLine(line)
        let pattern = #"(?i)^(?:all\s+(?:of\s+)?|the\s+|your\s+)*"#
            + prefermentNounPattern
            + #"(?:\s+(?:from\s+(?:above|step\s*\d+)|you\s+made(?:\s+(?:earlier|above))?))?\s*[.,!]?$"#
        return cleaned.range(of: pattern, options: .regularExpression) != nil
    }

    static func backReferenceLines(in ingredientLines: [String]) -> Set<String> {
        Set(ingredientLines.filter(isPrefermentReferenceLine))
    }

    /// Fallback preferment detection for sites whose structured data is a flat ingredient
    /// list with no HTML grouping we can key off of: everything before a back-reference
    /// line like "all of the poolish" is assumed to be the preferment.
    static func prefermentLines(fromBackReferenceIn ingredientLines: [String]) -> PrefermentLines? {
        guard let markerIndex = ingredientLines.firstIndex(where: isPrefermentReferenceLine) else {
            return nil
        }
        let cleanedMarker = cleanIngredientLine(ingredientLines[markerIndex])
        guard let nounRange = cleanedMarker.range(of: prefermentNounPattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let memberLines = Set(ingredientLines[..<markerIndex])
        guard !memberLines.isEmpty else { return nil }
        return PrefermentLines(name: String(cleanedMarker[nounRange]).capitalized, lines: memberLines)
    }

    /// Preferment detection from the site's own rendered HTML: many recipe sites (e.g.
    /// King Arthur) group ingredients under a short heading immediately before a `<ul>`/
    /// `<ol>` list, even though that grouping has no equivalent in the JSON-LD they publish.
    /// Only trusted when the extracted `<li>` items can be matched back to the flat
    /// `ingredientLines` (allowing for whitespace differences introduced by stripping
    /// embedded links, e.g. King Arthur's product links) - otherwise falls through to the
    /// plain-text heuristic.
    static func prefermentLines(fromHTML html: String, ingredientLines: [String]) -> PrefermentLines? {
        let headingPattern = #"<(p|h[2-6]|strong|span)[^>]*>\s*("# + prefermentNounPattern + #")\s*</\1>"#
        guard let headingRegex = try? NSRegularExpression(pattern: headingPattern, options: [.caseInsensitive]) else {
            return nil
        }
        let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let headingMatch = headingRegex.firstMatch(in: html, range: fullRange),
              let nounRange = Range(headingMatch.range(at: 2), in: html) else {
            return nil
        }
        let noun = String(html[nounRange])

        let searchStart = headingMatch.range.location + headingMatch.range.length
        let windowLength = min(4000, (html as NSString).length - searchStart)
        guard windowLength > 0,
              let windowRange = Range(NSRange(location: searchStart, length: windowLength), in: html) else {
            return nil
        }
        let window = String(html[windowRange])

        guard let listRegex = try? NSRegularExpression(pattern: #"<(ul|ol)[^>]*>(.*?)</\1>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let listMatch = listRegex.firstMatch(in: window, range: NSRange(window.startIndex..<window.endIndex, in: window)),
              let listContentRange = Range(listMatch.range(at: 2), in: window) else {
            return nil
        }
        let listContent = String(window[listContentRange])

        guard let itemRegex = try? NSRegularExpression(pattern: #"<li[^>]*>(.*?)</li>"#, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let itemRange = NSRange(listContent.startIndex..<listContent.endIndex, in: listContent)
        let items = itemRegex.matches(in: listContent, range: itemRange).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: listContent) else { return nil }
            return cleanText(String(listContent[range]))
        }

        let normalizedToOriginal = Dictionary(
            ingredientLines.map { (matchingKey(for: $0), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let memberLines = Set(items.compactMap { normalizedToOriginal[matchingKey(for: $0)] })
        guard !memberLines.isEmpty else { return nil }
        return PrefermentLines(name: noun.capitalized, lines: memberLines)
    }

    /// Normalizes text for matching an HTML-extracted `<li>` against a JSON-LD ingredient
    /// line: stripping an embedded link (e.g. King Arthur's product links) can leave a
    /// stray space before trailing punctuation ("...Flour *" vs "...Flour*") that would
    /// otherwise make an identical ingredient fail an exact-string match.
    static func matchingKey(for text: String) -> String {
        text.replacingOccurrences(of: #"\s+(?=[*.,;:!?)])"#, with: "", options: .regularExpression)
            .lowercased()
    }

    // MARK: - Microdata fallback

    /// Fallback for pages with no usable JSON-LD that mark their recipe up with
    /// microdata attributes (`itemtype=".../Recipe"` + `itemprop="recipeIngredient"`),
    /// common on older blogs and WordPress recipe plugins. Synthesizes the same
    /// dictionary shape `parse` expects from JSON-LD, so splitting, cleaning, and
    /// resolution stay shared. Values are raw inner HTML; `parse` cleans them.
    static func microdataRecipeObject(in html: String) -> [String: Any]? {
        guard let scopeTag = html.range(of: #"<[^>]*\bitemtype\s*=\s*["'][^"']*schema\.org/Recipe\b[^"']*["'][^>]*>"#,
                                        options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let scope = String(html[scopeTag.upperBound...])

        // "ingredients" is the legacy (data-vocabulary/early schema.org) property name.
        let ingredients = microdataValues(forProperties: "recipeIngredient|ingredients", in: scope)
        guard !ingredients.isEmpty else { return nil }

        var object: [String: Any] = [
            "@type": "Recipe",
            "recipeIngredient": ingredients,
        ]
        if let name = microdataValues(forProperties: "name", in: scope).first {
            object["name"] = name
        }
        let instructions = microdataValues(forProperties: "recipeInstructions", in: scope)
        if !instructions.isEmpty {
            object["recipeInstructions"] = instructions
        }
        return object
    }

    /// Collects the values of every element in `scope` whose `itemprop` matches
    /// `propertyPattern` (a regex alternation): a `content` attribute when present
    /// (meta-style tags), otherwise the element's inner HTML found by balanced-tag
    /// scanning — recipe plugins routinely nest `<span>`s inside an ingredient
    /// `<span>`, which a lazy `.*?</tag>` match would truncate at the first close.
    static func microdataValues(forProperties propertyPattern: String, in scope: String) -> [String] {
        let tagPattern = "<(\\w+)[^>]*\\bitemprop\\s*=\\s*[\"'](?:" + propertyPattern + ")[\"'][^>]*>"
        guard let regex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive]) else {
            return []
        }
        let voidTags: Set<String> = ["meta", "link", "img", "br", "input", "hr"]
        let nsRange = NSRange(scope.startIndex..<scope.endIndex, in: scope)

        var values: [String] = []
        for match in regex.matches(in: scope, range: nsRange) {
            guard let tagRange = Range(match.range, in: scope),
                  let nameRange = Range(match.range(at: 1), in: scope) else { continue }
            let tagText = String(scope[tagRange])
            let tagName = String(scope[nameRange]).lowercased()

            if let content = firstCaptureGroup(#"\bcontent\s*=\s*["']([^"']*)["']"#, in: tagText),
               !content.isEmpty {
                values.append(content)
            } else if !voidTags.contains(tagName),
                      let inner = balancedInnerHTML(tagName: tagName, after: tagRange.upperBound, in: scope) {
                values.append(inner)
            }
        }
        return values
    }

    /// The inner HTML of an element whose opening tag ends at `start`, found by
    /// scanning forward and depth-counting same-named open/close tags.
    static func balancedInnerHTML(tagName: String, after start: String.Index, in scope: String) -> String? {
        let pattern = "</?" + NSRegularExpression.escapedPattern(for: tagName) + "\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        var depth = 1
        for match in regex.matches(in: scope, range: NSRange(start..<scope.endIndex, in: scope)) {
            guard let range = Range(match.range, in: scope) else { continue }
            if scope[range].hasPrefix("</") {
                depth -= 1
                if depth == 0 {
                    return String(scope[start..<range.lowerBound])
                }
            } else {
                depth += 1
            }
        }
        return nil
    }

    static func firstCaptureGroup(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

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

    static func prettyJSONString(from object: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
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
            return splitHTMLLineBlocks(string)
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
            return splitHTMLLineBlocks(text)
        }
        if let name = dict["name"] as? String {
            return splitHTMLLineBlocks(name)
        }
        return []
    }

    /// Splits a JSON-LD string on line-break-ish HTML (`<br>`, `</p>`, `</li>`, …) and
    /// literal newlines, cleaning each piece. Some sites publish recipeIngredient or
    /// recipeInstructions as one HTML blob instead of an array; a normal single-value
    /// string passes through as one piece.
    static func splitHTMLLineBlocks(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: #"<br\s*/?\s*>|</(?:p|li|br|div|h\d)>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
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
            "&deg;": "°",
            "&frac14;": "¼",
            "&frac12;": "½",
            "&frac34;": "¾",
            "&frac13;": "⅓",
            "&frac23;": "⅔",
            "&frac18;": "⅛",
            "&frac38;": "⅜",
            "&frac58;": "⅝",
            "&frac78;": "⅞",
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
        let cleaned = strippedSecondaryAmounts(cleanIngredientLine(line))
        guard !cleaned.isEmpty else { return nil }

        let lower = cleaned.lowercased()
        let name = stripBrandingAndMarketing(from: ingredientName(from: cleaned))
        guard !name.isEmpty else { return nil }

        let category = ExtraIngredientConversion.ingredientCategory(forName: name)
        let isFlour = isFlourName(name, category: category)

        if lower.contains("yeast"),
           (lower.contains("package") || lower.contains("packet")),
           firstMeasurement(in: cleaned, units: [.gram, .kilogram, .ounce, .pound]) == nil {
            // "2 packages active dry yeast" — the leading amount is the package count.
            let packages = leadingAmount(in: cleaned).flatMap { $0 > 0 ? $0 : nil } ?? 1
            return WebsiteResolvedIngredient(originalLine: line, name: name, weightGrams: 7 * packages, isFlour: false, isExtra: false, extraAmount: 0, extraUnit: "count")
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

        // Fluid ounces are a volume, not the mass "ounce" — the weight check above
        // can't match them anyway ("fl" sits between the amount and "oz").
        guard let volume = firstMeasurement(in: cleaned, units: [.teaspoon, .tablespoon, .cup, .fluidOunce, .milliliter, .deciliter, .liter]) else {
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

    /// The amount at the very start of a line ("2 packages …" -> 2), or `nil`.
    static func leadingAmount(in text: String) -> Double? {
        guard let range = text.range(of: #"^\s*"# + amountPattern, options: .regularExpression) else {
            return nil
        }
        return parseAmountRange(String(text[range]))
    }

    static func ingredientName(from line: String) -> String {
        var working = cleanIngredientLine(line)
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: measurementRemovalPattern(excludingEggs: true), with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"(?i)^\s*(?:one|about|approximately|approx\.?|plus|minus|of|the|for|or|and|scant)\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*(?:(?:\d+/\d+)|(?:\d+(?:[.,]\d+)?(?:\s+\d+/\d+|\s*[¼½¾⅓⅔⅛⅜⅝⅞])?)|[¼½¾⅓⅔⅛⅜⅝⅞])\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)^\s*(?:packages?|packets?)\s+(?:of\s+)?"#, with: "", options: .regularExpression)

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
            // "." included for unit-dot residue: stripping "4 fl. oz." backtracks
            // off the final dot (the pattern ends \b), leaving ". water".
            .trimmingCharacters(in: CharacterSet(charactersIn: " -/,.\t\n"))

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
            ? #"(?:g|grams?|kg|kilograms?|ml|milliliters?|dl|deciliters?|decilitres?|l|liters?|litres?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|fl\.?\s*oz\.?|fluid\s+ounces?|ounces?|oz\.?|pounds?|lbs?\.?)"#
            : #"(?:g|grams?|kg|kilograms?|ml|milliliters?|dl|deciliters?|decilitres?|l|liters?|litres?|cups?|c\.|tablespoons?|tbsp\.?|teaspoons?|tsp\.?|fl\.?\s*oz\.?|fluid\s+ounces?|ounces?|oz\.?|pounds?|lbs?\.?|eggs?|egg\s+whites?|egg\s+yolks?)"#
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
        let pattern = #"(?<![0-9A-Za-z])"# + amount + #"(?:\s*(?:to|[-–—])\s*"# + amount + #")?\s*(?:small|medium|large|extra-large|extra\s+large|jumbo)?\s*(?:eggs?|egg\s+whites?|egg\s+yolks?|whites?|yolks?)\b"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        return parseAmountRange(String(text[range]))
    }

    static func firstCountMeasurement(in text: String) -> Double? {
        let amount = amountPattern
        let pattern = #"(?<![0-9A-Za-z])"# + amount + #"(?:\s*(?:to|[-–—])\s*"# + amount + #")?\s+(?:oranges?|lemons?|limes?|cloves?|(?:[a-z]+\s+)?leaves)\b"#
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
        case .fluidOunce: unitPattern = #"(?:fl\.?\s*oz\.?|fluid\s+ounces?)"#
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
        // (?<![0-9A-Za-z]) instead of \b: a line can start with a Unicode vulgar
        // fraction ("½ cup olive oil"), and \b never matches before a non-word char.
        return #"(?<![0-9A-Za-z])"# + amountPattern + #"(?:\s*(?:to|[-–—])\s*"# + amountPattern + #")?\s*-?\s*"# + unitPattern + #"\b"#
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

    /// "1,000 grams" uses a thousands comma but European recipes write decimals with a
    /// comma ("1,5 dl"). Exactly one or two digits after the comma means decimal;
    /// anything else is treated as a thousands separator and dropped.
    static func normalizedDecimalSeparators(_ raw: String) -> String {
        if raw.range(of: #"^\d+,\d{1,2}$"#, options: .regularExpression) != nil {
            return raw.replacingOccurrences(of: ",", with: ".")
        }
        return raw.replacingOccurrences(of: ",", with: "")
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
