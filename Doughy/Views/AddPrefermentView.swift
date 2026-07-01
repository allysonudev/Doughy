//
//  AddPrefermentView.swift
//  Doughy
//

import SwiftUI

/// Sheet presented from the Adjust tab's "Add preferment" button. Carves a
/// poolish, biga, or sourdough starter out of the recipe's existing flour,
/// water, and yeast while keeping the recipe's total hydration unchanged.
struct AddPrefermentView: View {
    let recipe: any RecipeProtocol
    /// Hands back the built, validated preferment (and, for a sourdough
    /// starter, the main dough yeast ingredient it replaces) without touching
    /// the stored recipe - the caller applies it as a session-scoped Adjust
    /// tab override, the same way other Adjust edits work until "Set as
    /// Default" persists them.
    let onAdd: (Preferment, String?) -> Void

    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var flourPercent: Double?
    @State private var hydrationPercent: Double?
    @State private var yeastPercent: Double?
    @State private var showsYeastField = true
    @State private var removesMainDoughYeast = false
    @State private var flourAllocations: [PrefermentTool.FlourAllocation] = []
    @State private var pendingSelectionRowID: UUID?
    @State private var focusedRowID: UUID?
    @State private var saveError: String?

    private let nameRowID = UUID()
    private let percentFormatter = PercentFormatter.shared
    private let weightFormatter = WeightFormatter.shared

    private var waterName: String? { PrefermentTool.waterIngredient(in: recipe)?.name }
    private var yeastName: String? { PrefermentTool.yeastIngredient(in: recipe)?.name }
    private var hasMultipleFlours: Bool { PrefermentTool.flourIngredients(in: recipe).count > 1 }

    private var calculated: (any CalculatedRecipeProtocol)? {
        try? Calculator.shared.calculate(recipe: recipe)
    }
    private var totalFlourWeight: Double {
        calculated?.ingredients.filter { $0.isFlour }.map(\.weight).reduce(0, +) ?? 0
    }
    private var totalWaterWeight: Double {
        calculated?.ingredients.first { $0.name == waterName }?.weight ?? 0
    }
    private var totalYeastWeight: Double {
        calculated?.ingredients.first { $0.name == yeastName }?.weight ?? 0
    }
    private func totalWeight(forFlourNamed flourName: String) -> Double {
        calculated?.ingredients.first { $0.isFlour && $0.name == flourName }?.weight ?? 0
    }

    private var nameSuggestions: [String] {
        var names = PrefermentPreset.allCases.map(\.rawValue)
        for suggestion in PrefermentTool.prefermentNameSuggestions(in: store)
        where !names.contains(where: { $0.caseInsensitiveCompare(suggestion) == .orderedSame }) {
            names.append(suggestion)
        }
        return names
    }

    private var prefermentFlourWeight: Double { totalFlourWeight * (flourPercent ?? 0) / 100 }
    private var prefermentWaterWeight: Double { prefermentFlourWeight * (hydrationPercent ?? 0) / 100 }
    private var prefermentYeastWeight: Double { showsYeastField ? prefermentFlourWeight * (yeastPercent ?? 0) / 100 : 0 }

    private func prefermentWeight(for allocation: PrefermentTool.FlourAllocation) -> Double {
        prefermentFlourWeight * (allocation.percentOfPrefermentFlour / 100)
    }

    private var flourAllocationTotal: Double {
        flourAllocations.map(\.percentOfPrefermentFlour).reduce(0, +)
    }

    private var totalHydrationPercent: Double {
        totalFlourWeight > 0 ? (totalWaterWeight / totalFlourWeight) * 100 : 0
    }

    private var displayName: String {
        name.isEmpty ? String(localized: "preferment.add.default_name", defaultValue: "Preferment") : name
    }

