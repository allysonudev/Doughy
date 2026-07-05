//
//  CalculatorView+UnitCycling.swift
//  Doughy
//

import SwiftUI

extension CalculatorView {
    // MARK: - Volume unit cycling

    /// Resolves an ingredient name to a density category. Prefers an exact match against
    /// `IngredientCategory.displayName` (reliable for stored recipe ingredients) and falls back to
    /// keyword matching for partial or variant names from scanning.
    func densityCategory(for lowerName: String) -> IngredientCategory? {
        IngredientCategory.allCases.first { $0.displayName.lowercased() == lowerName }
            ?? ExtraIngredientConversion.ingredientCategory(forName: lowerName)
    }

    func systemPrimary(for category: IngredientCategory, system: VolumeSystem) -> DensityUnit {
        DensityUnit.systemDefault(for: category.defaultDisplayUnit, in: system)
    }

    /// Returns the ordered list of units available for `name` at `grams`, starting with "grams".
    /// Units whose converted amount falls outside a practical range are skipped. Returns `nil`
    /// when no volume conversion exists for the ingredient.
    func cycleUnits(for name: String, grams: Double) -> [String]? {
        var units: [String] = ["grams"]
        let lowerName = name.lowercased()

        if let category = densityCategory(for: lowerName) {
            let gramsPerCup = densityStore.gramsPerCup(for: category)
            let system = Settings.shared.preferredVolumeSystem()
            let primary = systemPrimary(for: category, system: system)
            let systemUnits: [DensityUnit]
            switch system {
            case .imperial: systemUnits = [.cup, .fluidOunce, .tablespoon, .teaspoon]
            case .metric:   systemUnits = [.deciliter, .liter, .milliliter]
            }
            // Primary is always shown; remaining system units are filtered to practical ranges.
            let volumeUnits: [DensityUnit] = [primary] + systemUnits.filter { $0 != primary }
            let secondaryLimits: [DensityUnit: (min: Double, max: Double)] = [
                .cup: (0.0625, 20), .fluidOunce: (0.25, 40),
                .tablespoon: (0.0625, 32), .teaspoon: (0.0625, 48),
                .deciliter: (0.5, 50), .liter: (0.05, 10), .milliliter: (5, 1000),
            ]
            for unit in volumeUnits {
                let amount = grams / (gramsPerCup / unit.unitsPerCup)
                if unit == primary || secondaryLimits[unit].map({ amount >= $0.min && amount <= $0.max }) == true {
                    units.append(unit.rawValue)
                }
            }
        }

        // User-saved conversions for this ingredient name.
        for entry in conversionStore.allEntries() where entry.name.lowercased() == lowerName && !units.contains(entry.unit) {
            units.append(entry.unit)
        }

        return units.count > 1 ? units : nil
    }

    func advanceUnit(key: String, name: String, grams: Double) {
        guard let units = cycleUnits(for: name, grams: grams) else { return }
        let current = ingredientDisplayUnits[key] ?? "grams"
        let idx = units.firstIndex(of: current) ?? 0
        ingredientDisplayUnits[key] = units[(idx + 1) % units.count]
    }

    /// Formats `grams` expressed in `unit` for the named ingredient.
    func weightDisplay(grams: Double, unit: String, for name: String) -> String {
        guard unit != "grams" else { return weightFormatter.format(weight: grams) }
        let lowerName = name.lowercased()
        let gramsPerUnit: Double
        if let densityUnit = DensityUnit(rawValue: unit),
           let category = densityCategory(for: lowerName) {
            let gramsPerCup = densityStore.gramsPerCup(for: category)
            gramsPerUnit = gramsPerCup / densityUnit.unitsPerCup
        } else if let g = conversionStore.gramsPerUnit(name: lowerName, unit: unit) {
            gramsPerUnit = g
        } else {
            return weightFormatter.format(weight: grams)
        }
        let amount = grams / gramsPerUnit
        let (formatted, snapped) = formatVolumeAmount(amount)
        let prefix = abs(amount - snapped) > 0.001 ? "~" : ""
        return prefix + formatted + " " + VolumeUnitFormatter.label(unit: unit, amount: snapped <= 1.0 ? 1.0 : 2.0)
    }

    /// Formats a volume amount using baker-friendly fractions (1/8 resolution + 1/3, 2/3). Returns
    /// both the display string and the snapped numeric value so callers can base pluralization on
    /// the displayed quantity. Values below 1/8 are shown as decimals to avoid snapping to "0".
    func formatVolumeAmount(_ value: Double) -> (display: String, snapped: Double) {
        if value >= 10 {
            return (value.formatted(.number.precision(.fractionLength(0...1))), value)
        }
        if value < 0.125 {
            return (value.formatted(.number.precision(.fractionLength(2...2))), value)
        }
        let whole = Int(value)
        let frac = value - Double(whole)
        let candidates: [(Double, String)] = [
            (0, ""), (1/8, "1/8"), (1/4, "1/4"), (1/3, "1/3"),
            (3/8, "3/8"), (1/2, "1/2"), (5/8, "5/8"), (2/3, "2/3"),
            (3/4, "3/4"), (7/8, "7/8"), (1, "")
        ]
        guard let (nearVal, nearLabel) = candidates.min(by: { abs($0.0 - frac) < abs($1.0 - frac) }) else {
            return (value.formatted(.number.precision(.fractionLength(0...2))), value)
        }
        let adjustedWhole = nearVal == 1 ? whole + 1 : whole
        let snapped = Double(adjustedWhole) + (nearVal == 1 ? 0 : nearVal)
        let display: String
        if nearLabel.isEmpty {
            display = "\(adjustedWhole)"
        } else {
            display = adjustedWhole == 0 ? nearLabel : "\(adjustedWhole) \(nearLabel)"
        }
        return (display, snapped)
    }

}
