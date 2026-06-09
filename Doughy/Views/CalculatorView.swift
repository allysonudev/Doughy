//
//  CalculatorView.swift
//  Doughy

import SwiftUI

struct CalculatorView: View {
    let recipe: any RecipeProtocol
    @Environment(RecipeStore.self) private var store

    @State private var doughCount: Int = 1
    @State private var singleDoughWeight: Double?
    @State private var adjustIngredients = false
    @State private var adjustTemps = false
    @State private var adjustPreferment = false
    @State private var ingredientPercents: [Int: Double] = [:]
    @State private var ingredientTemps: [Int: Double] = [:]
    @State private var prefermentIngredientPercents: [Int: Double] = [:]
    @State private var prefermentTotalPercent: Double?
    @State private var calculatedRecipe: (any CalculatedRecipeProtocol)?
    @State private var calculationError: String?
    @State private var showingEdit = false

    private let calculator = Calculator.shared
    private let settings = Settings.shared
    private let weightFormatter = WeightFormatter.shared

    private var prefermentRecipe: PrefermentRecipe? { recipe as? PrefermentRecipe }
    private var hasTemps: Bool { recipe.containsVariableTemps() }
    private var effectiveWeight: Double { singleDoughWeight ?? recipe.defaultWeight }
    private var totalWeight: Double { effectiveWeight * Double(doughCount) }

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
                }
                HStack {
                    Text("Single Dough Weight")
                    Spacer()
                    TextField("\(Int(recipe.defaultWeight))",
                              value: $singleDoughWeight,
                              format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 100)
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
            }
        }
        .navigationTitle(recipe.name)
        .navigationDestination(item: Binding(
            get: { calculatedRecipe.map { CalculatedWrapper(recipe: $0) } },
            set: { calculatedRecipe = $0?.recipe }
        )) { wrapper in
            CalculatedRecipeView(calculatedRecipe: wrapper.recipe)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEdit = true }
            }
        }
        .sheet(isPresented: $showingEdit, onDismiss: { store.refresh() }) {
            CreateRecipeView(editingRecipe: recipe)
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

    private var ingredientAdjustSection: some View {
        Section("Ingredients") {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
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
                                get: { ingredientPercents[index] },
                                set: { ingredientPercents[index] = $0 }
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

    // MARK: - Temperature adjustment section

    private var temperatureAdjustSection: some View {
        Section("Temperatures") {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
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
        let weight = effectiveWeight * Double(doughCount)
        let ingredients = buildMeasuredIngredients()
        let preferment = buildMeasuredPreferment()

        do {
            calculatedRecipe = try calculator.calculate(
                ingredients: ingredients,
                preferment: preferment,
                recipe: recipe,
                totalWeight: weight
            )
        } catch CalculationError.finalDoughNegativeValue(let name, let value) {
            calculationError = "Calculated final dough \(name) weight is \(weightFormatter.format(weight: value)). Please adjust input."
        } catch CalculationError.prefermentNegativeValue(let name, let value) {
            calculationError = "Calculated preferment \(name) weight is \(weightFormatter.format(weight: value)). Please adjust input."
        } catch {
            calculationError = "An unexpected calculation error occurred."
        }
    }

    private func buildMeasuredIngredients() -> [MeasuredIngredient] {
        recipe.ingredients.enumerated().map { index, ingredient in
            let percent = ingredientPercents[index] ?? ingredient.defaultPercentage
            var temp = ingredient.temperature
            if let rawTemp = ingredientTemps[index] {
                temp = Temperature(value: rawTemp, measurement: settings.preferredTemp())
            }
            return MeasuredIngredient(ingredient: ingredient, percent: percent, temperature: temp)
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

// Wraps CalculatedRecipeProtocol for use as a NavigationStack value.
private struct CalculatedWrapper: Identifiable, Hashable {
    let id = UUID()
    let recipe: any CalculatedRecipeProtocol

    static func == (lhs: CalculatedWrapper, rhs: CalculatedWrapper) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
