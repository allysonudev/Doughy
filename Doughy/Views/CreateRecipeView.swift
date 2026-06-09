//
//  CreateRecipeView.swift
//  Doughy

import SwiftUI

// MARK: - Local data models

private struct FlourRow: Identifiable {
    var id = UUID()
    var name: String = ""
    var percent: Double? = nil
}

private struct IngredientRow: Identifiable {
    var id = UUID()
    var name: String = ""
    var mode: IngredientMeasurementMode = .percent
    var percent: Double? = nil
    var weight: Double? = nil
    var tempValue: Double? = nil
}

private struct PrefIngRow: Identifiable {
    var id = UUID()
    var name: String
    var isFlour: Bool
    var included: Bool = false
    var weight: Double? = nil
}

private enum CreateStep: Hashable {
    case flours
    case ingredients
    case preferment
    case instructions
    case preview
}

// MARK: - Main view

struct CreateRecipeView: View {
    let editingRecipe: (any RecipeProtocol)?

    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var navPath: [CreateStep] = []

    // Step 1 - Details
    @State private var recipeName: String = ""
    @State private var collectionName: String = ""
    @State private var isNewCollection: Bool = false
    @State private var newCollectionText: String = ""
    @State private var defaultWeight: Double? = nil
    @State private var containsPreferment: Bool = false

    // Step 2 - Flours
    @State private var flours: [FlourRow] = [FlourRow()]

    // Step 3 - Ingredients
    @State private var ingredients: [IngredientRow] = [IngredientRow()]

    // Step 4 - Preferment
    @State private var prefermentName: String = ""
    @State private var prefermentFlourPercent: Double? = nil
    @State private var prefermentIngredients: [PrefIngRow] = []

    // Step 5 - Instructions
    @State private var instructions: [String] = []

    // Misc
    @State private var saveError: String? = nil

    init(editingRecipe: (any RecipeProtocol)? = nil) {
        self.editingRecipe = editingRecipe
        guard let recipe = editingRecipe else { return }

        _recipeName = State(initialValue: recipe.name)
        _collectionName = State(initialValue: recipe.collection)
        _defaultWeight = State(initialValue: recipe.defaultWeight)
        _instructions = State(initialValue: recipe.instructions.map(\.step))

        let flourRows = recipe.ingredients
            .filter(\.isFlour)
            .map { FlourRow(name: $0.name, percent: $0.defaultPercentage) }
        _flours = State(initialValue: flourRows.isEmpty ? [FlourRow()] : flourRows)

        let ingRows = recipe.ingredients
            .filter { !$0.isFlour }
            .map { IngredientRow(name: $0.name, mode: .percent, percent: $0.defaultPercentage, tempValue: $0.temperature?.value) }
        _ingredients = State(initialValue: ingRows.isEmpty ? [IngredientRow()] : ingRows)

        if let prefRecipe = recipe as? PrefermentRecipe {
            _containsPreferment = State(initialValue: true)
            _prefermentName = State(initialValue: prefRecipe.preferment.name)
            _prefermentFlourPercent = State(initialValue: prefRecipe.preferment.flourPercentage)

            let prefRows = prefRecipe.preferment.ingredients.map { ing in
                PrefIngRow(name: ing.name, isFlour: ing.isFlour, included: true, weight: nil)
            }
            _prefermentIngredients = State(initialValue: prefRows)
        }
    }

