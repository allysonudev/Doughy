//
//  CreateRecipeView+StepsIngredients.swift
//  Doughy
//

import SwiftUI
import PhotosUI
import UIKit
import NaturalLanguage
#if canImport(VisionKit)
import VisionKit
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif

extension CreateRecipeView {
    // MARK: - Step 1: Details

    var detailsFormContent: some View {
        let collections = store.collectionNames
        return Form {
            Section {
                TextField("Name", text: $recipeName)
                    .autocorrectionDisabled()
                    .focused($isRecipeNameFocused)
                    .accessibilityIdentifier("recipeNameField")
            } header: {
                Text("Recipe")
            } footer: {
                if let lang = detectedRecipeLanguage {
                    Label(String(format: String(localized: "scan.detected_language", defaultValue: "Recipe detected in %@. Ingredient names have been translated."), lang), systemImage: "globe")
                        .font(.footnote)
                }
            }

            Section("Collection") {
                if !collections.isEmpty && !isNewCollection {
                    Picker("Collection", selection: $collectionName) {
                        ForEach(collections, id: \.self) { Text(DefaultLocalization.collectionName($0)).tag($0) }
                    }
                    .accessibilityIdentifier("collectionPicker")
                    .onAppear {
                        if collectionName.isEmpty, let fallback = collections.first {
                            collectionName = fallback
                            // This is an automatic default, not a user edit — update the
                            // baseline so it doesn't trip the discard-changes safeguard.
                            initialSnapshot.collectionName = fallback
                        } else if !collectionName.isEmpty, !collections.contains(collectionName), let fallback = collections.first {
                            collectionName = fallback
                            initialSnapshot.collectionName = fallback
                        }
                    }
                }
                Toggle("New Collection", isOn: $isNewCollection.animation())
                    .accessibilityIdentifier("newCollectionToggle")
                    .onChange(of: isNewCollection) { _, newValue in
                        if newValue {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(150))
                                isNewCollectionFocused = true
                            }
                        }
                    }
                if isNewCollection {
                    TextField("Collection Name", text: $newCollectionText)
                        .autocorrectionDisabled()
                        .focused($isNewCollectionFocused)
                        .accessibilityIdentifier("newCollectionNameField")
                }

                CollectionAppearanceEditor(
                    collection: effectiveCollection,
                    iconKey: $collectionIconKey,
                    colorKey: $collectionColorKey
                )
            }
            .onAppear { syncCollectionAppearanceIfNeeded() }
            .onChange(of: collectionName) { _, _ in
                if !isNewCollection { syncCollectionAppearance() }
            }
            .onChange(of: isNewCollection) { _, isNew in
                if isNew {
                    collectionIconKey = nil
                    collectionColorKey = nil
                } else {
                    syncCollectionAppearance()
                }
            }

            if inputMode == .byPercent {
                Section("Weight") {
                    HStack {
                        Text("Default Dough Weight")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("500", value: $defaultWeight, format: FlexibleDecimalStyle(fractionDigits: 0...2))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .accessibilityIdentifier("defaultWeightField")
                                .accessibilityLabel("Default dough weight in grams")
                            Text(String(localized: "unit.grams.short", defaultValue: "g")).foregroundStyle(.secondary)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }

            Section {
                Toggle("Include Preferment", isOn: $containsPreferment)
                    .accessibilityIdentifier("containsPrefermentToggle")
            } footer: {
                Text("A preferment (biga, poolish, etc.) is a portion of the dough fermented separately.")
            }
        }
    }

