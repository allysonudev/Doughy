//
//  CalculatorView+AdjustMode.swift
//  Doughy
//

import SwiftUI

extension CalculatorView {
    // MARK: - Adjust mode

    var adjustContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                batchAdjustPanel
                if let effectivePreferment {
                    prefermentAdjustPanel(preferment: effectivePreferment)
                } else if canAddPreferment {
                    addPrefermentPanel
                }
                mainDoughAdjustPanel
                if hasTemps {
                    temperatureAdjustPanel
                }
                if let calculationError {
                    Text(calculationError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
    }

    var batchAdjustPanel: some View {
        adjustPanel(title: "Batch") {
            adjustIntInputRow(
                title: "Number of Doughs",
                placeholder: 1,
                value: $doughCount,
                accessibilityIdentifier: "doughCountField"
            )
            adjustInputRow(
                title: "Single Dough Weight",
                placeholder: currentRecipe.defaultWeight,
                value: $singleDoughWeight,
                unit: String(localized: "unit.grams.short", defaultValue: "g"),
                accessibilityIdentifier: "singleDoughWeightField"
            )
            adjustReadOnlyRow(
                title: "Total Batch Size",
                value: weightFormatter.format(weight: totalWeight)
            )
        }
    }

    var addPrefermentPanel: some View {
        adjustPanel(title: String(localized: "calculator.preferment.add_panel_title", defaultValue: "Preferment")) {
            Text(String(localized: "calculator.preferment.add_panel_body", defaultValue: "Carve out part of this dough into a poolish, biga, or starter. Total hydration stays the same."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Button {
                showingAddPreferment = true
            } label: {
                Label(String(localized: "calculator.preferment.add_button", defaultValue: "Add Preferment"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("addPrefermentButton")
        }
    }

    func prefermentAdjustPanel(preferment: Preferment) -> some View {
        adjustPanel(title: {
            HStack {
                Text(String(format: String(localized: "calculator.preferment.section_title", defaultValue: "Preferment: %@"), preferment.name))
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    showingRemovePrefermentConfirmation = true
                } label: {
                    Text(String(localized: "calculator.preferment.remove_button", defaultValue: "Remove"))
                        .font(.subheadline)
                }
                .accessibilityIdentifier("removePrefermentButton")
            }
        }) {
            adjustInputRow(
                title: "Flour of Total",
                placeholder: preferment.flourPercentage,
                value: $prefermentTotalPercent,
                unit: percentFormatter.percentSymbol
            )
            ForEach(Array(preferment.ingredients.enumerated()), id: \.offset) { index, ingredient in
                if isWeightRecipe {
                    adjustInputRow(
                        title: ingredient.name,
                        placeholder: ingredient.defaultWeight ?? 0,
                        value: Binding(
                            get: { prefermentIngredientWeights[index] },
                            set: { prefermentIngredientWeights[index] = $0 }
                        ),
                        unit: String(localized: "unit.grams.short", defaultValue: "g"),
                        accessibilityIdentifier: "prefermentIngredientWeightField_\(index)"
                    )
                } else if ingredient.isFlour {
                    adjustReadOnlyRow(
                        title: ingredient.name,
                        value: percentFormatter.format(percent: ingredient.defaultPercentage)
                    )
                } else {
                    adjustInputRow(
                        title: ingredient.name,
                        placeholder: ingredient.defaultPercentage,
                        value: Binding(
                            get: { prefermentIngredientPercents[index] },
                            set: { prefermentIngredientPercents[index] = $0 }
                        ),
                        unit: percentFormatter.percentSymbol,
                        accessibilityIdentifier: "prefermentIngredientPercentField_\(index)"
                    )
                }
            }
        }
    }

    var mainDoughAdjustPanel: some View {
        adjustPanel(title: isWeightRecipe ? "Dough Weights" : "Dough") {
            ForEach(Array(currentRecipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                if ingredient.extraAmount != nil || pendingRemovedYeastName == ingredient.name {
                    EmptyView()
                } else if isWeightRecipe {
                    adjustInputRow(
                        title: ingredient.name,
                        placeholder: ingredient.defaultWeight ?? 0,
                        value: Binding(
                            get: { ingredientWeights[index] },
                            set: { ingredientWeights[index] = $0 }
                        ),
                        unit: String(localized: "unit.grams.short", defaultValue: "g"),
                        accessibilityIdentifier: "ingredientWeightField_\(index)"
                    )
                } else if ingredient.isFlour {
                    adjustReadOnlyRow(
                        title: ingredient.name,
                        value: percentFormatter.format(percent: ingredient.defaultPercentage)
                    )
                } else {
                    adjustInputRow(
                        title: ingredient.name,
                        placeholder: ingredient.defaultPercentage,
                        value: Binding(
                            get: { ingredientPercents[index] },
                            set: { ingredientPercents[index] = $0 }
                        ),
                        unit: percentFormatter.percentSymbol,
                        accessibilityIdentifier: "ingredientPercentField_\(index)"
                    )
                }
            }

            if hasAdditionalIngredients {
                Divider()
                Text("Additional Ingredients")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                ForEach(Array(currentRecipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    if let amount = ingredient.extraAmount, let unit = ingredient.extraUnit {
                        adjustInputRow(
                            title: ingredient.name,
                            placeholder: amount,
                            value: Binding(
                                get: { extraIngredientAmounts[index] },
                                set: { extraIngredientAmounts[index] = $0 }
                            ),
                            unit: VolumeUnitFormatter.label(unit: unit, amount: extraIngredientAmounts[index] ?? amount),
                            accessibilityIdentifier: "extraIngredientAmountField_\(index)"
                        )
                    }
                }
            }
        }
    }

    var temperatureAdjustPanel: some View {
        adjustPanel(title: "Temperatures") {
            ForEach(Array(currentRecipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                if let temp = ingredient.temperature, pendingRemovedYeastName != ingredient.name {
                    adjustInputRow(
                        title: ingredient.name,
                        placeholder: temp.value,
                        value: Binding(
                            get: { ingredientTemps[index] },
                            set: { ingredientTemps[index] = $0 }
                        ),
                        unit: settings.preferredTemp().localizedSymbol
                    )
                }
            }
            if let effectivePreferment {
                ForEach(Array(effectivePreferment.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    if let temp = ingredient.temperature {
                        adjustInputRow(
                            title: "\(effectivePreferment.name) - \(ingredient.name)",
                            placeholder: temp.value,
                            value: Binding(
                                get: { ingredientTemps[1000 + index] },
                                set: { ingredientTemps[1000 + index] = $0 }
                            ),
                            unit: settings.preferredTemp().localizedSymbol
                        )
                    }
                }
            }
        }
    }

    func adjustPanel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        adjustPanel(title: { Text(title).font(.headline) }, content: content)
    }

    func adjustPanel<TitleContent: View, Content: View>(
        @ViewBuilder title: () -> TitleContent,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            title()
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.7)
        }
    }

    func adjustInputRow(
        title: String,
        placeholder: Double,
        value: Binding<Double?>,
        unit: String,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: AdjustRowLayout.labelValueSpacing) {
                Text(title)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: AdjustRowLayout.fieldUnitSpacing) {
                    adjustDoubleTextField(
                        placeholder: String(format: "%.4g", placeholder),
                        value: value,
                        keyboardType: .decimalPad,
                        accessibilityIdentifier: accessibilityIdentifier ?? ""
                    )
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: AdjustRowLayout.unitColumnWidth, alignment: .trailing)
                }
                .frame(minWidth: AdjustRowLayout.valueColumnWidth, alignment: .trailing)
                .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.vertical, AdjustRowLayout.rowVerticalPadding)
            Divider()
        }
    }

    func adjustIntInputRow(
        title: String,
        placeholder: Int,
        value: Binding<Int?>,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: AdjustRowLayout.labelValueSpacing) {
                Text(title)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: AdjustRowLayout.fieldUnitSpacing) {
                    adjustIntTextField(
                        placeholder: "\(placeholder)",
                        value: value,
                        keyboardType: .numberPad,
                        accessibilityIdentifier: accessibilityIdentifier
                    )
                    Color.clear
                        .frame(width: AdjustRowLayout.unitColumnWidth)
                }
                .frame(minWidth: AdjustRowLayout.valueColumnWidth, alignment: .trailing)
                .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.vertical, AdjustRowLayout.rowVerticalPadding)
            Divider()
        }
    }

    func adjustReadOnlyRow(title: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: AdjustRowLayout.labelValueSpacing) {
                Text(title)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: AdjustRowLayout.valueColumnWidth, alignment: .trailing)
            }
            .padding(.vertical, AdjustRowLayout.rowVerticalPadding)
            Divider()
        }
    }

    func adjustDoubleTextField(
        placeholder: String,
        value: Binding<Double?>,
        keyboardType: UIKeyboardType,
        accessibilityIdentifier: String
    ) -> some View {
        TextField(
            placeholder,
            value: value,
            format: .number
        )
        .multilineTextAlignment(.trailing)
        .keyboardType(keyboardType)
        .textFieldStyle(.plain)
        .frame(width: AdjustRowLayout.textFieldWidth)
        .padding(.vertical, AdjustRowLayout.textFieldVerticalPadding)
        .padding(.horizontal, AdjustRowLayout.textFieldHorizontalPadding)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AdjustRowLayout.textFieldCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AdjustRowLayout.textFieldCornerRadius)
                .stroke(Color(.separator), lineWidth: AdjustRowLayout.textFieldBorderWidth)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    func adjustIntTextField(
        placeholder: String,
        value: Binding<Int?>,
        keyboardType: UIKeyboardType,
        accessibilityIdentifier: String
    ) -> some View {
        TextField(
            placeholder,
            value: value,
            format: .number
        )
        .multilineTextAlignment(.trailing)
        .keyboardType(keyboardType)
        .textFieldStyle(.plain)
        .frame(width: AdjustRowLayout.textFieldWidth)
        .padding(.vertical, AdjustRowLayout.textFieldVerticalPadding)
        .padding(.horizontal, AdjustRowLayout.textFieldHorizontalPadding)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AdjustRowLayout.textFieldCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AdjustRowLayout.textFieldCornerRadius)
                .stroke(Color(.separator), lineWidth: AdjustRowLayout.textFieldBorderWidth)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

}

private enum AdjustRowLayout {
    static let labelValueSpacing: CGFloat = 10
    static let rowVerticalPadding: CGFloat = 10
    static let textFieldWidth: CGFloat = 76
    static let textFieldVerticalPadding: CGFloat = 6
    static let textFieldHorizontalPadding: CGFloat = 8
    static let textFieldCornerRadius: CGFloat = 6
    static let textFieldBorderWidth: CGFloat = 0.5
    static let fieldUnitSpacing: CGFloat = 4
    static let unitColumnWidth: CGFloat = 10

    static var textFieldChromeWidth: CGFloat {
        textFieldWidth + (textFieldHorizontalPadding * 2)
    }

    static var valueColumnWidth: CGFloat {
        textFieldChromeWidth + fieldUnitSpacing + unitColumnWidth
    }
}
