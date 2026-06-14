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
        default:           return unit
        }
    }

    static func format(amount: Double, unit: String) -> String {
        let amountString: String
        if amount == amount.rounded() {
            amountString = String(Int(amount))
        } else {
            amountString = String(format: "%.2g", amount)
        }
        return "\(amountString) \(label(unit: unit, amount: amount))"
    }
}
