//
//  CreateRecipeView.swift
//  Doughy

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

// MARK: - CreateRecipeView

struct CreateRecipeView: View {
    let editingRecipe: (any RecipeProtocol)?
    let copyingRecipe: (any RecipeProtocol)?
    let initialScanImage: UIImage?
    let openScanOptionsOnAppear: Bool
    let initialWebsiteImportURL: URL?
    let defaultCollectionName: String?
    let onSave: ((any RecipeProtocol) -> Void)?

    @Environment(RecipeStore.self) var store
    @Environment(CollectionAppearanceStore.self) var appearanceStore
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State var inputMode: RecipeInputMode? = nil  // nil → show mode picker
    @State var navPath: [CreateStep] = []
    @State var selectedStudioStep: CreateStep = .details
    @State var selectedStudioStartOption: StudioStartOption = .percent
    @State var modeBeforeReturningToStudioStart: RecipeInputMode?

    // Scan state
    @State var showScanOptions = false
    @State var showPhotoPicker = false
    @State var showCamera = false
    @State var showCameraScanOptions = false
    @State var showWebsiteImportSheet = false
    @State var websiteImportSheetInitialURL: URL?
    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var cameraScanImages: [UIImage] = []
    @State var isScanning = false
    @State var scanError: String?
    #if DOUGHY_SCAN_DIAGNOSTICS
    @State var lastScanDiagnostics: String?
    #endif
    @State var detectedRecipeLanguage: String? = nil
    @State var didOpenInitialScanOptions = false
    @State var sourcePhotoImages: [UIImage] = []
    @State var sourcePhotoCorner: SourcePhotoCorner = .bottomLeading
    @State var showSourcePhotoViewer = false
    @State var didOpenInitialWebsiteImport = false

    // Details
    @State var recipeName = ""
    @State var collectionName = ""
    @State var isNewCollection = false
    @State var newCollectionText = ""
    @State var collectionIconKey: String?
    @State var collectionColorKey: String?
    @State var didLoadCollectionAppearance = false
    @State var defaultWeight: Double? = nil
    @State var containsPreferment = false
    @State var sourceURL: URL?

    // Ingredients
    @State var flours: [FlourRow] = [FlourRow()]
    @State var ingredients: [IngredientRow] = [IngredientRow()]
    @State var extraIngredients: [ExtraIngredientRow] = []
    @State var showingAddIngredientDialog = false
    @State var focusedRowID: UUID? = nil

    @FocusState var isRecipeNameFocused: Bool
    @FocusState var isNewCollectionFocused: Bool
    @FocusState var isPrefermentNameFocused: Bool
    @FocusState var isNewStepFocused: Bool
    @FocusState var isStepEditFocused: Bool
    @FocusState var focusedValueRowID: UUID?
    @FocusState var focusedTempRowID: UUID?
    @State var pendingValueRowID: UUID? = nil
    @State var ingredientsFormHasFocused = false
    @State var prefermentFormHasFocused = false

    // Convert-to-weight suggestions for additional ingredients, shown on "Next"
    @State var conversionSheetData: ExtraIngredientConversionSheetData?

    // Conversion prompts for scanned "extra" ingredients
    @State var pendingConversions: [PendingConversion] = []
    @State var activeConversion: PendingConversion?
    @State var conversionGramsText: String = ""

    // Name-alternative prompts for scanned ingredients with two listed options
    @State var pendingNameChoices: [PendingNameChoice] = []
    // Ingredients the on-device cleanup pass flagged as uncertain, awaiting confirmation
    @State var pendingUncertainIngredients: [PendingUncertainIngredient] = []
    @State var lastTotalFlourWeight: Double = 0
    @State var lastTotalPrefFlourWeight: Double = 0

    // Preferment: entered first, as its own flour/ingredient list (in grams for .byWeight,
    // or baker's percentage relative to the preferment's own flour for .byPercent). The
    // "Ingredients"/"Main Dough" step then collects only the additional amounts used in
    // the rest of the dough, and the two are combined when building the recipe.
    @State var prefermentName = ""
    @State var prefermentFlourPercent: Double? = nil  // .byPercent only: % of total flour in the preferment
    @State var prefermentFlours: [FlourRow] = [FlourRow()]
    @State var prefermentIngredientRows: [IngredientRow] = [IngredientRow()]

    // Preview + save
    @State var instructions: [InstructionRow] = []
    @State var newStepText = ""
    @State var editingStepIndex: Int? = nil
    @State var editingStepText = ""
    @State var moveStepIndex: Int? = nil
    @State var moveStepText = ""
    @State var showMoveStepAlert = false
    @State var saveError: String?

    // Discard safeguard
    @State var showDiscardConfirmation = false
    @State var initialSnapshot: DraftSnapshot

