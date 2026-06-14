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
            actionError = "Could not save this note."
        }
    }

    private func setAsDefault() {
        do {
            try store.setAsDefault(recipe: recipe, overrides: overrides)
        } catch {
            actionError = "Could not update this recipe's default values."
        }
    }

    @ViewBuilder
    private func ingredientRow(_ ingredient: CalculatedIngredient) -> some View {
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
                Text(weightFormatter.format(weight: ingredient.weight))
                Text(percentFormatter.format(percent: ingredient.percentage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
                Text(weightFormatter.format(weight: doughWeight))
                    .accessibilityIdentifier("ingredientWeight_\(ingredient.name)")
                Text(percentFormatter.format(percent: ingredient.percentage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("ingredientPercent_\(ingredient.name)")
            }
        }
    }
}