    var detailsForm: some View {
        detailsFormContent
        .onAppear {
            guard editingRecipe != nil || copyingRecipe != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                isRecipeNameFocused = true
            }
        }
        .navigationTitle(editingRecipe != nil
                         ? String(localized: "create.title.edit", defaultValue: "Edit Recipe")
                         : copyingRecipe != nil
                         ? String(localized: "create.title.copy", defaultValue: "Copy Recipe")
                         : String(localized: "create.title.new", defaultValue: "New Recipe"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if editingRecipe != nil || copyingRecipe != nil {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                        .accessibilityIdentifier("detailsCancelButton")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") {
                    navPath.append(containsPreferment ? .preferment : .ingredients)
                }
                .disabled(!detailsReady)
                .accessibilityIdentifier("detailsNextButton")
            }
        }
        .keyboardDismissible()
    }

    var detailsReady: Bool {
        !recipeName.trimmingCharacters(in: .whitespaces).isEmpty
            && !(isNewCollection
                 ? newCollectionText.trimmingCharacters(in: .whitespaces).isEmpty
                 : collectionName.isEmpty)
            && (inputMode == .byWeight || (defaultWeight != nil && (defaultWeight ?? 0) > 0))
    }

    // MARK: - Step 2: Ingredients (flours + other, combined)

    /// Units offered when switching the unit of an "extra" ingredient (one that's
    /// measured by volume/count rather than converted to grams).
    var extraIngredientUnits: [String] {
        switch Settings.shared.preferredVolumeSystem() {
        case .metric:   return ["milliliter", "deciliter", "liter", "count"]
        case .imperial: return ["teaspoon", "tablespoon", "cup", "fluidOunce", "ounce", "count"]
        }
    }

    static let seededFlourSuggestions: [String] =
        IngredientCategory.allCases
            .filter { $0.group == .flours }
            .map(\.localizedDisplayName)

    static let seededIngredientSuggestions: [String] = {
        var names = IngredientCategory.allCases
            .filter { $0.group != .flours }
            .map(\.localizedDisplayName)
        let eggVariants = [
            String(localized: "egg.noun.whole.many", defaultValue: "eggs"),
            String(localized: "egg.noun.white.many", defaultValue: "egg whites"),
            String(localized: "egg.noun.yolk.many",  defaultValue: "egg yolks"),
        ]
        for variant in eggVariants {
            EggSize.allCases.forEach { names.append("\($0.localizedDisplayName) \(variant)") }
        }
        return names
    }()

    var allFlourSuggestions: [String] {
        suggestionsSorted(isFlour: true)
    }

    var allIngredientSuggestions: [String] {
        suggestionsSorted(isFlour: false)
    }

    /// Builds the suggestion list for flour or ingredient name fields.
    /// Names used in the chosen collection are ranked by how often they appear there;
    /// names from other collections and static seeds follow at count 0.
    /// Within the same count, names are sorted alphabetically.
    func suggestionsSorted(isFlour: Bool) -> [String] {
        let target: String? = isNewCollection ? nil : (collectionName.isEmpty ? nil : collectionName)
        var counts: [String: Int] = [:]
        for collection in store.collections {
            let inTarget = target.map { $0 == collection.name } ?? true
            for recipe in collection.recipes {
                for ingredient in recipe.ingredients where ingredient.isFlour == isFlour {
                    if counts[ingredient.name] == nil { counts[ingredient.name] = 0 }
                    if inTarget { counts[ingredient.name, default: 0] += 1 }
                }
            }
        }
        let seeds = isFlour ? Self.seededFlourSuggestions : Self.seededIngredientSuggestions
        for seed in seeds where counts[seed] == nil { counts[seed] = 0 }
        for entry in IngredientConversionStore.shared.allEntries() {
            let entryIsFlour = entry.group == .flours
            if entryIsFlour == isFlour, counts[entry.name] == nil { counts[entry.name] = 0 }
        }
        return counts.keys.sorted { a, b in
            let ca = counts[a, default: 0], cb = counts[b, default: 0]
            return ca != cb ? ca > cb : a < b
        }
    }

    var ingredientsFormContent: some View {
        let useCelsius = Settings.shared.preferredTemp() == .celsius
        let isPercent = inputMode == .byPercent

        return Form {
            Section {
                ForEach(Array(flours.enumerated()), id: \.element.id) { index, _ in
                    HStack(alignment: .top) {
                        IngredientNameField(placeholder: String(localized: "create.flour_name", defaultValue: "Flour Name"), text: $flours[index].name,
                                            suggestions: allFlourSuggestions,
                                            accessibilityID: "flourNameField_\(index)",
                                            rowID: flours[index].id,
                                            focusedRowID: $focusedRowID,
                                            pendingValueRowID: $pendingValueRowID,
                                            exclude: Set(flours.map { $0.name.lowercased() }.filter { !$0.isEmpty }))
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", value: $flours[index].value, format: FlexibleDecimalStyle(fractionDigits: 0...4))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                                .accessibilityIdentifier("flourValueField_\(index)")
                                .accessibilityLabel("\(flours[index].name.isEmpty ? String(localized: "create.flour_label", defaultValue: "Flour") : flours[index].name), \(isPercent ? String(localized: "accessibility.percentage", defaultValue: "percentage") : String(localized: "accessibility.grams", defaultValue: "grams"))")
                                .focused($focusedValueRowID, equals: flours[index].id)
                            Text(isPercent ? "%" : String(localized: "unit.grams.short", defaultValue: "g")).foregroundStyle(.secondary)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .onDelete { offsets in
                    flours.remove(atOffsets: offsets)
                    renormalizeFlourPercentages()
                }
                Button {
                    let row = FlourRow()
                    flours.append(row)
                    focusedRowID = row.id
                } label: {
                    Label("Add Flour", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("addFlourButton")
            } header: {
                Text(String(localized: "density.group.flours", defaultValue: "Flours"))
            } footer: {
                if containsPreferment {
                    let prefermentLabel = prefermentName.isEmpty ? "preferment" : prefermentName
                    if isPercent {
                        let sum = combinedFlours.compactMap(\.value).reduce(0, +)
                        let diff = 100.0 - sum
                        if abs(diff) > 0.001 {
                            Text(String(
                                format: String(localized: "create.flours.footer.preferment_percent_remaining", defaultValue: "Enter any additional flour used in the main dough, on top of what's in the %@. Combined with the preferment, flour percentages must total 100%% (%.4g%% remaining)."),
                                prefermentLabel,
                                diff
                            ))
                                .foregroundStyle(diff < 0 ? .red : .orange)
                        } else {
                            Text("Combined flour percentages total 100%. ✓").foregroundStyle(.green)
                        }
                    } else {
                        Text(String(
                            format: String(localized: "create.flours.footer.preferment_weight", defaultValue: "Enter any additional flour used in the main dough, on top of what's in the %@. Leave at 0 (or remove) if all the flour is in the preferment."),
                            prefermentLabel
                        ))
                    }
                } else if isPercent {
                    let sum = flours.compactMap(\.value).reduce(0, +)
                    let diff = 100.0 - sum
                    if flours.compactMap(\.value).isEmpty {
                        Text("Flour percentages must add up to 100%.")
                    } else if abs(diff) > 0.001 {
                        Text(String(format: String(localized: "create.flours.main.percent_remaining", defaultValue: "%.4g%% remaining to reach 100%%"), diff))
                            .foregroundStyle(diff < 0 ? .red : .orange)
                    } else {
                        Text("Flour percentages total 100%. ✓").foregroundStyle(.green)
                    }
                }
            }

            Section {
                ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, _ in
                    HStack(alignment: .top) {
                        IngredientNameField(placeholder: String(localized: "create.ingredient_name", defaultValue: "Ingredient Name"), text: $ingredients[index].name,
                                            suggestions: allIngredientSuggestions,
                                            accessibilityID: "ingredientNameField_\(index)",
                                            rowID: ingredients[index].id,
                                            focusedRowID: $focusedRowID,
                                            pendingValueRowID: $pendingValueRowID,
                                            exclude: Set(ingredients.map { $0.name.lowercased() }.filter { !$0.isEmpty }))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                TextField("0", value: $ingredients[index].value, format: FlexibleDecimalStyle(fractionDigits: 0...4))
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 70)
                                    .accessibilityIdentifier("ingredientValueField_\(index)")
                                    .accessibilityLabel("\(ingredients[index].name.isEmpty ? String(localized: "create.ingredient_label", defaultValue: "Ingredient") : ingredients[index].name), \(isPercent ? String(localized: "accessibility.percentage", defaultValue: "percentage") : String(localized: "accessibility.grams", defaultValue: "grams"))")
                                    .focused($focusedValueRowID, equals: ingredients[index].id)
                                Text(isPercent ? "%" : String(localized: "unit.grams.short", defaultValue: "g")).foregroundStyle(.secondary)
                            }
                            if isPercent && containsPreferment {
                                let name = ingredients[index].name
                                let prefVal = prefermentIngredientRows
                                    .first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
                                if let prefVal, prefVal > 0.001, !name.isEmpty {
                                    let combined = prefermentContribution(prefVal) + (ingredients[index].value ?? 0)
                                    Text(String(format: String(localized: "create.ingredients.percent_total", defaultValue: "%@ total"), PercentFormatter.shared.format(percent: combined)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                    HStack {
                        Text("Temperature (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("–", value: $ingredients[index].tempValue, format: FlexibleDecimalStyle(fractionDigits: 0...1))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 60)
                                .focused($focusedTempRowID, equals: ingredients[index].id)
                                .accessibilityIdentifier("ingredientTempField_\(index)")
                                .accessibilityLabel("\(ingredients[index].name.isEmpty ? "Ingredient" : ingredients[index].name) temperature in \(TemperatureFormatter.shared.unitSymbol(useCelsius: useCelsius))")
                            Text(TemperatureFormatter.shared.unitSymbol(useCelsius: useCelsius)).foregroundStyle(.secondary)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { focusedTempRowID = ingredients[index].id }
                }
                .onDelete { ingredients.remove(atOffsets: $0) }
                Button { showingAddIngredientDialog = true } label: {
                    Label(String(localized: "action.add_ingredient", defaultValue: "Add Ingredient"), systemImage: "plus.circle")
                }
                .accessibilityIdentifier("addIngredientButton")
                .confirmationDialog(LocalizedStringKey("action.add_ingredient"), isPresented: $showingAddIngredientDialog, titleVisibility: .visible) {
                    Button(isPercent
                           ? String(localized: "create.add_ingredient.by_percentage", defaultValue: "By Percentage")
                           : String(localized: "create.add_ingredient.by_weight", defaultValue: "By Weight")) {
                        let row = IngredientRow()
                        ingredients.append(row)
                        focusedRowID = row.id
                    }
                    Button("Volume") {
                        let defaultUnit = Settings.shared.preferredVolumeSystem() == .metric ? "deciliter" : "tablespoon"
                        extraIngredients.append(ExtraIngredientRow(name: "", amount: 0, unit: defaultUnit, isPreferment: false))
                    }
                    Button(String(localized: "unit.count", defaultValue: "Count")) {
                        extraIngredients.append(ExtraIngredientRow(name: "", amount: 1, unit: "count", isPreferment: false))
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("How is this ingredient measured?")
                }
            } header: {
                Text("Other Ingredients")
            } footer: {
                if containsPreferment {
                    let prefermentLabel = prefermentName.isEmpty ? "preferment" : prefermentName
                    Text(String(
                        format: String(localized: "create.other_ingredients.footer.preferment", defaultValue: "Enter the additional amount of each ingredient used in the main dough, on top of what's in the %@. Leave at 0 (or remove) if it's only used in the preferment."),
                        prefermentLabel
                    ))
                }
            }

            if !extraIngredients.isEmpty {
                Section {
                    ForEach(Array(extraIngredients.enumerated()), id: \.element.id) { index, extra in
                        HStack {
                            TextField("Ingredient Name", text: $extraIngredients[index].name)
                                .autocorrectionDisabled()
                                .accessibilityIdentifier("extraIngredientNameField_\(index)")
                            Spacer()
                            TextField("0", value: $extraIngredients[index].amount, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 50)
                                .accessibilityIdentifier("extraIngredientAmountField_\(index)")
                            Menu {
                                ForEach(extraIngredientUnits, id: \.self) { unit in
                                    Button(VolumeUnitFormatter.pickerLabel(unit: unit)) {
                                        extraIngredients[index].unit = unit
                                    }
                                }
                            } label: {
                                Text(VolumeUnitFormatter.pickerLabel(unit: extra.unit))
                            }
                            .accessibilityIdentifier("extraIngredientUnitMenu_\(index)")
                        }
                    }
                    .onDelete { extraIngredients.remove(atOffsets: $0) }
                } header: {
                    Text("Additional Ingredients")
                } footer: {
                    Text("These ingredients aren't converted to grams, so they're kept in their original units and scaled with the recipe.")
                }
            }
        }
    }

    var ingredientsForm: some View {
        ingredientsFormContent
        .onAppear {
            guard !ingredientsFormHasFocused, let firstID = flours.first?.id else { return }
            ingredientsFormHasFocused = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                focusedRowID = firstID
            }
        }
        .navigationTitle(containsPreferment
                         ? String(localized: "create.title.main_dough", defaultValue: "Main Dough")
                         : String(localized: "create.title.ingredients", defaultValue: "Ingredients"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") {
                    let candidates = scanExtraIngredientConversions()
                    if candidates.isEmpty {
                        navPath.append(.preview)
                    } else {
                        conversionSheetData = ExtraIngredientConversionSheetData(candidates: candidates)
                    }
                }
                .disabled(!ingredientsReady)
                .accessibilityIdentifier("ingredientsNextButton")
            }
        }
        .sheet(item: $conversionSheetData) { data in
            extraIngredientConversionSheet(for: data)
        }
        .keyboardDismissible()
    }

    // MARK: - Convert additional ingredients to weight

    /// Scans `extraIngredients` for ones that match a known gram conversion (ounces
    /// or volume ingredients with a recognized `IngredientCategory`), so the user can
    /// choose to fold them into the weight-based ingredients. Count-based extras stay
    /// in their original unit.
    func scanExtraIngredientConversions() -> [ExtraIngredientConversionCandidate] {
        extraIngredients.enumerated().compactMap { index, extra in
            guard ExtraIngredientConversion.canSuggestWeightConversion(for: extra.unit) else {
                return nil
            }
            guard let suggestion = ExtraIngredientConversion.suggest(name: extra.name, amount: extra.amount, unit: extra.unit) else {
                return nil
            }
            return ExtraIngredientConversionCandidate(extraIndex: index, name: extra.name,
                                                        grams: suggestion.grams, description: suggestion.description)
        }
    }

    func extraIngredientConversionSheet(for data: ExtraIngredientConversionSheetData) -> some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(data.candidates.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(data.candidates[index].name)
                            Text(data.candidates[index].description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Toggle("Convert to weight", isOn: Binding(
                                get: { conversionSheetData?.candidates[index].convertToWeight ?? data.candidates[index].convertToWeight },
                                set: { conversionSheetData?.candidates[index].convertToWeight = $0 }
                            ))
                        }
                    }
                } header: {
                    Text("Convert to Weight?")
                } footer: {
                    Text("These additional ingredients can be converted to grams so they count toward the dough's total weight.")
                }
            }
            .navigationTitle("Additional Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Continue") {
                        applyExtraIngredientConversions()
                        conversionSheetData = nil
                        navPath.append(.preview)
                    }
                }
            }
        }
    }

    /// Applies the user's choices from `extraIngredientConversionSheet`: converted
    /// ingredients are removed from `extraIngredients` and added to `ingredients`/
    /// `prefermentIngredientRows` with a weight (in `.byWeight` mode) or an equivalent
    /// percentage (in `.byPercent` mode).
    func applyExtraIngredientConversions() {
        let toConvert = (conversionSheetData?.candidates ?? [])
            .filter(\.convertToWeight)
            .sorted { $0.extraIndex > $1.extraIndex }

        for candidate in toConvert {
            let extra = extraIngredients[candidate.extraIndex]
            guard let value = convertedValue(grams: candidate.grams, isPreferment: extra.isPreferment) else { continue }
            addConvertedIngredient(name: candidate.name, value: value, isPreferment: extra.isPreferment)
            extraIngredients.remove(at: candidate.extraIndex)
        }
    }

    /// Converts `grams` to the value an `IngredientRow` should hold: the gram amount
    /// directly in `.byWeight` mode, or an equivalent baker's percentage in
    /// `.byPercent` mode. Returns `nil` if a percentage can't be computed (e.g. the
    /// converted weight would exceed the relevant total).
    func convertedValue(grams: Double, isPreferment: Bool) -> Double? {
        if inputMode == .byWeight { return grams }
        guard let (totalPercent, totalWeight) = percentBasis(isPreferment: isPreferment), totalWeight > grams else {
            return nil
        }
        return grams * totalPercent / (totalWeight - grams)
    }

    /// The total baker's percentage and corresponding weight that a new ingredient's
    /// percentage should be computed against: the whole recipe for main-dough
    /// ingredients, or just the preferment for preferment ingredients.
    func percentBasis(isPreferment: Bool) -> (totalPercent: Double, totalWeight: Double)? {
        guard let defaultWeight, defaultWeight > 0 else { return nil }

        if !isPreferment {
            let useFlours = containsPreferment ? combinedFlours : flours
            let useIngredients = containsPreferment ? combinedIngredients : ingredients
            let totalPercent = useFlours.compactMap(\.value).reduce(0, +) + useIngredients.compactMap(\.value).reduce(0, +)
            guard totalPercent > 0 else { return nil }
            return (totalPercent, defaultWeight)
        }

        guard let prefermentFlourPercent, prefermentFlourPercent > 0 else { return nil }
        let overallFlourPercent = combinedFlours.compactMap(\.value).reduce(0, +)
        let overallTotalPercent = overallFlourPercent + combinedIngredients.compactMap(\.value).reduce(0, +)
        guard overallTotalPercent > 0 else { return nil }

        let overallFlourWeight = (overallFlourPercent / overallTotalPercent) * defaultWeight
        let prefermentFlourWeight = (prefermentFlourPercent / 100) * overallFlourWeight
        let prefermentTotalPercent = prefermentFlours.compactMap(\.value).reduce(0, +)
            + prefermentIngredientRows.compactMap(\.value).reduce(0, +)
        guard prefermentTotalPercent > 0 else { return nil }
        let prefermentWeight = prefermentFlourWeight * (prefermentTotalPercent / 100)
        guard prefermentWeight > 0 else { return nil }

        return (prefermentTotalPercent, prefermentWeight)
    }

    /// Adds a converted ingredient to `ingredients` or `prefermentIngredientRows`,
    /// reusing the first row if it's still empty (matching how rows are added
    /// elsewhere in this step).
    func addConvertedIngredient(name: String, value: Double, isPreferment: Bool) {
        if isPreferment {
            if prefermentIngredientRows.count == 1, prefermentIngredientRows[0].name.trimmingCharacters(in: .whitespaces).isEmpty {
                prefermentIngredientRows[0] = IngredientRow(name: name, value: value)
            } else {
                prefermentIngredientRows.append(IngredientRow(name: name, value: value))
            }
        } else {
            if ingredients.count == 1, ingredients[0].name.trimmingCharacters(in: .whitespaces).isEmpty {
                ingredients[0] = IngredientRow(name: name, value: value)
            } else {
                ingredients.append(IngredientRow(name: name, value: value))
            }
        }
    }

    var ingredientsReady: Bool {
        if containsPreferment {
            let namesOK = flours.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                && ingredients.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            guard namesOK else { return false }
            if inputMode == .byPercent {
                let sum = combinedFlours.compactMap(\.value).reduce(0, +)
                return abs(sum - 100) < 0.001
            }
            return true
        }

        let floursOK: Bool
        if inputMode == .byPercent {
            let sum = flours.compactMap(\.value).reduce(0, +)
            floursOK = !flours.isEmpty
                && flours.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.value != nil }
                && abs(sum - 100) < 0.001
        } else {
            let namedFlours = flours.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            let namedIngredients = ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            return (!namedFlours.isEmpty || !namedIngredients.isEmpty)
                && namedFlours.allSatisfy { ($0.value ?? 0) > 0 }
                && namedIngredients.allSatisfy { ($0.value ?? 0) > 0 }
        }
        return floursOK
            && !ingredients.isEmpty
            && ingredients.allSatisfy { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && ($0.value ?? 0) > 0 }
    }

    /// The preferment is entered first. This pre-seeds the "Main Dough" step with a row
    /// for each preferment flour/ingredient (left at 0) so the user can fill in any
    /// *additional* amount used in the rest of the dough, on top of what's already in the
    /// preferment.
    func syncMainDoughFromPreferment() {
        guard containsPreferment else { return }
        for prefFlour in prefermentFlours where !prefFlour.name.trimmingCharacters(in: .whitespaces).isEmpty {
            guard !flours.contains(where: { $0.name.caseInsensitiveCompare(prefFlour.name) == .orderedSame }) else { continue }
            if flours.count == 1, flours[0].name.trimmingCharacters(in: .whitespaces).isEmpty, flours[0].value == nil {
                flours[0] = FlourRow(name: prefFlour.name)
            } else {
                flours.append(FlourRow(name: prefFlour.name))
            }
        }
        for prefIng in prefermentIngredientRows where !prefIng.name.trimmingCharacters(in: .whitespaces).isEmpty {
            guard !ingredients.contains(where: { $0.name.caseInsensitiveCompare(prefIng.name) == .orderedSame }) else { continue }
            if ingredients.count == 1, ingredients[0].name.trimmingCharacters(in: .whitespaces).isEmpty, ingredients[0].value == nil {
                ingredients[0] = IngredientRow(name: prefIng.name)
            } else {
                ingredients.append(IngredientRow(name: prefIng.name))
            }
        }
    }

    /// The amount of a preferment flour/ingredient row that counts toward the recipe-wide
    /// total. In `.byWeight` mode this is just the preferment's grams. In `.byPercent`
    /// mode, the preferment's own percentages are relative to the *preferment's* flour, so
    /// they're scaled by `prefermentFlourPercent` (the preferment's share of the total
    /// flour) to get their contribution to the total-flour-relative percentage.
    func prefermentContribution(_ prefValue: Double?) -> Double {
        guard let prefValue else { return 0 }
        if inputMode == .byPercent {
            return prefValue / 100 * (prefermentFlourPercent ?? 0)
        }
        return prefValue
    }

    /// After deleting a flour in `.byPercent` mode, rescale the remaining flours'
    /// percentages proportionally so they still sum to 100% (or to
    /// `100% - <preferment's flour contribution>` when there's a preferment).
    /// Without this, deleting a flour can leave the remaining percentages summing
    /// to far less than 100%, permanently disabling "Next" with no way to fix it
    /// other than manually re-entering every remaining flour's percentage.
    func renormalizeFlourPercentages() {
        guard inputMode == .byPercent else { return }
        let prefermentContributionSum = prefermentFlours.reduce(0) { $0 + prefermentContribution($1.value) }
        let target = 100 - prefermentContributionSum
        let sum = flours.compactMap(\.value).reduce(0, +)
        guard sum > 0, target > 0 else { return }
        let scale = target / sum
        for index in flours.indices {
            if let value = flours[index].value {
                flours[index].value = value * scale
            }
        }
    }

    /// `flours`/`ingredients` hold only the *additional* amounts used in the main dough.
    /// These combine those with the preferment's contribution (matched by name,
    /// case-insensitive) to get the totals for the recipe as a whole.
    var combinedFlours: [FlourRow] {
        var result = flours.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        for prefRow in prefermentFlours where !prefRow.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let contribution = prefermentContribution(prefRow.value)
            if let idx = result.firstIndex(where: { $0.name.caseInsensitiveCompare(prefRow.name) == .orderedSame }) {
                result[idx].value = (result[idx].value ?? 0) + contribution
            } else {
                result.append(FlourRow(name: prefRow.name, value: contribution))
            }
        }
        return result
    }

    var combinedIngredients: [IngredientRow] {
        var result = ingredients.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        for prefRow in prefermentIngredientRows where !prefRow.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let contribution = prefermentContribution(prefRow.value)
            if let idx = result.firstIndex(where: { $0.name.caseInsensitiveCompare(prefRow.name) == .orderedSame }) {
                result[idx].value = (result[idx].value ?? 0) + contribution
            } else {
                result.append(IngredientRow(name: prefRow.name, value: contribution))
            }
        }
        return result
    }

}
