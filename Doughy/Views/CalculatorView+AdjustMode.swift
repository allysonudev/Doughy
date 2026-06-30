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
                if let preferment {
                    prefermentAdjustPanel(preferment: preferment)
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

    func prefermentAdjustPanel(preferment: Preferment) -> some View {
        adjustPanel(title: String(format: String(localized: "calculator.preferment.section_title", defaultValue: "Preferment: %@"), preferment.name)) {
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
                if ingredient.extraAmount != nil {
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
                if let temp = ingredient.temperature {
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
            if let preferment {
                ForEach(Array(preferment.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    if let temp = ingredient.temperature {
                        adjustInputRow(
                            title: "\(preferment.name) - \(ingredient.name)",
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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
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
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    TextField(
                        String(format: "%.4g", placeholder),
                        value: value,
                        format: .number
                    )
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .frame(width: 76)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    }
                    .accessibilityIdentifier(accessibilityIdentifier ?? "")
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 18, alignment: .leading)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.vertical, 10)
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
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField(
                    "\(placeholder)",
                    value: value,
                    format: .number
                )
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .frame(width: 76)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separator), lineWidth: 0.5)
                }
                .accessibilityIdentifier(accessibilityIdentifier)
            }
            .padding(.vertical, 10)
            Divider()
        }
    }

    func adjustReadOnlyRow(title: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .lineLimit(2)
                Spacer(minLength: 10)
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            Divider()
        }
    }

}
