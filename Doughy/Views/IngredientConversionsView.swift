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

    @State private var values: [IngredientCategory: Double] = [:]
    @State private var displayUnits: [IngredientCategory: DensityUnit] = [:]
    @State private var eggValues: [EggSize: [EggPart: Double]] = [:]
    @State private var defaultEggSize: EggSize = .large
    @State private var showingResetAllConfirmation = false

    var body: some View {
        Form {
            ForEach(IngredientCategoryGroup.allCases, id: \.self) { group in
                Section(group.rawValue) {
                    ForEach(categories(in: group)) { category in
                        row(for: category)
                    }
                }
                if group == .salts {
                    eggsSection
                }
            }

            Section {
                Button("Reset All to Defaults", role: .destructive) {
                    showingResetAllConfirmation = true
                }
                .accessibilityIdentifier("resetAllConversionsButton")
            } footer: {
                Text("Doughy uses these values to convert cup, tablespoon, and teaspoon measurements to grams when scanning recipes. Adjust them if your results consistently run heavy or light - ingredient density varies with humidity, brand, and how it's measured.")
            }
        }
        .navigationTitle("Ingredient Conversions")
        .onAppear {
            loadValues()
        }
        .confirmationDialog("Reset All to Defaults?", isPresented: $showingResetAllConfirmation, titleVisibility: .visible) {
            Button("Reset All to Defaults", role: .destructive) {
                store.resetAllToDefaults()
                loadValues()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This replaces every value below with Doughy's default for that ingredient.")
        }
    }

    private func categories(in group: IngredientCategoryGroup) -> [IngredientCategory] {
        IngredientCategory.allCases.filter { $0.group == group }
    }

    @ViewBuilder
    private func row(for category: IngredientCategory) -> some View {
        HStack {
            Text(category.displayName)
            Spacer()
            TextField(
                "",
                value: binding(for: category),
                format: .number
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
                format: .number
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
    }
}
