//
//  CalculatorView.swift
//  Doughy

import SwiftUI

struct CalculatorView: View {
    let recipe: any RecipeProtocol
    @Environment(RecipeStore.self) var store
    @Environment(CollectionAppearanceStore.self) var appearanceStore
    @Environment(\.colorScheme) var colorScheme

    @State var mode: RecipeSessionMode = .recipe
    @State var doughCount: Int?
    @State var singleDoughWeight: Double?
    @State var ingredientPercents: [Int: Double] = [:]
    @State var extraIngredientAmounts: [Int: Double] = [:]
    @State var ingredientTemps: [Int: Double] = [:]
    @State var prefermentIngredientPercents: [Int: Double] = [:]
    @State var ingredientWeights: [Int: Double] = [:]
    @State var prefermentIngredientWeights: [Int: Double] = [:]
    @State var prefermentTotalPercent: Double?
    @State var calculatedRecipe: (any CalculatedRecipeProtocol)?
    @State var calculationError: String?
    @State var actionError: String?
    @State var showingEdit = false
    @State var showingCopy = false
    @State var showingHistory = false
    @State var sharingRecipe: RecipeWrapper?
    @State var sharedBy: String? = nil
    @State var sharedNote: String? = nil
    @State var noteExpanded: Bool = true
    @State var tweakText: String = ""
    @State var noteText: String = ""
    @State var lastSavedNoteText: String?
    @State var showingSetAsDefaultConfirmation = false

    /// Ingredients sit at the top of the Recipe-mode scroll. Once the bottom-most ingredient row
    /// scrolls off the top, a floating bar fades in; tapping it expands the ingredient list above
    /// that bar. `ingredientsVisible` is driven by that row's `onAppear`/`onDisappear` — the only
    /// scroll signal `List`/`Form` reliably delivers to its rows (preferences and
    /// `onScrollVisibilityChange` never fire for List rows).
    @State var ingredientsExpanded = false
    @State var ingredientsDragOffset: CGFloat = 0
    @State var ingredientsVisible = true

    var ingredientsOffscreen: Bool { !ingredientsVisible }
    var ingredientsPeekBarHeight: CGFloat { 52 }
    var ingredientsPanelExpandedHeight: CGFloat { 360 }
    var ingredientsPanelHeight: CGFloat {
        guard ingredientsExpanded else { return 0 }
        if ingredientsDragOffset >= 0 {
            return max(0, ingredientsPanelExpandedHeight - ingredientsDragOffset)
        } else {
            return ingredientsPanelExpandedHeight - ingredientsDragOffset
        }
    }

    var noteExpandedKey: String { "sharedNoteExpanded_\(recipe.name)" }

    let calculator = Calculator.shared
    let settings = Settings.shared
    let weightFormatter = WeightFormatter.shared
    let percentFormatter = PercentFormatter.shared
    let tempFormatter = TemperatureFormatter.shared
    let densityStore = IngredientDensityStore.shared
    let conversionStore = IngredientConversionStore.shared

    /// Currently selected display unit per ingredient, keyed "preferment:<name>" / "dough:<name>".
    /// Absent entries default to "grams"; tapping a convertible weight cycles through its units.
    @State var ingredientDisplayUnits: [String: String] = [:]

    /// The recipe as currently stored, looked up from `store.collections` so
    /// edits made elsewhere (e.g. "Set as Default", or the recipe editor) are
    /// reflected here once the store refreshes - the `recipe` passed at
    /// navigation time is a snapshot and doesn't update on its own. Falls
    /// back to that snapshot if the recipe can no longer be found (e.g. it
    /// was just deleted).
    var currentRecipe: any RecipeProtocol {
        store.collections
            .first { $0.name == recipe.collection }?
            .recipes.first { $0.name == recipe.name } ?? recipe
    }

    var prefermentRecipe: PrefermentRecipe? { currentRecipe as? PrefermentRecipe }
    var preferment: Preferment? { prefermentRecipe?.preferment }
    var hasTemps: Bool { currentRecipe.containsVariableTemps() }
    var isWeightRecipe: Bool { currentRecipe.measurementMode == .weight }
    var effectiveWeight: Double { singleDoughWeight ?? currentRecipe.defaultWeight }
    var effectiveDoughCount: Int { max(doughCount ?? 1, 1) }
    var totalWeight: Double { effectiveWeight * Double(effectiveDoughCount) }
    var hasAdditionalIngredients: Bool {
        currentRecipe.ingredients.contains { $0.extraAmount != nil }
    }

    var calculatedPrefermentRecipe: CalculatedPrefermentRecipe? {
        calculatedRecipe as? CalculatedPrefermentRecipe
    }

    var extraIngredients: [CalculatedIngredient] {
        calculatedRecipe?.ingredients.filter { $0.extraAmount != nil } ?? []
    }

    var doughIngredients: [CalculatedIngredient] {
        calculatedRecipe?.ingredients.filter { $0.extraAmount == nil } ?? []
    }

    var overrideDiff: String? {
        RecipeDiff.summarize(from: RecipeSnapshot(from: currentRecipe), to: currentOverrides().applied(to: currentRecipe))
    }

