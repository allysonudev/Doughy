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
    @State var activeRecipeName: String?
    @State var activeRecipeCollection: String?
    @State var showingEdit = false
    @State var showingCopy = false
    @State var showingHistory = false
    @State var showingAddPreferment = false
    @State var showingRemovePrefermentConfirmation = false
    /// Session-scoped preferment add/remove state, mirroring the other Adjust
    /// tab overrides below - nothing here touches the stored recipe until
    /// "Set as Default" applies it via `CalculatorOverrides`.
    @State var pendingPreferment: Preferment?
    @State var pendingRemovedYeastName: String?
    @State var prefermentRemoved = false
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

    var noteExpandedKey: String { "sharedNoteExpanded_\(currentRecipe.collection)_\(currentRecipe.name)" }

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
        let collection = activeRecipeCollection ?? recipe.collection
        let name = activeRecipeName ?? recipe.name
        return store.collections
            .first { $0.name == collection }?
            .recipes.first { $0.name == name } ?? recipe
    }

    var prefermentRecipe: PrefermentRecipe? { currentRecipe as? PrefermentRecipe }
    var preferment: Preferment? { prefermentRecipe?.preferment }
    /// The preferment as it stands this session: the stored one, unless the
    /// user added or removed one via the Adjust tab without saving yet.
    var effectivePreferment: Preferment? {
        if prefermentRemoved { return nil }
        return pendingPreferment ?? preferment
    }
    var canAddPreferment: Bool {
        effectivePreferment == nil && PrefermentTool.hasFlourWaterYeast(currentRecipe)
    }
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

    /// The `0.0001`g threshold below which a final-dough amount is treated as
    /// nothing rather than a real, if tiny, quantity - matches the tolerance
    /// `Calculator` uses to shrug off the same floating-point noise.
    static let negligibleWeight = 0.0001

    var doughIngredients: [CalculatedIngredient] {
        guard let calculatedRecipe else { return [] }
        return calculatedRecipe.ingredients.filter { ingredient in
            guard ingredient.extraAmount == nil else { return false }
            // Once a preferment claims effectively all of an ingredient, the final
            // dough's share of it rounds to zero (or a hair negative, from summing
            // two independently-computed weights) - hide that row instead of
            // showing a phantom "0g"/"-0g" line for an ingredient that's really
            // just living entirely in the preferment now.
            guard let prefermentWeight = calculatedPrefermentRecipe?.preferment.ingredients
                .first(where: { $0.name == ingredient.name })?.weight else { return true }
            return ingredient.weight - prefermentWeight > Self.negligibleWeight
        }
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
        ZStack(alignment: .top) {
            calculatorNavigationBackdrop

            content
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: calculatorTopChromeHeight)
                }
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

            modePickerBar
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
            CreateRecipeView(copyingRecipe: currentRecipe) { recipe in
                store.pendingOpenIntent = PendingOpenRecipeRequest(recipeName: recipe.name, collection: recipe.collection)
            }
                .environment(store)
                .environment(appearanceStore)
        }
        .sheet(isPresented: $showingEdit, onDismiss: { store.refresh() }) {
            CreateRecipeView(editingRecipe: currentRecipe) { recipe in
                handleRecipeEditSaved(recipe)
            }
                .environment(store)
                .environment(appearanceStore)
        }
        .sheet(item: $sharingRecipe) { wrapper in
            RecipeShareView(recipe: wrapper.recipe)
                .environment(appearanceStore)
        }
        .sheet(isPresented: $showingAddPreferment) {
            AddPrefermentView(recipe: currentRecipe) { preferment, removedYeastName in
                pendingPreferment = preferment
                pendingRemovedYeastName = removedYeastName
                prefermentRemoved = false
                resetPrefermentSessionOverrides()
            }
            .environment(store)
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(actionError ?? "")
        }
        .alert(String(localized: "preferment.remove.confirm_title", defaultValue: "Remove Preferment?"), isPresented: $showingRemovePrefermentConfirmation) {
            Button(String(localized: "action.remove", defaultValue: "Remove"), role: .destructive) { removePreferment() }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) { }
        } message: {
            Text(String(localized: "preferment.remove.confirm_message", defaultValue: "Its flour and water fold back into the main dough. Total hydration stays the same."))
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
        Picker("Mode", selection: $mode) {
            Text("Recipe")
                .tag(RecipeSessionMode.recipe)
                .accessibilityIdentifier("recipeModeButton")
            Text("Adjust")
                .tag(RecipeSessionMode.adjust)
                .accessibilityIdentifier("adjustModeButton")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("recipeSessionModePicker")
    }

    var modePickerBar: some View {
        VStack(spacing: 0) {
            modePicker
                .padding(.horizontal)
                .padding(.vertical, 10)
            Divider()
        }
        .background {
            Color.clear
                .liquidGlassSurface(
                    in: Rectangle(),
                    tint: calculatorChromeTint
                )
        }
    }

    var calculatorChromeTint: Color {
        Color(.systemBackground).opacity(colorScheme == .dark ? 0.28 : 0.34)
    }

    var calculatorTopChromeHeight: CGFloat { 61 }

    var calculatorNavigationBackdrop: some View {
        Color(.systemGroupedBackground)
            .opacity(colorScheme == .dark ? 0.86 : 0.92)
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