    private var effectiveCollection: String {
        isNewCollection ? newCollectionText : collectionName
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            detailsForm
                .navigationDestination(for: CreateStep.self) { step in
                    switch step {
                    case .flours:      floursForm
                    case .ingredients: ingredientsForm
                    case .preferment:  prefermentForm
                    case .instructions: instructionsForm
                    case .preview:     previewForm
                    }
                }
        }
        .alert("Save Error", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Step 1: Details

    private var detailsForm: some View {
        let collections = store.collectionNames

        return Form {
            Section("Recipe") {
                TextField("Name", text: $recipeName)
                    .autocorrectionDisabled()
            }

            Section("Collection") {
                if !collections.isEmpty && !isNewCollection {
                    Picker("Collection", selection: $collectionName) {
                        ForEach(collections, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .onAppear {
                        if collectionName.isEmpty, let first = collections.first {
                            collectionName = first
                        }
                    }
                }
                Toggle("New Collection", isOn: $isNewCollection.animation())
                if isNewCollection {
                    TextField("Collection Name", text: $newCollectionText)
                        .autocorrectionDisabled()
                }
            }

            Section("Weight") {
                HStack {
                    Text("Default Dough Weight")
                    Spacer()
                    TextField("500", value: $defaultWeight, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    Text("g").foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Include Preferment", isOn: $containsPreferment)
            } footer: {
                Text("A preferment (biga, poolish, etc.) is a portion of the dough fermented separately.")
            }
        }
        .navigationTitle(editingRecipe != nil ? "Edit Recipe" : "New Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") { navPath.append(.flours) }
                    .disabled(!detailsReady)
            }
        }
    }

    private var detailsReady: Bool {
        !recipeName.trimmingCharacters(in: .whitespaces).isEmpty
            && !(isNewCollection ? newCollectionText.trimmingCharacters(in: .whitespaces).isEmpty : collectionName.isEmpty)
            && defaultWeight != nil && (defaultWeight ?? 0) > 0
    }

    // MARK: - Step 2: Flours

    private var floursForm: some View {
        let flourSum = flours.compactMap(\.percent).reduce(0, +)

        return Form {
            Section {
                ForEach($flours) { $flour in
                    HStack {
                        TextField("Flour Name", text: $flour.name)
                            .autocorrectionDisabled()
                        Spacer()
                        TextField("0", value: $flour.percent, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("%").foregroundStyle(.secondary)
                    }
                }
                .onDelete { indices in flours.remove(atOffsets: indices) }
                Button { flours.append(FlourRow()) } label: {
                    Label("Add Flour", systemImage: "plus.circle")
                }
            } header: {
                Text("Flours")
            } footer: {
                let diff = 100.0 - flourSum
                if flours.compactMap(\.percent).isEmpty {
                    Text("Flour percentages must add up to 100%.")
                } else if diff != 0 {
                    Text(String(format: "%.4g%% remaining (needs to total 100%%)", diff))
                        .foregroundStyle(diff < 0 ? .red : .orange)
                } else {
                    Text("Flour percentages total 100%. ✓").foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Flours")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") { navPath.append(.ingredients) }
                    .disabled(!floursReady)
            }
        }
    }

    private var floursReady: Bool {
        let ready = flours.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.percent != nil }
        let sum = flours.compactMap(\.percent).reduce(0, +)
        return ready && !flours.isEmpty && abs(sum - 100) < 0.001
    }

    // MARK: - Step 3: Ingredients

    private var ingredientsForm: some View {
        let useCelsius = Settings.shared.preferredTemp() == .celsius

        return Form {
            ForEach($ingredients) { $ing in
                Section {
                    TextField("Ingredient Name", text: $ing.name)
                        .autocorrectionDisabled()

                    Picker("Measurement", selection: $ing.mode) {
                        Text("Percent").tag(IngredientMeasurementMode.percent)
                        Text("Weight").tag(IngredientMeasurementMode.weight)
                    }
                    .pickerStyle(.segmented)

                    if ing.mode == .percent {
                        HStack {
                            Text("Percentage")
                            Spacer()
                            TextField("0", value: $ing.percent, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                            Text("%").foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("0", value: $ing.weight, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                            Text("g").foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Temperature (optional)")
                        Spacer()
                        TextField("–", value: $ing.tempValue, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                        Text("°\(useCelsius ? "C" : "F")").foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indices in ingredients.remove(atOffsets: indices) }

            Section {
                Button { ingredients.append(IngredientRow()) } label: {
                    Label("Add Ingredient", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Ingredients")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") {
                    syncPrefermentIngredients()
                    navPath.append(containsPreferment ? .preferment : .instructions)
                }
                .disabled(!ingredientsReady)
            }
        }
    }

    private var ingredientsReady: Bool {
        !ingredients.isEmpty && ingredients.allSatisfy { ing in
            !ing.name.trimmingCharacters(in: .whitespaces).isEmpty
                && (ing.mode == .percent ? ing.percent != nil : ing.weight != nil)
        }
    }

    private func syncPrefermentIngredients() {
        guard containsPreferment else { return }
        var merged: [PrefIngRow] = []
        for flour in flours where !flour.name.isEmpty {
            if let existing = prefermentIngredients.first(where: { $0.name == flour.name && $0.isFlour }) {
                merged.append(existing)
            } else {
                merged.append(PrefIngRow(name: flour.name, isFlour: true))
            }
        }
        for ing in ingredients where !ing.name.isEmpty {
            if let existing = prefermentIngredients.first(where: { $0.name == ing.name && !$0.isFlour }) {
                merged.append(existing)
            } else {
                merged.append(PrefIngRow(name: ing.name, isFlour: false))
            }
        }
        prefermentIngredients = merged
    }

    // MARK: - Step 4: Preferment

    private var prefermentForm: some View {
        let useCelsius = Settings.shared.preferredTemp() == .celsius

        return Form {
            Section("Preferment Details") {
                TextField("Preferment Name (e.g. Biga)", text: $prefermentName)
                    .autocorrectionDisabled()
                HStack {
                    Text("% of Total Flour")
                    Spacer()
                    TextField("0", value: $prefermentFlourPercent, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                    Text("%").foregroundStyle(.secondary)
                }
            }

            Section("Include in Preferment") {
                ForEach($prefermentIngredients) { $row in
                    HStack {
                        Toggle(isOn: $row.included) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                Text(row.isFlour ? "Flour" : "Ingredient")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if row.included {
                        HStack {
                            Text("Weight in Preferment")
                            Spacer()
                            TextField("0", value: $row.weight, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                            Text("g").foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .navigationTitle("Preferment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") { navPath.append(.instructions) }
                    .disabled(!prefermentReady)
            }
        }
    }

    private var prefermentReady: Bool {
        !prefermentName.trimmingCharacters(in: .whitespaces).isEmpty
            && prefermentFlourPercent != nil
            && (prefermentFlourPercent ?? 0) > 0
            && prefermentIngredients.filter(\.included).allSatisfy { $0.weight != nil }
            && !prefermentIngredients.filter(\.included).isEmpty
    }

    // MARK: - Step 5: Instructions

    @State private var newStepText: String = ""

    private var instructionsForm: some View {
        Form {
            Section {
                ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).").foregroundStyle(.secondary)
                        Text(step)
                    }
                }
                .onDelete { indices in instructions.remove(atOffsets: indices) }
                .onMove { source, destination in instructions.move(fromOffsets: source, toOffset: destination) }
            } header: {
                Text("Steps")
            } footer: {
                Text("Swipe to delete, drag to reorder.")
            }

            Section("Add Step") {
                TextField("Step description", text: $newStepText, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                Button("Add Step") {
                    let trimmed = newStepText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        instructions.append(trimmed)
                        newStepText = ""
                    }
                }
                .disabled(newStepText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Instructions")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") { navPath.append(.preview) }
            }
        }
    }

    // MARK: - Step 6: Preview + Save

    private var previewForm: some View {
        Form {
            Section("Details") {
                LabeledContent("Name", value: recipeName)
                LabeledContent("Collection", value: effectiveCollection)
                LabeledContent("Default Weight", value: "\(Int(defaultWeight ?? 0))g")
                if containsPreferment { LabeledContent("Preferment", value: prefermentName) }
            }

            Section("Flours") {
                ForEach(flours.filter { !$0.name.isEmpty }, id: \.id) { flour in
                    LabeledContent(flour.name, value: "\(Int(flour.percent ?? 0))%")
                }
            }

            Section("Ingredients") {
                ForEach(ingredients.filter { !$0.name.isEmpty }, id: \.id) { ing in
                    if ing.mode == .percent {
                        LabeledContent(ing.name, value: "\(Int(ing.percent ?? 0))%")
                    } else {
                        LabeledContent(ing.name, value: "\(Int(ing.weight ?? 0))g")
                    }
                }
            }

            if containsPreferment && !prefermentIngredients.filter(\.included).isEmpty {
                Section("Preferment Ingredients") {
                    LabeledContent("Flour of Total", value: "\(Int(prefermentFlourPercent ?? 0))%")
                    ForEach(prefermentIngredients.filter(\.included), id: \.id) { ing in
                        LabeledContent(ing.name, value: "\(Int(ing.weight ?? 0))g")
                    }
                }
            }

            if !instructions.isEmpty {
                Section("Instructions") {
                    ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).").foregroundStyle(.secondary)
                            Text(step)
                        }
                    }
                }
            }

            Section {
                Button {
                    saveRecipe()
                } label: {
                    HStack {
                        Spacer()
                        Text(editingRecipe != nil ? "Save Changes" : "Save Recipe")
                            .bold()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Save logic

    private func saveRecipe() {
        do {
            let recipe = try buildRecipe()
            if let existingName = editingRecipe?.name, let existingCollection = editingRecipe?.collection {
                try store.update(recipe: recipe, existingName: existingName, existingCollection: existingCollection)
            } else {
                try store.save(recipe: recipe)
            }
            dismiss()
        } catch RecipeBuilderError.missingName {
            saveError = "Recipe name is missing."
        } catch RecipeBuilderError.missingCollection {
            saveError = "Collection name is missing."
        } catch RecipeBuilderError.missingDefaultWeight {
            saveError = "Default weight is missing."
        } catch RecipeBuilderError.invalidIngredients {
            saveError = "One or more ingredients are invalid. Please review your recipe."
        } catch RecipeBuilderError.mainDoughLessThanPreferment(let main, let pref) {
            saveError = "\(main.name) in the main dough must be at least as much as in the preferment (\(pref.name))."
        } catch RecipeBuilderError.mainDoughMissingPreferment(let ing) {
            saveError = "Preferment ingredient \"\(ing.name)\" is not in the main dough."
        } catch {
            saveError = "Failed to save recipe: \(error.localizedDescription)"
        }
    }

    private func buildRecipe() throws -> any RecipeProtocol {
        let builder = RecipeBuilder()
        builder.name = recipeName.trimmingCharacters(in: .whitespaces)
        builder.collection = effectiveCollection.trimmingCharacters(in: .whitespaces)
        builder.defaultWeight = defaultWeight
        builder.instructions = instructions.map { Instruction(step: $0) }
        builder.containsPreferment = containsPreferment

        builder.mainDoughBuilder = MainDoughBuilder()

        for flour in flours where !flour.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let fb = FlourBuilder()
            fb.name = flour.name.trimmingCharacters(in: .whitespaces)
            fb.percent = flour.percent
            builder.mainDoughBuilder.flourBuilders.append(fb)
        }

        let tempMeasurement = Settings.shared.preferredTemp()
        for ing in ingredients where !ing.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let ib = IngredientBuilder()
            ib.name = ing.name.trimmingCharacters(in: .whitespaces)
            ib.mode = ing.mode
            ib.percent = ing.percent
            ib.weight = ing.weight
            if let tv = ing.tempValue {
                ib.temperature = Temperature(value: tv, measurement: tempMeasurement)
            }
            builder.mainDoughBuilder.ingredientBuilders.append(ib)
        }

        if containsPreferment {
            builder.prefermentBuilder.name = prefermentName.trimmingCharacters(in: .whitespaces)
            builder.prefermentBuilder.totalFlourPercent = prefermentFlourPercent

            for prefIng in prefermentIngredients where prefIng.included {
                let pb = PrefermentIngredientBuilder(isFlour: prefIng.isFlour)
                pb.name = prefIng.name
                pb.weight = prefIng.weight
                if prefIng.isFlour {
                    builder.prefermentBuilder.flourBuilders.append(pb)
                } else {
                    builder.prefermentBuilder.ingredientBuilders.append(pb)
                }
            }
        }

        return try builder.build()
    }
}
