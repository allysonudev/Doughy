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
        case "teaspoon", "tablespoon", "cup", "ounce":
            return plural ? pickerLabel(unit: unit).lowercased() : singularLabel(unit: unit)
        case "milliliter": return String(localized: "unit.volume.milliliter", defaultValue: "ml")
        case "deciliter":  return String(localized: "unit.volume.deciliter", defaultValue: "dl")
        case "liter":      return String(localized: "unit.volume.liter", defaultValue: "l")
        case "count":      return ""
        default:           return unit
        }
    }

    /// A display name for `unit` suitable for menus/pickers, where `label`'s
    /// empty string for `"count"` would otherwise be confusing.
    static func menuName(unit: String) -> String {
        unit == "count" ? String(localized: "unit.count", defaultValue: "Count") : label(unit: unit, amount: 2)
    }

    /// A properly capitalized display name for unit pickers. Metric symbols
    /// (ml, dl, l) are not capitalized; imperial names are title-cased.
    static func pickerLabel(unit: String) -> String {
        switch unit {
        case "teaspoon":   return String(localized: "unit.volume.teaspoon", defaultValue: "Teaspoons")
        case "tablespoon": return String(localized: "unit.volume.tablespoon", defaultValue: "Tablespoons")
        case "cup":        return String(localized: "unit.volume.cup", defaultValue: "Cups")
        case "ounce":      return String(localized: "unit.volume.ounce", defaultValue: "Ounces")
        case "milliliter": return String(localized: "unit.volume.milliliter", defaultValue: "ml")
        case "deciliter":  return String(localized: "unit.volume.deciliter", defaultValue: "dl")
        case "liter":      return String(localized: "unit.volume.liter", defaultValue: "l")
        case "count":      return String(localized: "unit.count", defaultValue: "Count")
        default:           return label(unit: unit, amount: 2).capitalized
        }
    }

    /// Singular localized unit label (e.g. "tablespoon" / "ملعقة كبيرة").
    static func singularLabel(unit: String) -> String {
        switch unit {
        case "teaspoon":   return String(localized: "unit.volume.teaspoon.one", defaultValue: "teaspoon")
        case "tablespoon": return String(localized: "unit.volume.tablespoon.one", defaultValue: "tablespoon")
        case "cup":        return String(localized: "unit.volume.cup.one", defaultValue: "cup")
        case "ounce":      return String(localized: "unit.volume.ounce.one", defaultValue: "ounce")
        default:           return pickerLabel(unit: unit)
        }
    }

    /// Like `format(amount:unit:)` but uses localized unit names.
    static func localizedFormat(amount: Double, unit: String) -> String {
        if unit == "count" {
            return String(Int(amount.rounded()))
        }
        let amountString: String
        let displayAmount: Double
        if amount == amount.rounded() {
            amountString = String(Int(amount))
            displayAmount = amount
        } else {
            amountString = String(format: "%.2g", amount)
            displayAmount = Double(amountString) ?? amount
        }
        let plural = abs(displayAmount - 1) > 0.0001
        let unitLabel = plural ? pickerLabel(unit: unit).lowercased() : singularLabel(unit: unit)
        return "\(amountString) \(unitLabel)"
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
