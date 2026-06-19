//
//  VolumeUnitFormatter.swift
//  Doughy
//

import Foundation

/// Formats "extra" ingredient quantities (e.g. "2 tablespoons") for unit strings like
/// "teaspoon"/"tablespoon"/"cup", as stored on `Ingredient.extraUnit`.
enum VolumeUnitFormatter {
    static func label(unit: String, amount: Double) -> String {
        let plural = abs(amount - 1) > 0.0001
        switch unit {
        case "teaspoon":   return plural ? "teaspoons" : "teaspoon"
        case "tablespoon": return plural ? "tablespoons" : "tablespoon"
        case "cup":        return plural ? "cups" : "cup"
        case "ounce":      return plural ? "ounces" : "ounce"
        case "milliliter": return "ml"
        case "deciliter":  return "dl"
        case "liter":      return "l"
        case "count":      return ""
        default:           return unit
        }
    }

    /// A display name for `unit` suitable for menus/pickers, where `label`'s
    /// empty string for `"count"` would otherwise be confusing.
    static func menuName(unit: String) -> String {
        unit == "count" ? String(localized: "unit.count", defaultValue: "Count") : label(unit: unit, amount: 2)
    }

    static func format(amount: Double, unit: String) -> String {
        let amountString: String
        let displayAmount: Double
        if amount == amount.rounded() {
            amountString = String(Int(amount))
            displayAmount = amount
        } else {
            amountString = String(format: "%.2g", amount)
            // Use the rounded display value for pluralization so "1.004" shown as "1" is singular.
            displayAmount = Double(amountString) ?? amount
        }
        let unitLabel = label(unit: unit, amount: displayAmount)
        return unitLabel.isEmpty ? amountString : "\(amountString) \(unitLabel)"
    }
}
