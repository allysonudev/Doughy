//
//  CreateRecipeView+StepsPreferment.swift
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
    // MARK: - Step 3: Preferment (optional)

    var prefermentFormContent: some View {
        let isPercent = inputMode == .byPercent
        let unit = isPercent ? "%" : String(localized: "unit.grams.short", defaultValue: "g")
        return Form {
            Section("Preferment Details") {
                TextField("Name (e.g. Biga, Poolish)", text: $prefermentName)
                    .autocorrectionDisabled()
                    .focused($isPrefermentNameFocused)
                    .accessibilityIdentifier("prefermentNameField")
                if isPercent {
                    HStack {
                        Text("% of Total Flour")
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", value: $prefermentFlourPercent, format: FlexibleDecimalStyle(fractionDigits: 0...4))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                                .accessibilityIdentifier("prefermentFlourPercentField")
                            Text("%").foregroundStyle(.secondary)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }

            Section {
                ForEach(Array(prefermentFlours.enumerated()), id: \.element.id) { index, _ in
                    HStack(alignment: .top) {
                        IngredientNameField(placeholder: String(localized: "create.flour_name", defaultValue: "Flour Name"), text: $prefermentFlours[index].name,
                                            suggestions: allFlourSuggestions,
                                            accessibilityID: "prefermentFlourNameField_\(index)",
                                            rowID: prefermentFlours[index].id,
                                            focusedRowID: $focusedRowID,
                                            pendingValueRowID: $pendingValueRowID,
                                            exclude: Set(prefermentFlours.map { $0.name.lowercased() }.filter { !$0.isEmpty }))
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", value: $prefermentFlours[index].value, format: FlexibleDecimalStyle(fractionDigits: 0...4))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                                .accessibilityIdentifier("prefermentFlourValueField_\(index)")
                                .focused($focusedValueRowID, equals: prefermentFlours[index].id)
                            Text(unit).foregroundStyle(.secondary)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .onDelete { prefermentFlours.remove(atOffsets: $0) }
                Button {
                    let row = FlourRow()
                    prefermentFlours.append(row)
                    focusedRowID = row.id
                } label: {
                    Label("Add Flour", systemImage: "plus.circle")
                }
                .accessibilityIdentifier("addPrefermentFlourButton")
            } header: {
                Text(String(localized: "density.group.flours", defaultValue: "Flours"))
            } footer: {
                if isPercent {
                    let sum = prefermentFlours.compactMap(\.value).reduce(0, +)
                    let diff = 100.0 - sum
                    if prefermentFlours.compactMap(\.value).isEmpty {
                        Text("Flour percentages (relative to the preferment's own flour) must add up to 100%.")
                    } else if abs(diff) > 0.001 {
                        Text(String(format: String(localized: "create.flours.preferment.percent_remaining", defaultValue: "%.4g%% remaining to reach 100%% of the preferment's flour."), diff))
                            .foregroundStyle(diff < 0 ? .red : .orange)
                    } else {
                        Text("Flour percentages total 100%. ✓").foregroundStyle(.green)
                    }
                }
            }

            Section {
                ForEach(Array(prefermentIngredientRows.enumerated()), id: \.element.id) { index, _ in
                    HStack(alignment: .top) {
                        IngredientNameField(placeholder: String(localized: "create.ingredient_name", defaultValue: "Ingredient Name"), text: $prefermentIngredientRows[index].name,
                                            suggestions: allIngredientSuggestions,
                                            accessibilityID: "prefermentIngredientNameField_\(index)",
                                            rowID: prefermentIngredientRows[index].id,
                                            focusedRowID: $focusedRowID,
                                            pendingValueRowID: $pendingValueRowID,
                                            exclude: Set(prefermentIngredientRows.map { $0.name.lowercased() }.filter { !$0.isEmpty }))
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("0", value: $prefermentIngredientRows[index].value, format: FlexibleDecimalStyle(fractionDigits: 0...4))
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 70)
                                .accessibilityIdentifier("prefermentIngredientValueField_\(index)")
                                .focused($focusedValueRowID, equals: prefermentIngredientRows[index].id)
                            Text(unit).foregroundStyle(.secondary)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .onDelete { prefermentIngredientRows.remove(atOffsets: $0) }
                Button {
                    let row = IngredientRow()
                    prefermentIngredientRows.append(row)
                    focusedRowID = row.id
                } label: {
                    Label(String(localized: "action.add_ingredient", defaultValue: "Add Ingredient"), systemImage: "plus.circle")
                }
                .accessibilityIdentifier("addPrefermentIngredientButton")
            } header: {
                Text("Other Ingredients")
            } footer: {
                if isPercent {
                    Text(String(localized: "create.preferment.other_ingredients.footer.percent", defaultValue: "Enter each ingredient's percentage relative to the preferment's own flour (e.g. 50 = 50% hydration). You'll add any additional amounts for the rest of the dough next."))
                } else {
                    Text(String(localized: "create.preferment.other_ingredients.footer.weight", defaultValue: "Enter the weight of each ingredient as it's used in the preferment. You'll add any additional amounts for the rest of the dough next."))
                }
            }
        }
    }

    var prefermentForm: some View {
        prefermentFormContent
        .onAppear {
            guard !prefermentFormHasFocused else { return }
            prefermentFormHasFocused = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                isPrefermentNameFocused = true
            }
        }
        .navigationTitle("Preferment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") {
                    syncMainDoughFromPreferment()
                    navPath.append(.ingredients)
                }
                .disabled(!prefermentReady)
                .accessibilityIdentifier("prefermentNextButton")
            }
        }
        .keyboardDismissible()
    }

    var prefermentReady: Bool {
        guard !prefermentName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        let namedFlours = prefermentFlours.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !namedFlours.isEmpty, namedFlours.allSatisfy({ ($0.value ?? 0) > 0 }) else { return false }
        let namedIngredients = prefermentIngredientRows.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        guard namedIngredients.allSatisfy({ ($0.value ?? 0) > 0 }) else { return false }

        if inputMode == .byPercent {
            guard let fp = prefermentFlourPercent, fp > 0 else { return false }
            let flourSum = namedFlours.compactMap(\.value).reduce(0, +)
            return abs(flourSum - 100) < 0.001
        }
        return true
    }

    // MARK: - Step 4: Preview + Instructions + Save

    func formatGrams(_ value: Double) -> String {
        let formatted: String
        if value < 5 {
            formatted = value.formatted(.number.precision(.fractionLength(0...2)))
        } else if value < 20 {
            formatted = value.formatted(.number.precision(.fractionLength(0...1)))
        } else {
            formatted = value.rounded().formatted(.number.precision(.fractionLength(0)))
        }
        return "\(formatted)g"
    }

    var previewFormContent: some View {
        let isPercent = inputMode == .byPercent
        return Form {
            Section("Details") {
                LabeledContent("Name", value: recipeName)
                LabeledContent("Collection", value: effectiveCollection)
                if let w = defaultWeight, isPercent {
                    LabeledContent("Default Weight", value: formatGrams(w))
                }
                if containsPreferment { LabeledContent("Preferment", value: prefermentName) }
            }

            Section(String(localized: "density.group.flours", defaultValue: "Flours")) {
                ForEach(containsPreferment ? combinedFlours : flours.filter { !$0.name.isEmpty }, id: \.id) { flour in
                    LabeledContent(flour.name, value: isPercent
                        ? String(format: "%.4g%%", flour.value ?? 0)
                        : formatGrams(flour.value ?? 0))
                }
            }

            Section("Other Ingredients") {
                ForEach(containsPreferment ? combinedIngredients : ingredients.filter { !$0.name.isEmpty }, id: \.id) { ing in
                    LabeledContent(ing.name, value: isPercent
                        ? String(format: "%.4g%%", ing.value ?? 0)
                        : formatGrams(ing.value ?? 0))
                }
            }

            if !extraIngredients.isEmpty {
                Section {
                    ForEach(extraIngredients) { extra in
                        LabeledContent(extra.name, value: VolumeUnitFormatter.localizedFormat(amount: extra.amount, unit: extra.unit))
                    }
                } header: {
                    Text("Additional Ingredients")
                } footer: {
                    Text("Scaled with the recipe but not included in the gram total.")
                }
            }

            if containsPreferment {
                Section("Preferment") {
                    if isPercent {
                        LabeledContent("% of Total Flour",
                                       value: String(format: "%.4g%%", prefermentFlourPercent ?? 0))
                    }
                    ForEach(prefermentFlours.filter { !$0.name.isEmpty }, id: \.id) { flour in
                        LabeledContent(flour.name, value: isPercent
                            ? String(format: "%.4g%%", flour.value ?? 0)
                            : formatGrams(flour.value ?? 0))
                    }
                    ForEach(prefermentIngredientRows.filter { !$0.name.isEmpty }, id: \.id) { ing in
                        LabeledContent(ing.name, value: isPercent
                            ? String(format: "%.4g%%", ing.value ?? 0)
                            : formatGrams(ing.value ?? 0))
                    }
                }
            }

            Section {
                ForEach(Array(instructions.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .foregroundStyle(.secondary)
                        if editingStepIndex == index {
                            TextField("Step description", text: $editingStepText, axis: .vertical)
                                .lineLimit(1...5)
                                .focused($isStepEditFocused)
                            Button {
                                let trimmed = editingStepText.trimmingCharacters(in: .whitespaces)
                                instructions[index].text = trimmed.isEmpty ? row.text : trimmed
                                editingStepIndex = nil
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Confirm edit")
                        } else {
                            Button {
                                editingStepIndex = index
                                editingStepText = row.text
                                isStepEditFocused = true
                            } label: {
                                Text(row.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    moveStepIndex = index
                                    moveStepText = ""
                                    showMoveStepAlert = true
                                } label: {
                                    Label(String(localized: "create.instructions.move_to_position", defaultValue: "Move to position…"), systemImage: "arrow.up.arrow.down")
                                }
                                Button(role: .destructive) {
                                    if editingStepIndex == index { editingStepIndex = nil }
                                    instructions.remove(at: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .onMove { instructions.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Instructions (Optional)")
            } footer: {
                if !instructions.isEmpty {
                    Text(String(localized: "create.instructions.tap_hint", defaultValue: "Tap to edit, hold to move or delete, drag to reorder."))
                }
            }

            Section("Add Step") {
                TextField("Step description", text: $newStepText, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .focused($isNewStepFocused)
                Button("Add Step") {
                    let trimmed = newStepText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    isNewStepFocused = false
                    instructions.append(InstructionRow(text: trimmed))
                    newStepText = ""
                }
                .disabled(newStepText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityHint("Enter step text to enable")
            }

            #if DOUGHY_SCAN_DIAGNOSTICS
            if let diagnostics = lastScanDiagnostics {
                Section {
                    Button("Copy Import Diagnostics") {
                        UIPasteboard.general.string = diagnostics
                    }
                } footer: {
                    Text("Copies scan or link-import inputs, parsed ingredient data, and final draft values to the clipboard for debugging.")
                }
            }
            #endif
        }
    }

    var previewForm: some View {
        previewFormContent
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(editingRecipe != nil
                       ? String(localized: "create.action.save_changes", defaultValue: "Save Changes")
                       : String(localized: "create.action.save_recipe", defaultValue: "Save Recipe")) {
                    saveRecipe()
                }
                .bold()
                .accessibilityIdentifier("saveRecipeButton")
            }
        }
        .keyboardDismissible()
    }

}
