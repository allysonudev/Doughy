//
//  CalculatedRecipeView.swift
//  Doughy

import SwiftUI

struct CalculatedRecipeView: View {
    let calculatedRecipe: any CalculatedRecipeProtocol

    private let weightFormatter = WeightFormatter.shared
    private let percentFormatter = PercentFormatter.shared
    private let tempFormatter = TemperatureFormatter.shared

    private var prefermentRecipe: CalculatedPrefermentRecipe? { calculatedRecipe as? CalculatedPrefermentRecipe }

    var body: some View {
        Form {
            // MARK: - Preferment section
            if let preferment = prefermentRecipe?.preferment {
                Section {
                    ForEach(preferment.ingredients, id: \.name) { ingredient in
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
                ForEach(calculatedRecipe.ingredients, id: \.name) { ingredient in
                    finalDoughRow(ingredient)
                }
            } header: {
                HStack {
                    Text(prefermentRecipe != nil ? "Final Dough" : "Dough")
                    Spacer()
                    Text(weightFormatter.format(weight: calculatedRecipe.weight))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        }
        .navigationTitle(calculatedRecipe.name)
        .navigationBarTitleDisplayMode(.large)
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
                Text(percentFormatter.format(percent: ingredient.percentage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