    init(editingRecipe: (any RecipeProtocol)? = nil,
         copyingRecipe: (any RecipeProtocol)? = nil,
         initialScanImage: UIImage? = nil,
         openScanOptionsOnAppear: Bool = false,
         initialWebsiteImportURL: URL? = nil,
         defaultCollectionName: String? = nil,
         onSave: ((any RecipeProtocol) -> Void)? = nil) {
        self.editingRecipe = editingRecipe
        self.copyingRecipe = copyingRecipe
        self.initialScanImage = initialScanImage
        self.openScanOptionsOnAppear = openScanOptionsOnAppear
        self.initialWebsiteImportURL = initialWebsiteImportURL
        self.defaultCollectionName = defaultCollectionName
        self.onSave = onSave
        guard let recipe = editingRecipe ?? copyingRecipe else {
            let defaultCollection = defaultCollectionName ?? ""
            _collectionName = State(initialValue: defaultCollection)
            _initialSnapshot = State(initialValue: DraftSnapshot(collectionName: defaultCollection))
            return
        }
        let recipeName = copyingRecipe == nil ? recipe.name : Self.copyName(for: recipe.name)
        let isWeightRecipe = recipe.measurementMode == .weight

        _inputMode = State(initialValue: isWeightRecipe ? .byWeight : .byPercent)
        _recipeName = State(initialValue: recipeName)
        _collectionName = State(initialValue: recipe.collection)
        _defaultWeight = State(initialValue: recipe.defaultWeight)
        _sourceURL = State(initialValue: recipe.sourceURL)
        _instructions = State(initialValue: recipe.instructions.map { InstructionRow(text: $0.step) })

        let flourRows = recipe.ingredients.filter(\.isFlour)
            .map { FlourRow(name: $0.name, value: isWeightRecipe ? ($0.defaultWeight ?? 0) : $0.defaultPercentage) }
        let nonFlour = recipe.ingredients.filter { !$0.isFlour }
        let ingRows = nonFlour.filter { $0.extraAmount == nil }
            .map { IngredientRow(name: $0.name, value: isWeightRecipe ? ($0.defaultWeight ?? 0) : $0.defaultPercentage, tempValue: $0.temperature?.value) }
        let mainExtra = nonFlour.filter { $0.extraAmount != nil }

        var prefName = ""
        var prefFlourPercent: Double? = nil
        var prefFlours = [FlourRow()]
        var prefIngRows: [IngredientRow] = [IngredientRow()]
        var prefExtra: [Ingredient] = []
        var finalFlours: [FlourRow]
        var finalIngredients: [IngredientRow]
        let hasPreferment: Bool

        if let pref = (recipe as? PrefermentRecipe)?.preferment {
            hasPreferment = true
            prefName = pref.name
            prefFlourPercent = pref.flourPercentage
            let fp = pref.flourPercentage

            let prefFlourRows = pref.ingredients.filter(\.isFlour)
                .map { FlourRow(name: $0.name, value: isWeightRecipe ? ($0.defaultWeight ?? 0) : $0.defaultPercentage) }
            prefFlours = prefFlourRows.isEmpty ? [FlourRow()] : prefFlourRows

            let prefNonFlour = pref.ingredients.filter { !$0.isFlour }
            let prefIngredientRows = prefNonFlour.filter { $0.extraAmount == nil }
                .map { IngredientRow(name: $0.name, value: isWeightRecipe ? ($0.defaultWeight ?? 0) : $0.defaultPercentage, tempValue: $0.temperature?.value) }
            prefIngRows = prefIngredientRows.isEmpty ? [IngredientRow()] : prefIngredientRows
            prefExtra = prefNonFlour.filter { $0.extraAmount != nil }

            // `flourRows`/`ingRows` hold recipe-wide totals; the "Main Dough" step only
            // collects the *additional* amounts on top of the preferment's contribution.
            func additional(total: Double?, prefRows: [(name: String, percent: Double?)], name: String) -> Double? {
                let contribution = (prefRows.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.percent ?? 0) / 100 * fp
                return max(0, (total ?? 0) - contribution)
            }
            func additionalWeight(total: Double?, prefRows: [(name: String, weight: Double?)], name: String) -> Double? {
                let contribution = prefRows.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.weight ?? 0
                return max(0, (total ?? 0) - contribution)
            }
            let prefFlourLookup = prefFlourRows.map { (name: $0.name, percent: $0.value) }
            let prefIngLookup = prefIngredientRows.map { (name: $0.name, percent: $0.value) }
            let prefFlourWeightLookup = pref.ingredients.filter(\.isFlour).map { (name: $0.name, weight: $0.defaultWeight) }
            let prefIngWeightLookup = pref.ingredients.filter { !$0.isFlour && $0.extraAmount == nil }.map { (name: $0.name, weight: $0.defaultWeight) }

            let adjustedFlourRows = flourRows.map {
                FlourRow(name: $0.name, value: isWeightRecipe
                    ? additionalWeight(total: $0.value, prefRows: prefFlourWeightLookup, name: $0.name)
                    : additional(total: $0.value, prefRows: prefFlourLookup, name: $0.name))
            }
            let adjustedIngRows = ingRows.map {
                IngredientRow(name: $0.name,
                              value: isWeightRecipe
                                ? additionalWeight(total: $0.value, prefRows: prefIngWeightLookup, name: $0.name)
                                : additional(total: $0.value, prefRows: prefIngLookup, name: $0.name),
                              tempValue: $0.tempValue)
            }
            finalFlours = adjustedFlourRows.isEmpty ? [FlourRow()] : adjustedFlourRows
            finalIngredients = adjustedIngRows.isEmpty ? [IngredientRow()] : adjustedIngRows
        } else {
            hasPreferment = false
            finalFlours = flourRows.isEmpty ? [FlourRow()] : flourRows
            finalIngredients = ingRows.isEmpty ? [IngredientRow()] : ingRows
        }

        let prefExtraNames = Set(prefExtra.map { $0.name.lowercased() })
        var extraRows = prefExtra.map {
            ExtraIngredientRow(name: $0.name, amount: $0.extraAmount ?? 0, unit: $0.extraUnit ?? "tablespoon", isPreferment: true)
        }
        extraRows += mainExtra.filter { !prefExtraNames.contains($0.name.lowercased()) }.map {
            ExtraIngredientRow(name: $0.name, amount: $0.extraAmount ?? 0, unit: $0.extraUnit ?? "tablespoon", isPreferment: false)
        }

        _containsPreferment = State(initialValue: hasPreferment)
        _prefermentName = State(initialValue: prefName)
        _prefermentFlourPercent = State(initialValue: prefFlourPercent)
        _prefermentFlours = State(initialValue: prefFlours)
        _prefermentIngredientRows = State(initialValue: prefIngRows)
        _flours = State(initialValue: finalFlours)
        _ingredients = State(initialValue: finalIngredients)
        _extraIngredients = State(initialValue: extraRows)

        _initialSnapshot = State(initialValue: DraftSnapshot(
            recipeName: recipeName,
            collectionName: recipe.collection,
            isNewCollection: false,
            newCollectionText: "",
            defaultWeight: recipe.defaultWeight,
            containsPreferment: hasPreferment,
            sourceURL: recipe.sourceURL?.absoluteString,
            flours: finalFlours,
            ingredients: finalIngredients,
            extraIngredients: extraRows,
            prefermentName: prefName,
            prefermentFlourPercent: prefFlourPercent,
            prefermentFlours: prefFlours,
            prefermentIngredientRows: prefIngRows,
            instructions: recipe.instructions.map(\.step)
        ))
    }

