//
//  RecipeDiff.swift
//  Doughy
//

import Foundation

/// Generates human-readable diff summaries between two `RecipeSnapshot`s, for
/// the Recipe History feature: edit-triggered version entries, "Set as
/// Default" confirmations, and note pre-fills.
enum RecipeDiff {

    private static let percentFormatter = PercentFormatter.shared
    private static let weightFormatter = WeightFormatter.shared
    private static let epsilon = 0.0001

    /// Returns `nil` if there's no meaningful difference between `old` and `new`.
    static func summarize(from old: RecipeSnapshot, to new: RecipeSnapshot) -> String? {
        var lines: [String] = []

        let weightMode = old.measurementMode == .weight || new.measurementMode == .weight
        lines.append(contentsOf: ingredientLines(from: old.ingredients, to: new.ingredients, prefix: "", weightMode: weightMode))

        switch (old.preferment, new.preferment) {
        case (let old?, let new?):
            if differs(old.flourPercentage, new.flourPercentage) {
                lines.append("\(new.name) flour: \(percentFormatter.format(percent: old.flourPercentage)) \u{2192} \(percentFormatter.format(percent: new.flourPercentage))")
            }
            lines.append(contentsOf: ingredientLines(from: old.ingredients, to: new.ingredients, prefix: "\(new.name) ", weightMode: weightMode))
        case (nil, .some):
            lines.append("+ Added preferment")
        case (.some, nil):
            lines.append("- Removed preferment")
        case (nil, nil):
            break
        }

        if differs(old.defaultWeight, new.defaultWeight) {
            lines.append("Weight: \(weightFormatter.format(weight: old.defaultWeight)) \u{2192} \(weightFormatter.format(weight: new.defaultWeight))")
        }

        if old.instructions != new.instructions {
            lines.append("Instructions updated")
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private static func ingredientLines(from old: [IngredientSnapshot], to new: [IngredientSnapshot], prefix: String, weightMode: Bool) -> [String] {
        var lines: [String] = []
        let newByName = Dictionary(uniqueKeysWithValues: new.map { ($0.name.lowercased(), $0) })
        let oldByName = Dictionary(uniqueKeysWithValues: old.map { ($0.name.lowercased(), $0) })

        for ingredient in old {
            guard let match = newByName[ingredient.name.lowercased()] else {
                lines.append("- Removed \(prefix)\(ingredient.name)")
                continue
            }
            if weightMode && differs(ingredient.defaultWeight ?? 0, match.defaultWeight ?? 0) {
                lines.append("\(prefix)\(ingredient.name): \(weightFormatter.format(weight: ingredient.defaultWeight ?? 0)) \u{2192} \(weightFormatter.format(weight: match.defaultWeight ?? 0))")
            } else if differs(ingredient.defaultPercentage, match.defaultPercentage) {
                lines.append("\(prefix)\(ingredient.name): \(percentFormatter.format(percent: ingredient.defaultPercentage)) \u{2192} \(percentFormatter.format(percent: match.defaultPercentage))")
            }
            if let oldLine = temperatureLine(prefix: prefix, ingredient: ingredient, other: match) {
                lines.append(oldLine)
            }
        }
        for ingredient in new where oldByName[ingredient.name.lowercased()] == nil {
            lines.append("+ Added \(prefix)\(ingredient.name)")
        }
        return lines
    }

    private static func temperatureLine(prefix: String, ingredient: IngredientSnapshot, other: IngredientSnapshot) -> String? {
        guard let oldValue = ingredient.temperatureValue, let oldMeasurementRaw = ingredient.temperatureMeasurement,
              let oldMeasurement = Temperature.Measurement(rawValue: oldMeasurementRaw),
              let newValue = other.temperatureValue, let newMeasurementRaw = other.temperatureMeasurement,
              let newMeasurement = Temperature.Measurement(rawValue: newMeasurementRaw) else {
            return nil
        }
        guard differs(oldValue, newValue) || oldMeasurement != newMeasurement else { return nil }

        let oldFormatted = TemperatureFormatter.shared.format(temperature: Temperature(value: oldValue, measurement: oldMeasurement))
        let newFormatted = TemperatureFormatter.shared.format(temperature: Temperature(value: newValue, measurement: newMeasurement))
        return "\(prefix)\(ingredient.name) temp: \(oldFormatted) \u{2192} \(newFormatted)"
    }

    private static func differs(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) > epsilon
    }
}
