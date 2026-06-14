//
//  CalculatorView.swift
//  Doughy

import SwiftUI

struct CalculatorView: View {
    let recipe: any RecipeProtocol
    @Environment(RecipeStore.self) private var store

    @State private var doughCount: Int?
    @State private var singleDoughWeight: Double?
    @State private var adjustIngredients = false
    @State private var adjustTemps = false
    @State private var adjustPreferment = false
    @State private var ingredientPercents: [Int: Double] = [:]
    @State private var extraIngredientAmounts: [Int: Double] = [:]
    @State private var ingredientTemps: [Int: Double] = [:]
    @State private var prefermentIngredientPercents: [Int: Double] = [:]
    @State private var prefermentTotalPercent: Double?
    @State private var calculatedResult: CalculatedWrapper?
    @State private var calculationError: String?
    @State private var showingEdit = false

    private let calculator = Calculator.shared
    private let settings = Settings.shared
    private let weightFormatter = WeightFormatter.shared

    /// The recipe as currently stored, looked up from `store.collections` so
    /// edits made elsewhere (e.g. "Set as Default", or the recipe editor) are
    /// reflected here once the store refreshes - the `recipe` passed at
    /// navigation time is a snapshot and doesn't update on its own. Falls
    /// back to that snapshot if the recipe can no longer be found (e.g. it
    /// was just deleted).
    private var currentRecipe: any RecipeProtocol {
        store.collections
            .first { $0.name == recipe.collection }?
            .recipes.first { $0.name == recipe.name } ?? recipe
    }

    private var prefermentRecipe: PrefermentRecipe? { currentRecipe as? PrefermentRecipe }
    private var hasTemps: Bool { currentRecipe.containsVariableTemps() }
    private var effectiveWeight: Double { singleDoughWeight ?? currentRecipe.defaultWeight }
    private var effectiveDoughCount: Int { doughCount ?? 1 }
    private var totalWeight: Double { effectiveWeight * Double(effectiveDoughCount) }

