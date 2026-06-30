//
//  CalculatorView+RecipeMode.swift
//  Doughy
//

import SwiftUI

extension CalculatorView {
    // MARK: - Recipe mode

    var recipeContent: some View {
        Form {
            sharedBySection
            if calculatedRecipe != nil {
                ingredientsSections(track: true)
                instructionsSection
                notesSection
                setAsDefaultSection
            } else if let calculationError {
                Section {
                    Text(calculationError)
                        .foregroundStyle(.red)
                }
            } else {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        // Reserve room so the last rows clear the floating ingredients button when it's showing.
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 52) }
    }

    @ViewBuilder
    var sharedBySection: some View {
        if let author = sharedBy {
            Section {
                if let note = sharedNote {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { noteExpanded },
                            set: {
                                noteExpanded = $0
                                UserDefaults.standard.set($0, forKey: noteExpandedKey)
                            }
                        )
                    ) {
                        Text(note)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text("Shared by \(author)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("Shared by \(author)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// The ingredient sections. When `track` is true (the live Recipe scroll), the bottom-most
    /// ingredient row drives `ingredientsVisible` via `onAppear`/`onDisappear`; the sheet passes
    /// false so its own scrolling doesn't move the floating button.
    @ViewBuilder
    func ingredientsSections(track: Bool) -> some View {
        if let preferment = calculatedPrefermentRecipe?.preferment {
            Section {
                ForEach(preferment.ingredients.filter { $0.extraAmount == nil }, id: \.name) { ingredient in
                    calculatedIngredientRow(ingredient)
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

        Section {
            ForEach(Array(doughIngredients.enumerated()), id: \.element.name) { index, ingredient in
                trackIngredientsVisibility(
                    finalDoughRow(ingredient),
                    enabled: track && extraIngredients.isEmpty
                        && calculatedPrefermentRecipe?.preferment == nil
                        && index == doughIngredients.count - 1
                )
            }
            if let preferment = calculatedPrefermentRecipe?.preferment {
                trackIngredientsVisibility(
                    HStack {
                        Text(preferment.name)
                        Spacer()
                        Text(weightFormatter.format(weight: preferment.weight))
                            .fontWeight(.medium)
                    },
                    enabled: track && extraIngredients.isEmpty
                )
            }
        } header: {
            HStack {
                Text(calculatedPrefermentRecipe != nil ? "Final Dough" : "Dough")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(weightFormatter.format(weight: calculatedRecipe?.weight ?? totalWeight))
                        .accessibilityIdentifier("doughTotalWeight")
                    if !extraIngredients.isEmpty {
                        Text("plus additional ingredients")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }

        if !extraIngredients.isEmpty {
            Section {
                ForEach(Array(extraIngredients.enumerated()), id: \.element.name) { index, ingredient in
                    trackIngredientsVisibility(
                        extraIngredientRow(ingredient),
                        enabled: track && index == extraIngredients.count - 1
                    )
                }
            } header: {
                Text("Additional Ingredients")
            } footer: {
                Text("These ingredients are scaled with the recipe but aren't included in the weight above.")
            }
        }
    }

    /// Drives `ingredientsVisible` from the bottom-most ingredient row. `List`/`Form` only deliver
    /// `onAppear`/`onDisappear` to rows (not preferences or `onScrollVisibilityChange`), so we use
    /// those: the row leaves the top → ingredients are gone → show the peek button.
    @ViewBuilder
    func trackIngredientsVisibility<Content: View>(_ content: Content, enabled: Bool) -> some View {
        if enabled {
            content
                .onAppear { ingredientsVisible = true }
                .onDisappear { ingredientsVisible = false }
        } else {
            content
        }
    }

    @ViewBuilder
    var instructionsSection: some View {
        if let calculatedRecipe, !calculatedRecipe.instructions.isEmpty {
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
    }

    var notesSection: some View {
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
    }

    @ViewBuilder
    var setAsDefaultSection: some View {
        if currentOverrides().hasAnyOverride {
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

    func calculatedIngredientRow(_ ingredient: CalculatedIngredient) -> some View {
        let key = "preferment:\(ingredient.name)"
        let units = cycleUnits(for: ingredient.name, grams: ingredient.weight)
        let currentUnit = ingredientDisplayUnits[key] ?? "grams"
        let weightText = weightDisplay(grams: ingredient.weight, unit: currentUnit, for: ingredient.name)
        return HStack {
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
                    .fontWeight(.medium)
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

    func finalDoughRow(_ ingredient: CalculatedIngredient) -> some View {
        let prefermentWeight = calculatedPrefermentRecipe?.preferment.ingredients
            .first(where: { $0.name == ingredient.name })?.weight ?? 0
        let doughWeight = ingredient.weight - prefermentWeight
        let key = "dough:\(ingredient.name)"
        let units = cycleUnits(for: ingredient.name, grams: ingredient.weight)
        let currentUnit = ingredientDisplayUnits[key] ?? "grams"
        let weightText = weightDisplay(grams: doughWeight, unit: currentUnit, for: ingredient.name)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                if let temp = ingredient.temperature {
                    Text(tempFormatter.format(temperature: temp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if prefermentWeight > 0 {
                    Text(String(format: String(localized: "calculated.percent_total", defaultValue: "%@ total"), percentFormatter.format(percent: ingredient.totalPercentage)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(weightText)
                    .fontWeight(.medium)
                    .foregroundStyle(units != nil ? Color.blue : Color.primary)
                    .accessibilityIdentifier("ingredientWeight_\(ingredient.name)")
                Text(
                    ingredient.percentage > 0 && ingredient.totalPercentage > 0 ? percentFormatter.format(percent: ingredient.percentage) : ""
                )
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

    func extraIngredientRow(_ ingredient: CalculatedIngredient) -> some View {
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
                Text(VolumeUnitFormatter.localizedFormat(amount: amount, unit: unit))
            }
        }
    }
}
