//
//  IngredientConversionsView.swift
//  Doughy

import SwiftUI

/// Lets users adjust the grams-per-cup values the recipe scanner uses to convert
/// cup/tablespoon/teaspoon measurements to grams. Seeded with reasonable defaults,
/// but density varies with humidity, brand, and how an ingredient is measured, so
/// users can tweak individual ingredients or reset back to the defaults.
struct IngredientConversionsView: View {
    private let store = IngredientDensityStore.shared
    private let conversionStore = IngredientConversionStore.shared

    @State private var values: [IngredientCategory: Double] = [:]
    @State private var displayUnits: [IngredientCategory: DensityUnit] = [:]
    @State private var eggValues: [EggSize: [EggPart: Double]] = [:]
    @State private var defaultEggSize: EggSize = .large
    @State private var showingResetAllConfirmation = false
    @State private var addingToGroup: IngredientCategoryGroup? = nil
    @State private var customEntries: [IngredientConversionStore.ConversionEntry] = []
    @State private var hiddenCategories: Set<IngredientCategory> = []

    private func customEntries(for group: IngredientCategoryGroup) -> [IngredientConversionStore.ConversionEntry] {
        customEntries.filter { $0.group == group }
    }

    private var ungroupedCustomEntries: [IngredientConversionStore.ConversionEntry] {
        customEntries.filter { $0.group == nil }
    }

    var body: some View {
        Form {
            ForEach(IngredientCategoryGroup.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(categories(in: group)) { category in
                        row(for: category)
                    }
                    ForEach(customEntries(for: group)) { entry in
                        customEntryRow(entry)
                    }
                    Button {
                        addingToGroup = group
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle")
                    }
                }
                if group == .salts {
                    eggsSection
                }
            }

            if !ungroupedCustomEntries.isEmpty {
                Section("Custom Ingredients") {
                    ForEach(ungroupedCustomEntries) { entry in
                        customEntryRow(entry)
                    }
                }
            }

            Section {
                Button("Reset All to Defaults", role: .destructive) {
                    showingResetAllConfirmation = true
                }
                .accessibilityIdentifier("resetAllConversionsButton")
                .confirmationDialog("Reset All to Defaults?", isPresented: $showingResetAllConfirmation, titleVisibility: .visible) {
                    Button("Reset All to Defaults", role: .destructive) {
                        store.resetAllToDefaults()
                        loadValues()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This replaces every value below with Doughy's default for that ingredient.")
                }
            } footer: {
                Text("Doughy uses these values to convert cup, tablespoon, and teaspoon measurements to grams when scanning recipes. Adjust them if your results consistently run heavy or light - ingredient density varies with humidity, brand, and how it's measured.")
            }
        }
        .navigationTitle("Ingredient Conversions")
        .onAppear {
            loadValues()
            customEntries = conversionStore.allEntries()
            hiddenCategories = store.hiddenCategories()
        }
        .sheet(item: $addingToGroup) { group in
            AddConversionSheet { name, unit, grams in
                conversionStore.save(name: name, unit: unit, gramsPerUnit: grams, group: group)
                customEntries = conversionStore.allEntries()
            }
        }
    }

    @ViewBuilder
    private func customEntryRow(_ entry: IngredientConversionStore.ConversionEntry) -> some View {
        HStack {
            Text(entry.name.capitalized)
            Spacer()
            TextField("", value: customEntryBinding(for: entry), format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(width: 70)
            Text(shortUnitLabel(for: entry.unit))
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                conversionStore.delete(name: entry.name, unit: entry.unit)
                customEntries = conversionStore.allEntries()
            }
        }
    }

    private func customEntryBinding(for entry: IngredientConversionStore.ConversionEntry) -> Binding<Double> {
        Binding(
            get: { entry.gramsPerUnit },
            set: { newValue in
                conversionStore.save(name: entry.name, unit: entry.unit, gramsPerUnit: newValue, group: entry.group)
                customEntries = conversionStore.allEntries()
            }
        )
    }

    private func shortUnitLabel(for unit: String) -> String {
        DensityUnit(rawValue: unit)?.label ?? "g/\(unit)"
    }

    private func categories(in group: IngredientCategoryGroup) -> [IngredientCategory] {
        IngredientCategory.allCases.filter { $0.group == group && !hiddenCategories.contains($0) }
    }