    var body: some View {
        Form {
            // MARK: - Amounts
            Section("Batch") {
                HStack {
                    Text("Number of Doughs")
                    Spacer()
                    TextField("1", value: $doughCount, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .accessibilityIdentifier("doughCountField")
                }
                HStack {
                    Text("Single Dough Weight")
                    Spacer()
                    TextField("\(Int(currentRecipe.defaultWeight))",
                              value: $singleDoughWeight,
                              format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 100)
                        .accessibilityIdentifier("singleDoughWeightField")
                    Text("g").foregroundStyle(.secondary)
                }
            }

            // MARK: - Preferment toggle + adjustments
            if let preferment = prefermentRecipe?.preferment {
                Section {
                    Toggle("Adjust Preferment Percentages", isOn: $adjustPreferment)
                }
                if adjustPreferment {
                    prefermentAdjustSection(preferment: preferment)
                }
            }

            // MARK: - Ingredient toggle + adjustments
            Section {
                Toggle("Adjust Dough Ingredients", isOn: $adjustIngredients)
                    .accessibilityIdentifier("adjustIngredientsToggle")
            }
            if adjustIngredients {
                ingredientAdjustSection
            }

            // MARK: - Temp toggle + adjustments
            if hasTemps {
                Section {
                    Toggle("Adjust Ingredient Temperatures", isOn: $adjustTemps)
                }
                if adjustTemps {
                    temperatureAdjustSection
                }
            }

            // MARK: - Calculate
            Section {
                Button {
                    calculate()
                } label: {
                    HStack {
                        Spacer()
                        Text("How much do I need?")
                            .bold()
                        Spacer()
                    }
                }
                .accessibilityIdentifier("calculateButton")
            }
        }
        .navigationTitle(currentRecipe.name)
        .navigationDestination(item: $calculatedResult) { wrapper in
            CalculatedRecipeView(calculatedRecipe: wrapper.recipe, recipe: currentRecipe, overrides: wrapper.overrides)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    RecipeHistoryView(recipe: currentRecipe)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityIdentifier("historyButton")
            }
        }
        .sheet(isPresented: $showingEdit, onDismiss: { store.refresh() }) {
            CreateRecipeView(editingRecipe: currentRecipe)
                .environment(store)
        }
        .alert("Calculation Error", isPresented: Binding(
            get: { calculationError != nil },
            set: { if !$0 { calculationError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(calculationError ?? "")
        }
    }

    // MARK: - Ingredient adjustment section

    @ViewBuilder
    private var ingredientAdjustSection: some View {
        Section("Ingredients") {
            ForEach(Array(currentRecipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                if ingredient.extraAmount != nil {
                    // Handled in additionalIngredientsSection.
                } else if ingredient.isFlour {
                    HStack {
                        Text(ingredient.name)
                        Spacer()
                        Text(PercentFormatter.shared.format(percent: ingredient.defaultPercentage))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text(ingredient.name)
                        Spacer()
                        TextField(
                            String(format: "%.4g", ingredient.defaultPercentage),
                            value: Binding(
                                get: { ingredientPercents[index] },
                                set: { ingredientPercents[index] = $0 }
                            ),
                            format: .number
                        )
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        .accessibilityIdentifier("ingredientPercentField_\(index)")
                        Text("%").foregroundStyle(.secondary)
                    }
                }
            }
        }

        if hasAdditionalIngredients {
            additionalIngredientsSection
        }
    }

    private var hasAdditionalIngredients: Bool {
        currentRecipe.ingredients.contains { $0.extraAmount != nil }
    }

    private var additionalIngredientsSection: some View {
        Section {
            ForEach(Array(currentRecipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                if let amount = ingredient.extraAmount, let unit = ingredient.extraUnit {
                    HStack {
                        Text(ingredient.name)
                            .lineLimit(1)
                            .layoutPriority(1)
                        Spacer()
                        TextField(
                            String(format: "%.4g", amount),
                            value: Binding(
                                get: { extraIngredientAmounts[index] },
                                set: { extraIngredientAmounts[index] = $0 }
                            ),
                            format: .number
                        )
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 50)
                        .accessibilityIdentifier("extraIngredientAmountField_\(index)")
                        Text(VolumeUnitFormatter.label(unit: unit, amount: extraIngredientAmounts[index] ?? amount))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Additional Ingredients")
        } footer: {
            Text("These ingredients aren't included in baker's percentages. Adjust the amount if you'd like to scale it for this batch.")
        }
    }

    // MARK: - Temperature adjustment section

    private var temperatureAdjustSection: some View {
        Section("Temperatures") {
            ForEach(Array(currentRecipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                if let temp = ingredient.temperature {
                    HStack {
                        Text(ingredient.name)
                        Spacer()
                        TextField(
                            String(format: "%.4g", temp.value),
                            value: Binding(
                                get: { ingredientTemps[index] },
                                set: { ingredientTemps[index] = $0 }
                            ),
                            format: .number
                        )
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        Text("°\(settings.preferredTemp().shortValue)").foregroundStyle(.secondary)
                    }
                }
            }
            if let preferment = prefermentRecipe?.preferment {
                ForEach(Array(preferment.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    if let temp = ingredient.temperature {
                        HStack {
                            Text("\(preferment.name) – \(ingredient.name)")
                            Spacer()
                            TextField(
                                String(format: "%.4g", temp.value),
                                value: Binding(
                                    get: { ingredientTemps[1000 + index] },
                                    set: { ingredientTemps[1000 + index] = $0 }
                                ),
                                format: .number
                            )
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                            Text("°\(settings.preferredTemp().shortValue)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preferment adjustment section

    @ViewBuilder
    private func prefermentAdjustSection(preferment: Preferment) -> some View {
        Section("Preferment: \(preferment.name)") {
            HStack {
                Text("Flour of Total")
                Spacer()
                TextField(
                    String(format: "%.4g", preferment.flourPercentage),
                    value: $prefermentTotalPercent,
                    format: .number
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 70)
                Text("%").foregroundStyle(.secondary)
            }
            ForEach(Array(preferment.ingredients.enumerated()), id: \.offset) { index, ingredient in
                if ingredient.isFlour {
                    HStack {
                        Text(ingredient.name)
                        Spacer()
                        Text(PercentFormatter.shared.format(percent: ingredient.defaultPercentage))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text(ingredient.name)
                        Spacer()
                        TextField(
                            String(format: "%.4g", ingredient.defaultPercentage),
                            value: Binding(
                                get: { prefermentIngredientPercents[index] },
                                set: { prefermentIngredientPercents[index] = $0 }
                            ),
                            format: .number
                        )
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        Text("%").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Calculation

    private func calculate() {
        let weight = effectiveWeight * Double(effectiveDoughCount)
        let ingredients = buildMeasuredIngredients()
        let preferment = buildMeasuredPreferment()

        do {
            let calculated = try calculator.calculate(
                ingredients: ingredients,
                preferment: preferment,
                recipe: currentRecipe,
                totalWeight: weight
            )
            calculatedResult = CalculatedWrapper(recipe: calculated, overrides: currentOverrides())
        } catch CalculationError.finalDoughNegativeValue(let name, let value) {
            calculationError = "Calculated final dough \(name) weight is \(weightFormatter.format(weight: value)). Please adjust input."
        } catch CalculationError.prefermentNegativeValue(let name, let value) {
            calculationError = "Calculated preferment \(name) weight is \(weightFormatter.format(weight: value)). Please adjust input."
        } catch {
            calculationError = "An unexpected calculation error occurred."
        }
    }

    private func currentOverrides() -> CalculatorOverrides {
        CalculatorOverrides(
            ingredientPercents: ingredientPercents,
            ingredientTemps: ingredientTemps,
            prefermentIngredientPercents: prefermentIngredientPercents,
            prefermentTotalPercent: prefermentTotalPercent,
            singleDoughWeight: singleDoughWeight,
            extraIngredientAmounts: extraIngredientAmounts,
            temperatureMeasurement: settings.preferredTemp()
        )
    }

    private func buildMeasuredIngredients() -> [MeasuredIngredient] {
        currentRecipe.ingredients.enumerated().map { index, ingredient in
            let percent = ingredientPercents[index] ?? ingredient.defaultPercentage
            var temp = ingredient.temperature
            if let rawTemp = ingredientTemps[index] {
                temp = Temperature(value: rawTemp, measurement: settings.preferredTemp())
            }
            return MeasuredIngredient(ingredient: ingredient, percent: percent, temperature: temp, extraAmountOverride: extraIngredientAmounts[index])
        }
    }

    private func buildMeasuredPreferment() -> MeasuredPreferment? {
        guard let preferment = prefermentRecipe?.preferment else { return nil }
        let fermentPercent = prefermentTotalPercent ?? preferment.flourPercentage
        let fermentIngredients = preferment.ingredients.enumerated().map { index, ingredient in
            let percent = prefermentIngredientPercents[index] ?? ingredient.defaultPercentage
            var temp = ingredient.temperature
            if let rawTemp = ingredientTemps[1000 + index] {
                temp = Temperature(value: rawTemp, measurement: settings.preferredTemp())
            }
            return MeasuredIngredient(ingredient: ingredient, percent: percent, temperature: temp)
        }
        return MeasuredPreferment(ingredients: fermentIngredients, name: preferment.name, flourPercentage: fermentPercent)
    }
}

// Wraps CalculatedRecipeProtocol (plus the overrides used to produce it) for
// use as a NavigationStack value.
private struct CalculatedWrapper: Identifiable, Hashable {
    let id = UUID()
    let recipe: any CalculatedRecipeProtocol
    let overrides: CalculatorOverrides

    static func == (lhs: CalculatedWrapper, rhs: CalculatedWrapper) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
