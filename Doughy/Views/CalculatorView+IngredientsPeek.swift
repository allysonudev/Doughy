//
//  CalculatorView+IngredientsPeek.swift
//  Doughy
//

import SwiftUI

extension CalculatorView {
    var ingredientsPeekOverlay: some View {
        ZStack(alignment: .bottom) {
            expandedIngredientsPanel
                .frame(height: ingredientsPanelHeight, alignment: .bottom)
                .clipped()
                .padding(.bottom, ingredientsPeekBarHeight)
                .allowsHitTesting(ingredientsExpanded)
                .zIndex(0)

            ingredientsPeekBar
                .zIndex(1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ingredientsPeekBar")
    }

    var ingredientsPeekBar: some View {
        Button {
            if ingredientsExpanded {
                collapseIngredientsPeek()
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                    ingredientsDragOffset = 0
                    ingredientsExpanded = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("Ingredients")
                    .font(.headline)
                Spacer()
                Text(weightFormatter.format(weight: calculatedRecipe?.weight ?? totalWeight))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: ingredientsExpanded ? "chevron.down" : "chevron.up")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(height: ingredientsPeekBarHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            let shape = UnevenRoundedRectangle(
                topLeadingRadius: ingredientsExpanded ? 0 : 16,
                topTrailingRadius: ingredientsExpanded ? 0 : 16
            )
            Color.clear
                .liquidGlassSurface(
                    in: shape,
                    tint: Color(.systemBackground).opacity(0.18),
                    interactive: true
                )
        }
        .overlay(alignment: .top) {
            Divider()
        }
        .foregroundStyle(.primary)
        .shadow(color: .black.opacity(ingredientsExpanded ? 0.12 : 0.08), radius: ingredientsExpanded ? 10 : 8, y: -4)
    }

    var expandedIngredientsPanel: some View {
        VStack(spacing: 12) {
            ingredientsDragHandle
            ScrollView {
                compactIngredientsContent
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            }
            .frame(maxHeight: .infinity)
        }
        .background {
            let shape = UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16)
            Color.clear
                .liquidGlassSurface(
                    in: shape,
                    tint: Color(.secondarySystemGroupedBackground).opacity(0.24)
                )
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: -4)
    }

    func collapseIngredientsPeek() {
        guard ingredientsExpanded else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            ingredientsDragOffset = 0
            ingredientsExpanded = false
        }
    }

    var ingredientsDragHandle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.28))
            .frame(width: 42, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        let translation = value.translation.height
                        ingredientsDragOffset = translation >= 0
                            ? translation
                            : max(translation * 0.28, -48)
                    }
                    .onEnded { value in
                        let shouldCollapse = value.translation.height > 80 || value.predictedEndTranslation.height > 150
                        if shouldCollapse {
                            collapseIngredientsPeek()
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                ingredientsDragOffset = 0
                            }
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    /// A condensed ingredient list for the peek bar — plain rows with hairline dividers instead of
    /// the full grouped `Form`, so a normal-length recipe doesn't fill the whole expansion.
    @ViewBuilder
    var compactIngredientsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let preferment = calculatedPrefermentRecipe?.preferment {
                compactIngredientSection(
                    title: preferment.name,
                    trailing: weightFormatter.format(weight: preferment.weight)
                ) {
                    ForEach(Array(preferment.ingredients.filter { $0.extraAmount == nil }.enumerated()), id: \.element.name) { index, ingredient in
                        compactPrefermentRow(
                            ingredient,
                            showDivider: index < preferment.ingredients.filter { $0.extraAmount == nil }.count - 1
                        )
                    }
                }
                compactSectionDivider()
            }

            compactIngredientSection(
                title: calculatedPrefermentRecipe != nil ? "Final Dough" : "Dough",
                trailing: weightFormatter.format(weight: calculatedRecipe?.weight ?? totalWeight),
                trailingAccessibilityIdentifier: "doughTotalWeight"
            ) {
                ForEach(Array(doughIngredients.enumerated()), id: \.element.name) { index, ingredient in
                    compactFinalDoughRow(
                        ingredient,
                        showDivider: index < doughIngredients.count - 1 || calculatedPrefermentRecipe?.preferment != nil
                    )
                }
                if let preferment = calculatedPrefermentRecipe?.preferment {
                    compactIngredientRow(
                        name: preferment.name,
                        temperature: nil,
                        primary: weightFormatter.format(weight: preferment.weight),
                        secondary: "",
                        showDivider: false
                    )
                }
            }

            if !extraIngredients.isEmpty {
                compactSectionDivider()
                compactIngredientSection(title: "Additional Ingredients") {
                    ForEach(Array(extraIngredients.enumerated()), id: \.element.name) { index, ingredient in
                        compactExtraIngredientRow(
                            ingredient,
                            showDivider: index < extraIngredients.count - 1
                        )
                    }
                }
            }
        }
    }

    func compactIngredientSection<Content: View>(
        title: String,
        trailing: String? = nil,
        trailingAccessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer(minLength: 12)
                if let trailing {
                    Text(trailing)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(trailingAccessibilityIdentifier ?? "")
                }
            }
            .padding(.bottom, 6)

            content()
        }
        .padding(.vertical, 2)
    }

    func compactSectionDivider() -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.22))
            .frame(height: 1.5)
            .padding(.vertical, 12)
    }

    func compactFinalDoughRow(_ ingredient: CalculatedIngredient, showDivider: Bool) -> some View {
        let prefermentWeight = calculatedPrefermentRecipe?.preferment.ingredients
            .first(where: { $0.name == ingredient.name })?.weight ?? 0
        let doughWeight = ingredient.weight - prefermentWeight
        let key = "dough:\(ingredient.name)"
        let units = cycleUnits(for: ingredient.name, grams: ingredient.weight)
        let currentUnit = ingredientDisplayUnits[key] ?? "grams"
        let weightText = weightDisplay(grams: doughWeight, unit: currentUnit, for: ingredient.name)
        return compactIngredientRow(
            name: ingredient.name,
            temperature: nil,
            primary: weightText,
            secondary: "",
            tertiary: nil,
            primaryAccessibilityIdentifier: "ingredientWeight_\(ingredient.name)",
            secondaryAccessibilityIdentifier: nil,
            primaryIsActionable: units != nil,
            showDivider: showDivider
        ) {
            guard units != nil else { return }
            advanceUnit(key: key, name: ingredient.name, grams: ingredient.weight)
        }
    }

    func compactPrefermentRow(_ ingredient: CalculatedIngredient, showDivider: Bool) -> some View {
        let key = "preferment:\(ingredient.name)"
        let units = cycleUnits(for: ingredient.name, grams: ingredient.weight)
        let currentUnit = ingredientDisplayUnits[key] ?? "grams"
        let weightText = weightDisplay(grams: ingredient.weight, unit: currentUnit, for: ingredient.name)

        return compactIngredientRow(
            name: ingredient.name,
            temperature: nil,
            primary: weightText,
            secondary: "",
            primaryIsActionable: units != nil,
            showDivider: showDivider
        ) {
            guard units != nil else { return }
            advanceUnit(key: key, name: ingredient.name, grams: ingredient.weight)
        }
    }

    func compactExtraIngredientRow(_ ingredient: CalculatedIngredient, showDivider: Bool) -> some View {
        let amountText: String
        if let amount = ingredient.extraAmount, let unit = ingredient.extraUnit {
            amountText = VolumeUnitFormatter.localizedFormat(amount: amount, unit: unit)
        } else {
            amountText = ""
        }

        return compactIngredientRow(
            name: ingredient.name,
            temperature: ingredient.temperature,
            primary: amountText,
            secondary: "",
            showDivider: showDivider
        )
    }

    func compactIngredientRow(
        name: String,
        temperature: Temperature?,
        primary: String,
        secondary: String,
        tertiary: String? = nil,
        primaryAccessibilityIdentifier: String? = nil,
        secondaryAccessibilityIdentifier: String? = nil,
        primaryIsActionable: Bool = false,
        showDivider: Bool,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .lineLimit(2)
                    if let temperature {
                        Text(tempFormatter.format(temperature: temperature))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let tertiary {
                        Text(tertiary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(primary)
                        .font(.body.weight(.medium))
                        .foregroundStyle(primaryIsActionable ? Color.blue : Color.primary)
                        .accessibilityIdentifier(primaryAccessibilityIdentifier ?? "")
                    if !secondary.isEmpty {
                        Text(secondary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(secondaryAccessibilityIdentifier ?? "")
                    }
                }
                .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                action?()
            }
            .accessibilityAddTraits(primaryIsActionable ? .isButton : [])
            .accessibilityHint(primaryIsActionable ? String(localized: "Double-tap to cycle units") : "")

            if showDivider {
                Rectangle()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(height: 1)
            }
        }
    }

}

extension View {
    func calculatorNavigationGlass() -> some View {
        self
            .toolbarBackground(.bar, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }

    @ViewBuilder
    func liquidGlassSurface<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                Glass.regular
                    .tint(tint)
                    .interactive(interactive),
                in: shape
            )
        } else {
            self
                .background(tint ?? Color.clear, in: shape)
                .background(.bar, in: shape)
        }
    }
}