    @ViewBuilder
    private func row(for category: IngredientCategory) -> some View {
        HStack {
            Text(category.displayName)
            Spacer()
            TextField(
                "",
                value: binding(for: category),
                format: .number.precision(.fractionLength(0...2))
            )
            .multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad)
            .frame(width: 70)
            .accessibilityIdentifier("gramsPerCupField_\(category.rawValue)")

            Menu {
                ForEach(DensityUnit.allCases) { unit in
                    Button(unit.label) {
                        displayUnits[category] = unit
                        store.setDisplayUnit(unit, for: category)
                    }
                }
            } label: {
                Text(unit(for: category).label)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("unitMenu_\(category.rawValue)")
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                store.hide(category: category)
                hiddenCategories = store.hiddenCategories()
            }
            if store.isCustomized(category) {
                Button("Reset") {
                    store.resetToDefault(for: category)
                    values[category] = category.defaultGramsPerCup
                }
                .tint(.blue)
            }
        }
    }

    private var eggsSection: some View {
        Section {
            Picker("Default Egg Size", selection: $defaultEggSize) {
                ForEach(EggSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .accessibilityIdentifier("defaultEggSizePicker")
            .onChange(of: defaultEggSize) { _, newValue in
                store.setDefaultEggSize(newValue)
            }

            ForEach(EggSize.allCases) { size in
                ForEach(EggPart.allCases) { part in
                    eggRow(for: size, part: part)
                }
            }
        } header: {
            Text("Eggs")
        } footer: {
            Text("Eggs are measured by count rather than volume. These weights convert quantities like “2 large eggs” or “3 large egg whites” to grams. Whole-egg weights are for the egg out of its shell (white plus yolk); separated white and yolk weights vary more. If a recipe doesn’t specify a size, the default size above is assumed.")
        }
    }

    @ViewBuilder
    private func eggRow(for size: EggSize, part: EggPart) -> some View {
        HStack {
            Text("\(size.displayName) \(part.displayName)")
            Spacer()
            TextField(
                "",
                value: eggBinding(for: size, part: part),
                format: .number.precision(.fractionLength(0...2))
            )
            .multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad)
            .frame(width: 70)
            .accessibilityIdentifier("eggGramsField_\(size.rawValue)_\(part.rawValue)")

            Text("g")
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .trailing) {
            if store.isCustomized(size, part: part) {
                Button("Reset") {
                    store.resetToDefault(for: size, part: part)
                    eggValues[size, default: [:]][part] = size.defaultGrams(for: part)
                }
                .tint(.blue)
            }
        }
    }

    private func eggBinding(for size: EggSize, part: EggPart) -> Binding<Double> {
        Binding(
            get: { eggValues[size]?[part] ?? size.defaultGrams(for: part) },
            set: { newValue in
                eggValues[size, default: [:]][part] = newValue
                store.setGramsPerEgg(newValue, for: size, part: part)
            }
        )
    }

    private func unit(for category: IngredientCategory) -> DensityUnit {
        displayUnits[category] ?? .cup
    }

    /// The density for `category`, converted from the canonical grams-per-cup
    /// storage into its current display unit (e.g. grams per tablespoon).
    private func binding(for category: IngredientCategory) -> Binding<Double> {
        let unit = unit(for: category)
        return Binding(
            get: { (values[category] ?? category.defaultGramsPerCup) / unit.unitsPerCup },
            set: { newValue in
                let gramsPerCup = newValue * unit.unitsPerCup
                values[category] = gramsPerCup
                store.setGramsPerCup(gramsPerCup, for: category)
            }
        )
    }

    private func loadValues() {
        values = Dictionary(uniqueKeysWithValues: IngredientCategory.allCases.map { ($0, store.gramsPerCup(for: $0)) })
        displayUnits = Dictionary(uniqueKeysWithValues: IngredientCategory.allCases.map { ($0, store.displayUnit(for: $0)) })
        eggValues = Dictionary(uniqueKeysWithValues: EggSize.allCases.map { size in
            (size, Dictionary(uniqueKeysWithValues: EggPart.allCases.map { part in
                (part, store.gramsPerEgg(for: size, part: part))
            }))
        })
        defaultEggSize = store.defaultEggSize()
        hiddenCategories = store.hiddenCategories()
    }
}

private struct AddConversionSheet: View {
    let onSave: (String, String, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var unit = "tablespoon"
    @State private var gramsPerUnit: Double? = nil
    @FocusState private var isNameFocused: Bool

    private let units = ["teaspoon", "tablespoon", "cup", "ounce", "milliliter"]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (gramsPerUnit ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                        .focused($isNameFocused)
                }
                Section {
                    Picker("Unit", selection: $unit) {
                        ForEach(units, id: \.self) { u in
                            Text(VolumeUnitFormatter.label(unit: u, amount: 1).capitalized).tag(u)
                        }
                    }
                    HStack {
                        Text("Grams per \(VolumeUnitFormatter.label(unit: unit, amount: 1))")
                        Spacer()
                        TextField("0", value: $gramsPerUnit, format: .number.precision(.fractionLength(0...2)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 70)
                        Text("g").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Conversion")
                } footer: {
                    Text("Enter how many grams are in one \(VolumeUnitFormatter.label(unit: unit, amount: 1)) of this ingredient.")
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let g = gramsPerUnit, isValid {
                            onSave(name.trimmingCharacters(in: .whitespaces), unit, g)
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear { isNameFocused = true }
        }
    }
}
