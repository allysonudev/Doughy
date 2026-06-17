//
//  CalculatorOverrides.swift
//  Doughy
//

import Foundation

/// Bundles the calculator's "Adjust" overrides so they can be carried from
/// `CalculatorView` to `CalculatedRecipeView` for the "Set as Default" and
/// "+ Add Note" features. Preferment ingredient temperature overrides reuse
/// `ingredientTemps` keyed at `1000 + index`, matching `CalculatorView`.
struct CalculatorOverrides {
    let ingredientPercents: [Int: Double]
    let ingredientWeights: [Int: Double]
    let ingredientTemps: [Int: Double]
    let prefermentIngredientPercents: [Int: Double]
    let prefermentIngredientWeights: [Int: Double]
    let prefermentTotalPercent: Double?
    let singleDoughWeight: Double?
    let extraIngredientAmounts: [Int: Double]
    let temperatureMeasurement: Temperature.Measurement

    /// Whether the user set any "Adjust" value, regardless of whether it
    /// differs numerically from the recipe's current default.
    var hasAnyOverride: Bool {
        !ingredientPercents.isEmpty || !ingredientWeights.isEmpty || !ingredientTemps.isEmpty
            || !prefermentIngredientPercents.isEmpty || !prefermentIngredientWeights.isEmpty
            || prefermentTotalPercent != nil || singleDoughWeight != nil
            || !extraIngredientAmounts.isEmpty
    }

    /// Applies these overrides on top of `recipe`'s current values, producing
    /// the snapshot "Set as Default" would persist.
    func applied(to recipe: any RecipeProtocol) -> RecipeSnapshot {
        var snapshot = RecipeSnapshot(from: recipe)

        if let weight = singleDoughWeight {
            snapshot.defaultWeight = weight
        }

        for (index, percent) in ingredientPercents where snapshot.ingredients.indices.contains(index) {
            snapshot.ingredients[index].defaultPercentage = percent
        }
        for (index, weight) in ingredientWeights where snapshot.ingredients.indices.contains(index) {
            snapshot.ingredients[index].defaultWeight = weight
        }
        for (index, temp) in ingredientTemps where snapshot.ingredients.indices.contains(index) {
            snapshot.ingredients[index].temperatureValue = temp
            snapshot.ingredients[index].temperatureMeasurement = temperatureMeasurement.rawValue
        }
        for (index, amount) in extraIngredientAmounts where snapshot.ingredients.indices.contains(index) {
            snapshot.ingredients[index].extraAmount = amount
        }

        if var preferment = snapshot.preferment {
            if let totalPercent = prefermentTotalPercent {
                preferment.flourPercentage = totalPercent
            }
            for (index, percent) in prefermentIngredientPercents where preferment.ingredients.indices.contains(index) {
                preferment.ingredients[index].defaultPercentage = percent
            }
            for (index, weight) in prefermentIngredientWeights where preferment.ingredients.indices.contains(index) {
                preferment.ingredients[index].defaultWeight = weight
            }
            for (key, temp) in ingredientTemps where key >= 1000 {
                let index = key - 1000
                guard preferment.ingredients.indices.contains(index) else { continue }
                preferment.ingredients[index].temperatureValue = temp
                preferment.ingredients[index].temperatureMeasurement = temperatureMeasurement.rawValue
            }
            snapshot.preferment = preferment
        }

        if snapshot.measurementMode == .weight {
            let sum = snapshot.ingredients
                .filter { $0.extraAmount == nil }
                .compactMap(\.defaultWeight)
                .reduce(0, +)
            if sum > 0 {
                snapshot.defaultWeight = sum
            }
        }

        return snapshot
    }
}
