//
//  CalculatedRecipeView.swift
//  Doughy

import SwiftUI

struct CalculatedRecipeView: View {
    let calculatedRecipe: any CalculatedRecipeProtocol
    let recipe: any RecipeProtocol
    let overrides: CalculatorOverrides

    @Environment(RecipeStore.self) private var store
    @State private var tweakText: String = ""
    @State private var noteText: String = ""
    @State private var lastSavedNoteText: String?
    @State private var showingSetAsDefaultConfirmation = false
    @State private var actionError: String?

    private let weightFormatter = WeightFormatter.shared
    private let percentFormatter = PercentFormatter.shared
    private let tempFormatter = TemperatureFormatter.shared
    private let densityStore = IngredientDensityStore.shared
    private let conversionStore = IngredientConversionStore.shared

    /// Tracks the currently selected display unit for each ingredient by name.
    /// Absent entries default to "grams".
    @State private var ingredientDisplayUnits: [String: String] = [:]

    private var prefermentRecipe: CalculatedPrefermentRecipe? { calculatedRecipe as? CalculatedPrefermentRecipe }

    /// Diff between the recipe's current defaults and what "Set as Default"
    /// would persist, given this screen's calculator overrides. `nil` if the
    /// overrides don't actually change anything.
    private var overrideDiff: String? {
        RecipeDiff.summarize(from: RecipeSnapshot(from: recipe), to: overrides.applied(to: recipe))
    }

    /// Ingredients with a quantity that isn't part of the gram total (e.g. "2 tablespoons"
    /// of rosemary leaves), shown separately and not part of any weight shown above.
    private var extraIngredients: [CalculatedIngredient] {
        calculatedRecipe.ingredients.filter { $0.extraAmount != nil }
    }

    private var doughIngredients: [CalculatedIngredient] {
        calculatedRecipe.ingredients.filter { $0.extraAmount == nil }
    }

