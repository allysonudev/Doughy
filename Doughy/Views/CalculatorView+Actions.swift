//
//  CalculatorView+Actions.swift
//  Doughy
//

import SwiftUI

extension CalculatorView {
    // MARK: - Actions

    func loadSharedNote() {
        let entries = store.historyEntries(for: currentRecipe)
        sharedBy = entries
            .first { $0.kind == .note && $0.text.hasPrefix("Shared by ") }
            .map { String($0.text.dropFirst("Shared by ".count)) }
        sharedNote = entries
            .first { $0.kind == .note && $0.text.hasPrefix("Share note: ") }
            .map { String($0.text.dropFirst("Share note: ".count)) }
        if let saved = UserDefaults.standard.object(forKey: noteExpandedKey) as? Bool {
            noteExpanded = saved
        }
    }

    func handleRecipeEditSaved(_ recipe: any RecipeProtocol) {
        activeRecipeName = recipe.name
        activeRecipeCollection = recipe.collection
        store.refresh()
        resetSessionAfterRecipeChange()
    }

    func resetSessionAfterRecipeChange() {
        ingredientPercents = [:]
        extraIngredientAmounts = [:]
        ingredientTemps = [:]
        prefermentIngredientPercents = [:]
        ingredientWeights = [:]
        prefermentIngredientWeights = [:]
        prefermentTotalPercent = nil
        ingredientDisplayUnits = [:]
        ingredientsExpanded = false
        ingredientsDragOffset = 0
        ingredientsVisible = true
        loadSharedNote()
        calculateAndRefreshTweakText()
    }

    func saveNote() {
        let text = combinedNoteText
        guard !text.isEmpty else { return }
        do {
            try store.addNote(text, to: currentRecipe)
            lastSavedNoteText = text
        } catch {
            actionError = String(localized: "calculated.error.save_note", defaultValue: "Could not save this note.")
        }
    }

    /// Undoes a preferment added earlier this session, or - for the recipe's
    /// actual stored preferment - marks it removed for this session. Either
    /// way nothing is written until "Set as Default".
    func removePreferment() {
        if pendingPreferment != nil {
            pendingPreferment = nil
            pendingRemovedYeastName = nil
        } else {
            prefermentRemoved = true
        }
        resetPrefermentSessionOverrides()
    }

    /// Clears preferment-ingredient overrides, whose indices point into
    /// whichever preferment array was on screen when they were set - stale
    /// once that preferment is replaced or removed this session.
    func resetPrefermentSessionOverrides() {
        prefermentIngredientPercents = [:]
        prefermentIngredientWeights = [:]
        prefermentTotalPercent = nil
        calculateAndRefreshTweakText()
    }

    func setAsDefault() {
        do {
            try store.setAsDefault(recipe: currentRecipe, overrides: currentOverrides())
            tweakText = ""
            store.refresh()
        } catch {
            actionError = String(localized: "calculated.error.set_default", defaultValue: "Could not update this recipe's default values.")
        }
    }

    func calculateAndRefreshTweakText() {
        calculate()
        tweakText = overrideDiff ?? ""
    }

    func calculate() {
        let ingredients = buildMeasuredIngredients()
        let preferment = buildMeasuredPreferment()

        do {
            calculatedRecipe = try calculator.calculate(
                ingredients: ingredients,
                preferment: preferment,
                recipe: currentRecipe,
                totalWeight: totalWeight
            )
            calculationError = nil
        } catch CalculationError.finalDoughNegativeValue(let name, let value) {
            calculatedRecipe = nil
            calculationError = String(
                format: String(localized: "calculator.error.final_dough_negative", defaultValue: "Calculated final dough %@ weight is %@. Please adjust input."),
                name,
                weightFormatter.format(weight: value)
            )
        } catch CalculationError.prefermentNegativeValue(let name, let value) {
            calculatedRecipe = nil
            calculationError = String(
                format: String(localized: "calculator.error.preferment_negative", defaultValue: "Calculated preferment %@ weight is %@. Please adjust input."),
                name,
                weightFormatter.format(weight: value)
            )
        } catch {
            calculatedRecipe = nil
            calculationError = String(localized: "calculator.error.unexpected", defaultValue: "An unexpected calculation error occurred.")
        }
    }

    func currentOverrides() -> CalculatorOverrides {
        CalculatorOverrides(
            ingredientPercents: ingredientPercents,
            ingredientWeights: ingredientWeights,
            ingredientTemps: ingredientTemps,
            prefermentIngredientPercents: prefermentIngredientPercents,
            prefermentIngredientWeights: prefermentIngredientWeights,
            prefermentTotalPercent: prefermentTotalPercent,
            singleDoughWeight: singleDoughWeight,
            extraIngredientAmounts: extraIngredientAmounts,
            temperatureMeasurement: settings.preferredTemp(),
            pendingPreferment: pendingPreferment,
            pendingRemovedYeastName: pendingRemovedYeastName,
            prefermentRemoved: prefermentRemoved
        )
    }

    func buildMeasuredIngredients() -> [MeasuredIngredient] {
        currentRecipe.ingredients.enumerated().compactMap { index, ingredient in
            if let pendingRemovedYeastName, ingredient.name == pendingRemovedYeastName { return nil }
            let percent = ingredientPercents[index] ?? ingredient.defaultPercentage
            var temp = ingredient.temperature
            if let rawTemp = ingredientTemps[index] {
                temp = Temperature(value: rawTemp, measurement: settings.preferredTemp())
            }
            return MeasuredIngredient(
                ingredient: ingredient,
                percent: percent,
                temperature: temp,
                weight: ingredientWeights[index] ?? ingredient.defaultWeight,
                extraAmountOverride: extraIngredientAmounts[index]
            )
        }
    }

    func buildMeasuredPreferment() -> MeasuredPreferment? {
        guard let effectivePreferment else { return nil }
        let fermentPercent = prefermentTotalPercent ?? effectivePreferment.flourPercentage
        let fermentIngredients = effectivePreferment.ingredients.enumerated().map { index, ingredient in
            let percent = prefermentIngredientPercents[index] ?? ingredient.defaultPercentage
            var temp = ingredient.temperature
            if let rawTemp = ingredientTemps[1000 + index] {
                temp = Temperature(value: rawTemp, measurement: settings.preferredTemp())
            }
            return MeasuredIngredient(
                ingredient: ingredient,
                percent: percent,
                temperature: temp,
                weight: prefermentIngredientWeights[index] ?? ingredient.defaultWeight
            )
        }
        return MeasuredPreferment(ingredients: fermentIngredients, name: effectivePreferment.name, flourPercentage: fermentPercent)
    }
}