    private var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(String(localized: "preferment.add.error.name", defaultValue: "Enter a name for the preferment."))
        }
        guard let flourPercent, flourPercent > 0, flourPercent <= 100 else {
            errors.append(String(localized: "preferment.add.error.flour_percent", defaultValue: "Enter what percent of the total flour goes into the preferment."))
            return errors
        }
        if hasMultipleFlours, abs(flourAllocationTotal - 100) > 0.01 {
            errors.append(String(localized: "preferment.add.error.flour_blend", defaultValue: "The flour blend must add up to 100%."))
        }
        for allocation in flourAllocations where prefermentWeight(for: allocation) - totalWeight(forFlourNamed: allocation.name) > 0.01 {
            errors.append(String(format: String(localized: "preferment.add.error.flour_amount", defaultValue: "The recipe doesn't have enough %@ for that split."), allocation.name))
        }
        if prefermentWaterWeight - totalWaterWeight > 0.01 {
            errors.append(String(localized: "preferment.add.error.water", defaultValue: "That hydration takes out more water than the recipe has."))
        }
        if showsYeastField, prefermentYeastWeight - totalYeastWeight > 0.01 {
            errors.append(String(localized: "preferment.add.error.yeast", defaultValue: "That's more yeast than the recipe has."))
        }
        return errors
    }

    private var isValid: Bool { validationErrors.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                if hasMultipleFlours {
                    flourBlendSection
                }
                previewSection
            }
            .navigationTitle(String(localized: "preferment.add.title", defaultValue: "Add Preferment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.add", defaultValue: "Add")) { addPreferment() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("addPrefermentConfirmButton")
                }
            }
            .onAppear {
                flourAllocations = PrefermentTool.defaultFlourAllocations(for: recipe)
            }
            .onChange(of: pendingSelectionRowID) { _, newValue in
                guard newValue == nameRowID else { return }
                applyDefaults(forSelectedName: name)
                pendingSelectionRowID = nil
            }
            .alert(String(localized: "error.generic_title", defaultValue: "Something Went Wrong"), isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    private var detailsSection: some View {
        Section {
            IngredientNameField(
                placeholder: String(localized: "preferment.add.name_placeholder", defaultValue: "Poolish, Biga, Levain…"),
                text: $name,
                suggestions: nameSuggestions,
                accessibilityID: "addPrefermentNameField",
                rowID: nameRowID,
                focusedRowID: $focusedRowID,
                pendingValueRowID: $pendingSelectionRowID
            )

            HStack {
                Text(String(localized: "preferment.add.flour_percent", defaultValue: "% of Total Flour"))
                Spacer()
                percentField(value: $flourPercent, accessibilityID: "addPrefermentFlourPercentField")
            }
            HStack {
                Text(String(localized: "preferment.add.hydration", defaultValue: "Hydration"))
                Spacer()
                percentField(value: $hydrationPercent, accessibilityID: "addPrefermentHydrationField")
            }
            if showsYeastField {
                HStack {
                    Text(String(localized: "preferment.add.yeast", defaultValue: "Yeast (of preferment flour)"))
                    Spacer()
                    percentField(value: $yeastPercent, accessibilityID: "addPrefermentYeastField")
                }
            } else {
                Label(
                    String(format: String(localized: "preferment.add.replaces_yeast", defaultValue: "This replaces %@ - it will be removed from the recipe."), yeastName ?? ""),
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "preferment.add.details_header", defaultValue: "Preferment Details"))
        }
    }

    private var flourBlendSection: some View {
        Section {
            ForEach($flourAllocations) { $allocation in
                HStack {
                    Text(allocation.name)
                    Spacer()
                    percentField(
                        value: Binding(
                            get: { allocation.percentOfPrefermentFlour },
                            set: { allocation.percentOfPrefermentFlour = $0 ?? 0 }
                        ),
                        accessibilityID: "addPrefermentFlourBlendField_\(allocation.name)"
                    )
                }
            }
        } header: {
            Text(String(localized: "preferment.add.flour_blend_header", defaultValue: "Flour Blend"))
        } footer: {
            let diff = 100 - flourAllocationTotal
            if abs(diff) < 0.01 {
                Text(String(localized: "preferment.add.flour_blend.complete", defaultValue: "100% of the preferment's flour. ✓"))
                    .foregroundStyle(.green)
            } else {
                Text(String(format: String(localized: "preferment.add.flour_blend.remaining", defaultValue: "%.4g%% remaining to reach 100%% of the preferment's flour."), diff))
                    .foregroundStyle(diff < 0 ? .red : .orange)
            }
        }
    }

    private var previewSection: some View {
        Section {
            ForEach(flourAllocations) { allocation in
                LabeledContent("\(displayName) \(allocation.name)", value: weightFormatter.format(weight: prefermentWeight(for: allocation)))
            }
            if let waterName {
                LabeledContent("\(displayName) \(waterName)", value: weightFormatter.format(weight: prefermentWaterWeight))
            }
            if showsYeastField, let yeastName, (yeastPercent ?? 0) > 0 {
                LabeledContent("\(displayName) \(yeastName)", value: weightFormatter.format(weight: prefermentYeastWeight))
            }
            LabeledContent {
                remainingSummaryText
            } label: {
                Text(String(localized: "preferment.add.remaining_main_dough", defaultValue: "Remaining Main Dough"))
            }
            Label(
                String(format: String(localized: "preferment.add.hydration_unchanged", defaultValue: "Total hydration unchanged at %@."), percentFormatter.format(percent: totalHydrationPercent)),
                systemImage: "checkmark.circle"
            )
            .font(.footnote)
            .foregroundStyle(.green)

            ForEach(validationErrors, id: \.self) { error in
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text(String(localized: "preferment.add.preview_header", defaultValue: "Preview"))
        }
    }

    /// What's left for the main dough once the preferment is carved out, per
    /// ingredient - deliberately *not* clamped at zero, so a split that asks
    /// for more of something than the recipe has shows up as a negative
    /// amount (colored red by `remainingSummaryText`) rather than silently
    /// reading "0g" alongside the validation error below.
    private var remainingComponents: [(name: String, weight: Double)] {
        var components: [(name: String, weight: Double)] = []
        for flour in PrefermentTool.flourIngredients(in: recipe) {
            let allocation = flourAllocations.first { $0.name == flour.name }
            let remaining = totalWeight(forFlourNamed: flour.name) - (allocation.map(prefermentWeight(for:)) ?? 0)
            components.append((flour.name, remaining))
        }
        components.append((waterName ?? "", totalWaterWeight - prefermentWaterWeight))
        if showsYeastField, let yeastName {
            components.append((yeastName, totalYeastWeight - prefermentYeastWeight))
        }
        return components
    }

    private var remainingSummaryText: Text {
        let separator = Text(" · ").foregroundStyle(.secondary)
        var segments = remainingComponents.map { component in
            Text("\(weightFormatter.format(weight: component.weight)) \(component.name)")
                .foregroundStyle(component.weight < 0 ? .red : .primary)
        }
        if !showsYeastField {
            segments.append(Text(String(localized: "preferment.add.no_yeast", defaultValue: "no yeast")))
        }
        return segments.dropFirst().reduce(segments.first ?? Text("")) { $0 + separator + $1 }
    }

    private func percentField(value: Binding<Double?>, accessibilityID: String) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 70)
                .accessibilityIdentifier(accessibilityID)
            Text("%").foregroundStyle(.secondary)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func applyDefaults(forSelectedName selected: String) {
        if let preset = PrefermentPreset.matching(name: selected) {
            let defaultYeast = preset.defaultYeastPercent(for: recipe)
            flourPercent = preset.defaultFlourPercentOfTotal
            hydrationPercent = preset.defaultHydrationPercent
            yeastPercent = defaultYeast
            showsYeastField = defaultYeast != nil
            removesMainDoughYeast = preset.removesMainDoughYeast
            flourAllocations = PrefermentTool.defaultFlourAllocations(for: recipe)
        } else if let existing = PrefermentTool.existingPreferment(named: selected, in: store) {
            flourPercent = existing.flourPercentage
            hydrationPercent = existing.ingredients.first { $0.name.localizedCaseInsensitiveContains("water") }?.defaultPercentage
            let existingYeastPercent = existing.ingredients.first { $0.name.localizedCaseInsensitiveContains("yeast") }?.defaultPercentage
            yeastPercent = existingYeastPercent ?? 0
            showsYeastField = existingYeastPercent != nil
            removesMainDoughYeast = existingYeastPercent == nil
            let existingFloursByName = Dictionary(
                uniqueKeysWithValues: existing.ingredients.filter(\.isFlour).map { ($0.name.lowercased(), $0.defaultPercentage) }
            )
            flourAllocations = PrefermentTool.defaultFlourAllocations(for: recipe).map {
                PrefermentTool.FlourAllocation(
                    name: $0.name,
                    percentOfPrefermentFlour: existingFloursByName[$0.name.lowercased()] ?? $0.percentOfPrefermentFlour
                )
            }
        }
    }

    private func addPreferment() {
        guard let flourPercent, let hydrationPercent, let waterName else { return }
        let preferment = PrefermentTool.buildPreferment(
            name: name.trimmingCharacters(in: .whitespaces),
            flourPercentOfTotal: flourPercent,
            flourAllocations: flourAllocations,
            hydrationPercent: hydrationPercent,
            waterName: waterName,
            yeastPercent: showsYeastField ? (yeastPercent ?? 0) : nil,
            yeastName: yeastName
        )
        do {
            // Validated against the current recipe so the same rule the persistence
            // layer enforces (a preferment can't claim more of an ingredient than the
            // recipe's total) applies here too, even though nothing is written yet.
            let validated = try PrefermentTool.addPreferment(
                preferment,
                to: recipe,
                removingYeastNamed: removesMainDoughYeast ? yeastName : nil
            )
            onAdd(validated.preferment, removesMainDoughYeast ? yeastName : nil)
            dismiss()
        } catch RecipeBuilderError.mainDoughLessThanPreferment(let main, let pref) {
            saveError = String(
                format: String(localized: "create.error.main_dough_less_than_preferment", defaultValue: "%@ in the main dough must be at least as much as in the preferment (%@)."),
                main.name, pref.name
            )
        } catch RecipeBuilderError.mainDoughMissingPreferment(let ing) {
            saveError = String(
                format: String(localized: "create.error.main_dough_missing_preferment", defaultValue: "Preferment ingredient \"%@\" is not in the main dough."),
                ing.name
            )
        } catch {
            saveError = error.localizedDescription
        }
    }
}