    var body: some View {
        Form {
            // MARK: - Preferment section
            if let preferment = prefermentRecipe?.preferment {
                Section {
                    ForEach(preferment.ingredients.filter { $0.extraAmount == nil }, id: \.name) { ingredient in
                        ingredientRow(ingredient)
                    }
                } header: {
                    HStack {
                        Text(preferment.name)
                        Spacer()
                        Text(weightFormatter.format(weight: preferment.weight))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Final dough section
            Section {
                ForEach(doughIngredients, id: \.name) { ingredient in
                    finalDoughRow(ingredient)
                }
                if let preferment = prefermentRecipe?.preferment {
                    finalDoughRow(preferment.toCalculatedIngredient())
                }
            } header: {
                HStack {
                    Text(prefermentRecipe != nil ? "Final Dough" : "Dough")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(weightFormatter.format(weight: calculatedRecipe.weight))
                            .accessibilityIdentifier("doughTotalWeight")
                        if !extraIngredients.isEmpty {
                            Text("plus additional ingredients")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            // MARK: - Additional ingredients section
            if !extraIngredients.isEmpty {
                Section {
                    ForEach(extraIngredients, id: \.name) { ingredient in
                        extraIngredientRow(ingredient)
                    }
                } header: {
                    Text("Additional Ingredients")
                } footer: {
                    Text("These ingredients are scaled with the recipe but aren't included in the weight above.")
                }
            }

            // MARK: - Instructions section
            if !calculatedRecipe.instructions.isEmpty {
                Section("Instructions") {
                    ForEach(Array(calculatedRecipe.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)
                            Text(instruction.step)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            // MARK: - Notes
            Section("Notes") {
                if overrideDiff != nil {
                    TextField("Changes from default", text: $tweakText, axis: .vertical)
                        .accessibilityIdentifier("historyTweakField")
                }
                TextField("Add a note about this batch...", text: $noteText, axis: .vertical)
                    .accessibilityIdentifier("historyNoteField")
                HStack {
                    Button("Save Note") {
                        saveNote()
                    }
                    .disabled(combinedNoteText.isEmpty || combinedNoteText == lastSavedNoteText)
                    .accessibilityIdentifier("saveNoteButton")

                    if combinedNoteText == lastSavedNoteText, lastSavedNoteText != nil {
                        Spacer()
                        Text("Saved")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("noteSavedMessage")
                    }
                }
            }

            // MARK: - Set as Default
            if overrides.hasAnyOverride {
                Section {
                    Button("Set as Default") {
                        showingSetAsDefaultConfirmation = true
                    }
                    .accessibilityIdentifier("setAsDefaultButton")
                    .confirmationDialog("Set as Default", isPresented: $showingSetAsDefaultConfirmation, titleVisibility: .visible) {
                        Button("Set as Default") {
                            setAsDefault()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text(overrideDiff ?? "No changes to apply.")
                    }
                }
            }
        }
        .navigationTitle(calculatedRecipe.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            tweakText = overrideDiff ?? ""
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Notes / Set as Default actions

    /// The tweak summary and free-text note, joined by a newline. Either half
    /// may be empty (e.g. no overrides, or no note text entered).
    private var combinedNoteText: String {
        let tweaks = tweakText.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        return [tweaks, notes].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private func saveNote() {
        let text = combinedNoteText
        guard !text.isEmpty else { return }
        do {
            try store.addNote(text, to: recipe)
            lastSavedNoteText = text
        } catch {
            actionError = String(localized: "calculated.error.save_note", defaultValue: "Could not save this note.")
        }
    }

    private func setAsDefault() {
        do {
            try store.setAsDefault(recipe: recipe, overrides: overrides)
        } catch {
            actionError = String(localized: "calculated.error.set_default", defaultValue: "Could not update this recipe's default values.")
        }
    }

    // MARK: - Volume unit cycling

    /// Resolves an ingredient name to a density category. Prefers an exact match against
    /// `IngredientCategory.displayName` (reliable for stored recipe ingredients) and falls
    /// back to keyword matching for partial or variant names from scanning.
    private func densityCategory(for lowerName: String) -> IngredientCategory? {
        IngredientCategory.allCases.first { $0.displayName.lowercased() == lowerName }
            ?? ExtraIngredientConversion.ingredientCategory(forName: lowerName)
    }

    /// Returns the ordered list of units available for `name` at `grams`, starting with
    /// "grams". Units whose converted amount falls outside a practical range are skipped.
    /// Returns `nil` when no volume conversion exists for the ingredient.
    private func systemPrimary(for category: IngredientCategory, system: VolumeSystem) -> DensityUnit {
        DensityUnit.systemDefault(for: category.defaultDisplayUnit, in: system)
    }

    private func cycleUnits(for name: String, grams: Double) -> [String]? {
        var units: [String] = ["grams"]
        let lowerName = name.lowercased()

        if let category = densityCategory(for: lowerName) {
            let gramsPerCup = densityStore.gramsPerCup(for: category)
            let system = Settings.shared.preferredVolumeSystem()
            let primary = systemPrimary(for: category, system: system)
            let systemUnits: [DensityUnit]
            switch system {
            case .imperial: systemUnits = [.cup, .tablespoon, .teaspoon]
            case .metric:   systemUnits = [.deciliter, .liter, .milliliter]
            }
            // Primary is always shown; remaining system units are filtered to practical ranges.
            let volumeUnits: [DensityUnit] = [primary] + systemUnits.filter { $0 != primary }
            let secondaryLimits: [DensityUnit: (min: Double, max: Double)] = [
                .cup: (0.0625, 20), .tablespoon: (0.0625, 32), .teaspoon: (0.0625, 48),
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

    private func advanceUnit(key: String, name: String, grams: Double) {
        guard let units = cycleUnits(for: name, grams: grams) else { return }
        let current = ingredientDisplayUnits[key] ?? "grams"
        let idx = units.firstIndex(of: current) ?? 0
        ingredientDisplayUnits[key] = units[(idx + 1) % units.count]
    }

    /// Formats `grams` expressed in `unit` for the named ingredient.
    private func weightDisplay(grams: Double, unit: String, for name: String) -> String {
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

    /// Formats a volume amount using baker-friendly fractions (1/8 resolution + 1/3, 2/3).
    /// Returns both the display string and the snapped numeric value so callers can base
    /// pluralization on the displayed quantity rather than the raw floating-point amount.
    /// Values below 1/8 are shown as decimals to avoid snapping to "0".
    private func formatVolumeAmount(_ value: Double) -> (display: String, snapped: Double) {
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

    @ViewBuilder
    private func ingredientRow(_ ingredient: CalculatedIngredient) -> some View {
        let key = "preferment:\(ingredient.name)"
        let units = cycleUnits(for: ingredient.name, grams: ingredient.weight)
        let currentUnit = ingredientDisplayUnits[key] ?? "grams"
        let weightText = weightDisplay(grams: ingredient.weight, unit: currentUnit, for: ingredient.name)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                if let temp = ingredient.temperature {
                    Text(tempFormatter.format(temperature: temp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(weightText)
                    .foregroundStyle(units != nil ? Color.blue : Color.primary)
                Text(percentFormatter.format(percent: ingredient.percentage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard units != nil else { return }
            advanceUnit(key: key, name: ingredient.name, grams: ingredient.weight)
        }
        .accessibilityAddTraits(units != nil ? .isButton : [])
        .accessibilityHint(units != nil ? String(localized: "Double-tap to cycle units") : "")
    }

    @ViewBuilder
    private func extraIngredientRow(_ ingredient: CalculatedIngredient) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                if let temp = ingredient.temperature {
                    Text(tempFormatter.format(temperature: temp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let amount = ingredient.extraAmount, let unit = ingredient.extraUnit {
                Text(VolumeUnitFormatter.format(amount: amount, unit: unit))
            }
        }
    }

    @ViewBuilder
    private func finalDoughRow(_ ingredient: CalculatedIngredient) -> some View {
        let prefermentWeight = prefermentRecipe?.preferment.ingredients
            .first(where: { $0.name == ingredient.name })?.weight ?? 0
        let doughWeight = ingredient.weight - prefermentWeight
        let key = "dough:\(ingredient.name)"
        let units = cycleUnits(for: ingredient.name, grams: ingredient.weight)
        let currentUnit = ingredientDisplayUnits[key] ?? "grams"
        let weightText = weightDisplay(grams: doughWeight, unit: currentUnit, for: ingredient.name)

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                if let temp = ingredient.temperature {
                    Text(tempFormatter.format(temperature: temp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if prefermentWeight > 0 {
                    Text(percentFormatter.format(percent: ingredient.totalPercentage) + " total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(weightText)
                    .foregroundStyle(units != nil ? Color.blue : Color.primary)
                    .accessibilityIdentifier("ingredientWeight_\(ingredient.name)")
                Text(
                    ingredient.percentage > 0 && ingredient.totalPercentage > 0 ? percentFormatter.format(percent: ingredient.percentage) : "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("ingredientPercent_\(ingredient.name)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard units != nil else { return }
            advanceUnit(key: key, name: ingredient.name, grams: ingredient.weight)
        }
        .accessibilityAddTraits(units != nil ? .isButton : [])
        .accessibilityHint(units != nil ? String(localized: "Double-tap to cycle units") : "")
    }
}

fileprivate extension CalculatedPreferment {
    func toCalculatedIngredient() -> CalculatedIngredient {
        return .init(name: name, isFlour: false, percentage: 0, totalPercentage: 0, temperature: nil, weight: weight)
    }
}