    var combinedNoteText: String {
        let tweaks = tweakText.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        return [tweaks, notes].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background {
                    Color.clear
                        .liquidGlassSurface(
                            in: Rectangle(),
                            tint: calculatorChromeTint
                        )
                }
            Divider()
            content
                .overlay(alignment: .bottom) {
                    if mode == .recipe && calculatedRecipe != nil && ingredientsOffscreen {
                        ZStack(alignment: .bottom) {
                            if ingredientsExpanded {
                                Color.black.opacity(0.001)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        collapseIngredientsPeek()
                                    }
                                    .simultaneousGesture(
                                        DragGesture(minimumDistance: 8)
                                            .onChanged { _ in
                                                collapseIngredientsPeek()
                                            }
                                    )
                                    .transition(.opacity)
                            }
                            ingredientsPeekOverlay
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: ingredientsOffscreen)
        }
        .background(alignment: .top) {
            calculatorNavigationBackdrop
        }
        .navigationTitle(currentRecipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .calculatorNavigationGlass()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        sharingRecipe = RecipeWrapper(recipe: currentRecipe)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("calculatorShareButton")

                    Button {
                        showingHistory = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("historyButton")

                    Button {
                        showingCopy = true
                    } label: {
                        Label("Copy", systemImage: "plus.square.on.square")
                    }
                    .accessibilityIdentifier("calculatorCopyButton")

                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("calculatorEditButton")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Recipe Actions")
                .accessibilityIdentifier("calculatorActionsMenu")
            }
        }
        .navigationDestination(isPresented: $showingHistory) {
            RecipeHistoryView(recipe: currentRecipe)
        }
        .sheet(isPresented: $showingCopy, onDismiss: { store.refresh() }) {
            CreateRecipeView(copyingRecipe: currentRecipe)
                .environment(store)
                .environment(appearanceStore)
        }
        .sheet(isPresented: $showingEdit, onDismiss: { store.refresh() }) {
            CreateRecipeView(editingRecipe: currentRecipe)
                .environment(store)
                .environment(appearanceStore)
        }
        .sheet(item: $sharingRecipe) { wrapper in
            RecipeShareView(recipe: wrapper.recipe)
                .environment(appearanceStore)
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(actionError ?? "")
        }
        .onAppear {
            store.recordOpened(recipe: currentRecipe)
            loadSharedNote()
            calculate()
            tweakText = overrideDiff ?? ""
        }
        .onChange(of: doughCount) { _, _ in calculate() }
        .onChange(of: singleDoughWeight) { _, _ in calculateAndRefreshTweakText() }
        .onChange(of: ingredientPercents) { _, _ in calculateAndRefreshTweakText() }
        .onChange(of: extraIngredientAmounts) { _, _ in calculateAndRefreshTweakText() }
        .onChange(of: ingredientTemps) { _, _ in calculateAndRefreshTweakText() }
        .onChange(of: prefermentIngredientPercents) { _, _ in calculateAndRefreshTweakText() }
        .onChange(of: ingredientWeights) { _, _ in calculateAndRefreshTweakText() }
        .onChange(of: prefermentIngredientWeights) { _, _ in calculateAndRefreshTweakText() }
        .onChange(of: prefermentTotalPercent) { _, _ in calculateAndRefreshTweakText() }
        .onChange(of: ingredientsOffscreen) { _, offscreen in
            if !offscreen {
                ingredientsExpanded = false
            }
        }
        .onChange(of: mode) { _, newMode in
            if newMode != .recipe {
                ingredientsExpanded = false
            }
        }
    }

    var modePicker: some View {
        HStack(spacing: 0) {
            modeButton("Recipe", mode: .recipe, accessibilityIdentifier: "recipeModeButton")
            modeButton("Adjust", mode: .adjust, accessibilityIdentifier: "adjustModeButton")
        }
        .padding(4)
        .frame(minHeight: 40)
        .background {
            Color.clear
                .liquidGlassSurface(
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                    tint: calculatorChromeTint,
                    interactive: true
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.28), lineWidth: 0.7)
        }
        .accessibilityIdentifier("recipeSessionModePicker")
    }

    func modeButton(_ title: String, mode targetMode: RecipeSessionMode, accessibilityIdentifier: String) -> some View {
        let isSelected = mode == targetMode
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                mode = targetMode
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                Color.clear
                    .liquidGlassSurface(
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous),
                        tint: Color(.systemBackground).opacity(colorScheme == .dark ? 0.42 : 0.64),
                        interactive: true
                    )
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    var calculatorAccentColor: Color {
        let appearance = appearanceStore.appearance(for: currentRecipe.collection)
        return CollectionColorCatalog.color(for: appearance.colorKey)
            ?? CollectionColorCatalog.derivedColor(for: currentRecipe.collection, dark: colorScheme == .dark)
    }

    var calculatorChromeTint: Color {
        calculatorAccentColor.opacity(colorScheme == .dark ? 0.20 : 0.12)
    }

    var calculatorNavigationBackdrop: some View {
        calculatorAccentColor
            .opacity(colorScheme == .dark ? 0.20 : 0.13)
            .frame(height: 160)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    var content: some View {
        ZStack {
            recipeContent
                .opacity(mode == .recipe ? 1 : 0)
                .allowsHitTesting(mode == .recipe)
                .accessibilityHidden(mode != .recipe)

            adjustContent
                .opacity(mode == .adjust ? 1 : 0)
                .allowsHitTesting(mode == .adjust)
                .accessibilityHidden(mode != .adjust)
        }
    }


}

enum RecipeSessionMode: String, CaseIterable {
    case recipe = "Recipe"
    case adjust = "Adjust"
}