    static func copyName(for name: String) -> String {
        String(format: String(localized: "recipe.copy_name", defaultValue: "Copy of %@"), name)
    }

    var effectiveCollection: String {
        isNewCollection ? newCollectionText : collectionName
    }

    /// Loads the appearance for the current collection once, after the form's collection
    /// has settled (the picker auto-selects the first collection on appear).
    func syncCollectionAppearanceIfNeeded() {
        guard !didLoadCollectionAppearance else { return }
        didLoadCollectionAppearance = true
        syncCollectionAppearance()
    }

    /// Mirrors the editor's icon/color onto the currently targeted collection's stored
    /// appearance, so editing reflects (and won't clobber) that collection's existing look.
    func syncCollectionAppearance() {
        let appearance = appearanceStore.appearance(for: effectiveCollection)
        collectionIconKey = appearance.iconKey
        collectionColorKey = appearance.colorKey
    }

    // MARK: - Discard safeguard

    var currentSnapshot: DraftSnapshot {
        DraftSnapshot(
            recipeName: recipeName,
            collectionName: collectionName,
            isNewCollection: isNewCollection,
            newCollectionText: newCollectionText,
            defaultWeight: defaultWeight,
            containsPreferment: containsPreferment,
            sourceURL: sourceURL?.absoluteString,
            flours: flours,
            ingredients: ingredients,
            extraIngredients: extraIngredients,
            prefermentName: prefermentName,
            prefermentFlourPercent: prefermentFlourPercent,
            prefermentFlours: prefermentFlours,
            prefermentIngredientRows: prefermentIngredientRows,
            instructions: instructions.map(\.text)
        )
    }

    var isDirty: Bool {
        currentSnapshot != initialSnapshot || appearanceChanged
    }

    /// Whether the chosen collection appearance differs from what's stored, so an
    /// appearance-only edit still trips the unsaved-changes safeguard.
    var appearanceChanged: Bool {
        guard didLoadCollectionAppearance else { return false }
        let stored = appearanceStore.appearance(for: effectiveCollection)
        return stored.iconKey != collectionIconKey || stored.colorKey != collectionColorKey
    }

    /// Dismisses immediately if nothing has changed; otherwise asks the user to confirm
    /// discarding their edits.
    func requestDismiss() {
        if isDirty {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }
}
