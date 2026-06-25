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

// MARK: - Types

private enum RecipeInputMode {
    case byPercent
    case byWeight
}

private enum SourcePhotoCorner: CaseIterable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

private enum SourcePhotoHiddenEdge: Equatable {
    case leading
    case trailing
}

private struct SourcePhotoEdgeAttachment: Equatable {
    var edge: SourcePhotoHiddenEdge
    var y: CGFloat
}

private struct FlourRow: Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var value: Double? = nil  // percent in .byPercent, grams in .byWeight

    static func == (lhs: FlourRow, rhs: FlourRow) -> Bool {
        lhs.name == rhs.name && lhs.value == rhs.value
    }
}

private struct IngredientRow: Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var value: Double? = nil  // percent or grams depending on mode
    var tempValue: Double? = nil

    static func == (lhs: IngredientRow, rhs: IngredientRow) -> Bool {
        lhs.name == rhs.name && lhs.value == rhs.value && lhs.tempValue == rhs.tempValue
    }
}

private struct InstructionRow: Identifiable {
    var id = UUID()
    var text: String
}

/// A ParseableFormatStyle for decimal number fields (.decimalPad keyboard) that displays
/// with the app language's decimal separator but accepts both "." and "," when parsing,
/// so hardware-keyboard input works correctly in any locale (e.g. German/Icelandic where
/// "." is a grouping separator and would otherwise be misread as a thousands separator).
private struct FlexibleDecimalStyle: ParseableFormatStyle {
    typealias FormatInput = Double
    typealias FormatOutput = String

    var fractionDigits: ClosedRange<Int>

    func format(_ value: Double) -> String {
        // Use the app's selected language (not the device region) to pick the decimal
        // separator. This keeps "." for English-language users even when their device
        // region is set to a comma-decimal locale, while correctly showing "," for
        // users running the app in German, French, etc.
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        return value.formatted(.number.locale(Locale(identifier: lang)).precision(.fractionLength(fractionDigits)))
    }

    var parseStrategy: FlexibleDecimalParseStrategy { FlexibleDecimalParseStrategy() }
}

private struct FlexibleDecimalParseStrategy: ParseStrategy {
    func parse(_ value: String) throws -> Double {
        // Swift's Double() always uses "." as decimal — handles en-US and hardware keyboards
        if let d = Double(value) { return d }
        // Also accept comma as decimal separator (locale-native decimal pad)
        if let d = Double(value.replacingOccurrences(of: ",", with: ".")) { return d }
        throw CocoaError(.formatting)
    }
}

/// An ingredient with a quantity that isn't converted to grams (e.g. "2 tablespoons" of
/// rosemary leaves). Kept separate from the percent-based flours/ingredients and scaled
/// by the recipe's scaling ratio when calculated.
private struct ExtraIngredientRow: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var amount: Double
    var unit: String  // "teaspoon" | "tablespoon" | "cup"
    var isPreferment: Bool

    static func == (lhs: ExtraIngredientRow, rhs: ExtraIngredientRow) -> Bool {
        lhs.name == rhs.name && lhs.amount == rhs.amount
            && lhs.unit == rhs.unit && lhs.isPreferment == rhs.isPreferment
    }
}

/// A name text field that shows previously-used ingredient names as tappable chips
/// below the field while it is focused, filtered to those containing the current text.
private struct IngredientNameField: View {
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]
    var accessibilityID: String = ""
    /// The stable UUID of the row this field belongs to, used with `focusedRowID`
    /// to trigger focus when a new row is added.
    var rowID: UUID = UUID()
    /// When set to `rowID`, this field becomes focused and clears the binding.
    var focusedRowID: Binding<UUID?> = .constant(nil)
    /// When a suggestion is tapped, written to `rowID` so the parent can drive focus
    /// onto the paired value field via a separate `@FocusState`.
    var pendingValueRowID: Binding<UUID?> = .constant(nil)
    /// Names already in use by other rows of the same type; filtered out of suggestions.
    var exclude: Set<String> = []

    @FocusState private var isFocused: Bool

    private var filtered: [String] {
        let q = text.trimmingCharacters(in: .whitespaces)
        let qLower = q.lowercased()
        let available = suggestions.filter { !exclude.contains($0.lowercased()) || $0.lowercased() == qLower }
        if q.isEmpty {
            return Array(available.prefix(5))
        }
        return available
            .filter { $0.localizedCaseInsensitiveContains(q) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
                .focused($isFocused)
                .accessibilityIdentifier(accessibilityID)
                .onAppear {
                    if focusedRowID.wrappedValue == rowID {
                        isFocused = true
                        focusedRowID.wrappedValue = nil
                    }
                }
                .onChange(of: focusedRowID.wrappedValue) { _, newID in
                    if newID == rowID {
                        isFocused = true
                        focusedRowID.wrappedValue = nil
                    }
                }

            if isFocused && !filtered.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filtered, id: \.self) { name in
                            Button(name) {
                                text = name
                                isFocused = false
                                pendingValueRowID.wrappedValue = rowID
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct MoveStepSheet: View {
    let total: Int
    let currentIndex: Int
    @Binding var text: String
    let onMove: (Int) -> Void
    let onDismiss: () -> Void

    @FocusState private var isFocused: Bool

    private var target: Int? { Int(text).map { $0 - 1 } }
    private var isValid: Bool {
        guard let t = target else { return false }
        return t >= 0 && t < total && t != currentIndex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "create.instructions.move_step.title", defaultValue: "Move Step"))
                .font(.headline)
            Text(String(format: String(localized: "create.instructions.move_step.prompt", defaultValue: "Enter a step number (1–%d)"), total))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(String(localized: "create.instructions.move_step.placeholder", defaultValue: "Step number"), text: $text)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
            HStack {
                Spacer()
                Button(String(localized: "action.cancel", defaultValue: "Cancel")) { onDismiss() }
                Button(String(localized: "create.instructions.move_step.action", defaultValue: "Move")) {
                    if isValid, let t = target { onMove(t) }
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.hidden)
        .onAppear { isFocused = true }
    }
}

private struct ScanAlternativeReviewRow: View {
    let primaryName: String
    let alternativeName: String
    @Binding var selectedName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(primaryName) or \(alternativeName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button(primaryName) {
                    selectedName = primaryName
                }
                .buttonStyle(.bordered)
                .tint(selectedName == primaryName ? .accentColor : .secondary)

                Button(alternativeName) {
                    selectedName = alternativeName
                }
                .buttonStyle(.bordered)
                .tint(selectedName == alternativeName ? .accentColor : .secondary)
            }

            TextField("Correct ingredient name", text: $selectedName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
        }
        .padding(.vertical, 4)
    }
}

/// A suggestion to convert an "additional ingredient" (e.g. "2 large eggs") to a
/// weight-based ingredient, presented to the user with a toggle before continuing
/// past the Ingredients step.
private struct ExtraIngredientConversionCandidate: Identifiable {
    var id = UUID()
    var extraIndex: Int
    var name: String
    var grams: Double
    var description: String
    var convertToWeight = true
}

/// Wraps the candidates for `extraIngredientConversionSheet` so it can be presented
/// with `.sheet(item:)`, which (unlike `.sheet(isPresented:)`) guarantees the sheet's
/// content is built from this data rather than a stale snapshot from before it was set.
private struct ExtraIngredientConversionSheetData: Identifiable {
    let id = UUID()
    var candidates: [ExtraIngredientConversionCandidate]
}

/// A scanned ingredient with no gram conversion, awaiting the user's input on whether
/// they know a gram conversion for it.
private struct PendingConversion: Identifiable {
    var id = UUID()
    var name: String
    var amount: Double
    var unit: String
    var isPreferment: Bool
}

/// Which of the four scanned-ingredient arrays a row belongs to, so a queued name
/// choice can locate and update the right row after the user picks.
private enum IngredientRowKind {
    case flour
    case ingredient
    case prefermentFlour
    case prefermentIngredient
}

/// A scanned ingredient that listed two alternative names (e.g. "all-purpose flour or
/// bread flour"), awaiting the user's choice of which one to use for that row.
private struct PendingNameChoice: Identifiable {
    var id = UUID()
    var rowID: UUID
    var kind: IngredientRowKind
    var primaryName: String
    var alternativeName: String
    var selectedName: String
}

private enum CreateStep: Hashable {
    case scanReview
    case details
    case ingredients
    case preferment
    case preview
}

/// A snapshot of the editable fields of the recipe draft, used to detect unsaved changes
/// so the user can be warned before discarding them.
private struct DraftSnapshot: Equatable {
    var recipeName = ""
    var collectionName = ""
    var isNewCollection = false
    var newCollectionText = ""
    var defaultWeight: Double? = nil
    var containsPreferment = false
    var flours: [FlourRow] = [FlourRow()]
    var ingredients: [IngredientRow] = [IngredientRow()]
    var extraIngredients: [ExtraIngredientRow] = []
    var prefermentName = ""
    var prefermentFlourPercent: Double? = nil
    var prefermentFlours: [FlourRow] = [FlourRow()]
    var prefermentIngredientRows: [IngredientRow] = [IngredientRow()]
    var instructions: [String] = []
}

// MARK: - Scan diagnostics

/// A snapshot of a recipe scan's inputs/outputs (OCR text, raw + resolved model output,
/// and the final recipe values applied to the form), exportable as JSON for debugging
/// and improving the scan prompt/category mappings.
private struct ScanDiagnostics: Codable {
    var ocrText: String
    var rawIngredients: [DiagIngredient]
    var resolvedIngredients: [DiagIngredient]
    var finalRecipe: DiagFinalRecipe

    struct DiagIngredient: Codable {
        var name: String
        var alternativeName: String?
        var category: String
        var weightGrams: Double
        var volumeAmount: Double
        var volumeUnit: String
        var isFlour: Bool
        var isPreferment: Bool
        var isExtra: Bool
    }

    struct DiagFinalRecipe: Codable {
        var name: String
        var defaultWeightGrams: Double?
        var flours: [DiagPercent]
        var ingredients: [DiagPercent]
        var extraIngredients: [DiagExtra]
        var preferment: DiagPreferment?

        struct DiagPercent: Codable {
            var name: String
            var percent: Double
        }

        struct DiagExtra: Codable {
            var name: String
            var amount: Double
            var unit: String
            var isPreferment: Bool
        }

        struct DiagPreferment: Codable {
            var name: String
            var flourPercentOfTotalFlour: Double
            var ingredients: [DiagPercent]
        }
    }

    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}

// MARK: - CreateRecipeView

struct CreateRecipeView: View {
    let editingRecipe: (any RecipeProtocol)?
    let copyingRecipe: (any RecipeProtocol)?
    let initialScanImage: UIImage?
    let openScanOptionsOnAppear: Bool

    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var inputMode: RecipeInputMode? = nil  // nil → show mode picker
    @State private var navPath: [CreateStep] = []

    // Scan state
    @State private var showScanOptions = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var scanError: String?
    @State private var lastScanDiagnostics: String?
    @State private var detectedRecipeLanguage: String? = nil
    @State private var didOpenInitialScanOptions = false
    @State private var sourcePhotoImage: UIImage?
    @State private var sourcePhotoCorner: SourcePhotoCorner = .bottomLeading
    @State private var showSourcePhotoViewer = false

    // Details
    @State private var recipeName = ""
    @State private var collectionName = ""
    @State private var isNewCollection = false
    @State private var newCollectionText = ""
    @State private var defaultWeight: Double? = nil
    @State private var containsPreferment = false

    // Ingredients
    @State private var flours: [FlourRow] = [FlourRow()]
    @State private var ingredients: [IngredientRow] = [IngredientRow()]
    @State private var extraIngredients: [ExtraIngredientRow] = []
    @State private var showingAddIngredientDialog = false
    @State private var focusedRowID: UUID? = nil

    @FocusState private var isRecipeNameFocused: Bool
    @FocusState private var isNewCollectionFocused: Bool
    @FocusState private var isPrefermentNameFocused: Bool
    @FocusState private var isNewStepFocused: Bool
    @FocusState private var isStepEditFocused: Bool
    @FocusState private var focusedValueRowID: UUID?
    @FocusState private var focusedTempRowID: UUID?
    @State private var pendingValueRowID: UUID? = nil
    @State private var ingredientsFormHasFocused = false
    @State private var prefermentFormHasFocused = false

    // Convert-to-weight suggestions for additional ingredients, shown on "Next"
    @State private var conversionSheetData: ExtraIngredientConversionSheetData?

    // Conversion prompts for scanned "extra" ingredients
    @State private var pendingConversions: [PendingConversion] = []
    @State private var activeConversion: PendingConversion?
    @State private var conversionGramsText: String = ""

    // Name-alternative prompts for scanned ingredients with two listed options
    @State private var pendingNameChoices: [PendingNameChoice] = []
    @State private var lastTotalFlourWeight: Double = 0
    @State private var lastTotalPrefFlourWeight: Double = 0

    // Preferment: entered first, as its own flour/ingredient list (in grams for .byWeight,
    // or baker's percentage relative to the preferment's own flour for .byPercent). The
    // "Ingredients"/"Main Dough" step then collects only the additional amounts used in
    // the rest of the dough, and the two are combined when building the recipe.
    @State private var prefermentName = ""
    @State private var prefermentFlourPercent: Double? = nil  // .byPercent only: % of total flour in the preferment
    @State private var prefermentFlours: [FlourRow] = [FlourRow()]
    @State private var prefermentIngredientRows: [IngredientRow] = [IngredientRow()]

    // Preview + save
    @State private var instructions: [InstructionRow] = []
    @State private var newStepText = ""
    @State private var editingStepIndex: Int? = nil
    @State private var editingStepText = ""
    @State private var moveStepIndex: Int? = nil
    @State private var moveStepText = ""
    @State private var showMoveStepAlert = false
    @State private var saveError: String?

    // Discard safeguard
    @State private var showDiscardConfirmation = false
    @State private var initialSnapshot: DraftSnapshot

    init(editingRecipe: (any RecipeProtocol)? = nil,
         copyingRecipe: (any RecipeProtocol)? = nil,
         initialScanImage: UIImage? = nil,
         openScanOptionsOnAppear: Bool = false) {
        self.editingRecipe = editingRecipe
        self.copyingRecipe = copyingRecipe
        self.initialScanImage = initialScanImage
        self.openScanOptionsOnAppear = openScanOptionsOnAppear
        guard let recipe = editingRecipe ?? copyingRecipe else {
            _initialSnapshot = State(initialValue: DraftSnapshot())
            return
        }
        let recipeName = copyingRecipe == nil ? recipe.name : Self.copyName(for: recipe.name)
        let isWeightRecipe = recipe.measurementMode == .weight

        _inputMode = State(initialValue: isWeightRecipe ? .byWeight : .byPercent)
        _recipeName = State(initialValue: recipeName)
        _collectionName = State(initialValue: recipe.collection)
        _defaultWeight = State(initialValue: recipe.defaultWeight)
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

    private static func copyName(for name: String) -> String {
        String(format: String(localized: "recipe.copy_name", defaultValue: "Copy of %@"), name)
    }

    private var effectiveCollection: String {
        isNewCollection ? newCollectionText : collectionName
    }

    // MARK: - Discard safeguard

    private var currentSnapshot: DraftSnapshot {
        DraftSnapshot(
            recipeName: recipeName,
            collectionName: collectionName,
            isNewCollection: isNewCollection,
            newCollectionText: newCollectionText,
            defaultWeight: defaultWeight,
            containsPreferment: containsPreferment,
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

    private var isDirty: Bool {
        currentSnapshot != initialSnapshot
    }

    /// Dismisses immediately if nothing has changed; otherwise asks the user to confirm
    /// discarding their edits.
    private func requestDismiss() {
        if isDirty {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    // MARK: - Body

    var body: some View {
        coreView
            .overlay { if isScanning { scanningOverlay } }
            .overlay {
                if let image = sourcePhotoImage, !isScanning {
                    SourcePhotoPipView(
                        image: image,
                        corner: $sourcePhotoCorner
                    ) {
                        showSourcePhotoViewer = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showSourcePhotoViewer) {
                if let image = sourcePhotoImage {
                    SourcePhotoViewer(image: image)
                }
            }
            .task {
                openInitialScanOptionsIfNeeded()
                guard let image = initialScanImage else { return }
                #if canImport(FoundationModels)
                if #available(iOS 26, *) {
                    await processImage(image)
                }
                #endif
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    showCamera = false
                    guard let image else { return }
                    #if canImport(FoundationModels)
                    if #available(iOS 26, *) {
                        Task { await processImage(image) }
                    }
                    #endif
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
            .alert("Scan Error", isPresented: Binding(
                get: { scanError != nil },
                set: { if !$0 { scanError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(scanError ?? "")
            }
            .alert("Unknown Ingredient", isPresented: Binding(
                get: { activeConversion != nil },
                set: { if !$0 { activeConversion = nil; scheduleNextScanPrompt(after: 0.4) } }
            )) {
                TextField(String(
                    format: String(localized: "create.unknown_ingredient.grams_per_unit", defaultValue: "Grams per %@"),
                    activeConversion.map { VolumeUnitFormatter.label(unit: $0.unit, amount: 1) }
                        ?? String(localized: "create.unknown_ingredient.unit_fallback", defaultValue: "unit")
                ),
                          text: $conversionGramsText)
                    .keyboardType(.decimalPad)
                Button("Save & Use") { resolveConversionPrompt(useGrams: true) }
                Button("Keep Original Unit", role: .cancel) { resolveConversionPrompt(useGrams: false) }
            } message: {
                if let pending = activeConversion {
                    Text(String(
                        format: String(localized: "create.unknown_ingredient.message", defaultValue: "We don't have a gram conversion for \"%@\" (%@). If you know how many grams are in one %@, enter it to use it now and remember it for future scans."),
                        pending.name,
                        VolumeUnitFormatter.format(amount: pending.amount, unit: pending.unit),
                        VolumeUnitFormatter.label(unit: pending.unit, amount: 1)
                    ))
                }
            }
            .sheet(isPresented: $showMoveStepAlert, onDismiss: {
                moveStepIndex = nil
                moveStepText = ""
            }) {
                MoveStepSheet(
                    total: instructions.count,
                    currentIndex: moveStepIndex ?? 0,
                    text: $moveStepText,
                    onMove: { target in
                        if let midx = moveStepIndex {
                            instructions.move(fromOffsets: IndexSet(integer: midx),
                                              toOffset: target > midx ? target + 1 : target)
                        }
                    },
                    onDismiss: { showMoveStepAlert = false }
                )
            }
            .interactiveDismissDisabled(isDirty)
    }

    private func openInitialScanOptionsIfNeeded() {
        guard openScanOptionsOnAppear, !didOpenInitialScanOptions else { return }
        didOpenInitialScanOptions = true
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            showScanOptions = true
        }
        #endif
    }

    @ViewBuilder
    private var coreView: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            navigationStack
                .photosPicker(isPresented: $showPhotoPicker,
                               selection: $selectedPhotoItem,
                               matching: .images)
                .onChange(of: selectedPhotoItem) { _, item in
                    guard let item else { return }
                        Task { await processPickedPhoto(item) }
                }
                .confirmationDialog("Choose Source", isPresented: $showScanOptions,
                                     titleVisibility: .visible) {
                    Button("Photo Library") { showPhotoPicker = true }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Camera") { showCamera = true }
                    }
                    Button("Cancel", role: .cancel) {}
                }
        } else {
            navigationStack
        }
        #else
        navigationStack
        #endif
    }

    private var navigationStack: some View {
        NavigationStack(path: $navPath) {
            Group {
                if editingRecipe != nil {
                    detailsForm
                } else if copyingRecipe != nil {
                    detailsForm
                } else {
                    modeSelectionPage
                }
            }
            .navigationDestination(for: CreateStep.self) { step in
                switch step {
                case .scanReview:  scanReviewForm
                case .details:     detailsForm
                case .ingredients: ingredientsForm
                case .preferment:  prefermentForm
                case .preview:     previewForm
                }
            }
        }
        .onChange(of: inputMode) { oldValue, newValue in
            guard let oldValue, let newValue, oldValue != newValue else { return }
            defaultWeight = nil
            for i in flours.indices { flours[i].value = nil }
            for i in ingredients.indices { ingredients[i].value = nil }
            prefermentFlourPercent = nil
            for i in prefermentFlours.indices { prefermentFlours[i].value = nil }
            for i in prefermentIngredientRows.indices { prefermentIngredientRows[i].value = nil }
            detectedRecipeLanguage = nil
        }
    }

    // MARK: - Scanning overlay

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                    .accessibilityLabel("Scanning recipe")
                Text("Scanning recipe…")
                    .foregroundStyle(.white)
                    .font(.headline)
                Text("AI can make mistakes — review the result and edit anything that doesn't look right.")
                    .foregroundStyle(.white.opacity(0.8))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Mode selection

    private var modeSelectionPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("How would you like to create your recipe?")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    .padding(.bottom, 32)

                VStack(spacing: 16) {
                    ModeCard(
                        icon: "percent",
                        title: String(localized: "create.mode.percent.title", defaultValue: "By Baker's Percentage"),
                        description: String(localized: "create.mode.percent.description", defaultValue: "Best for flour-based doughs where ingredients scale from total flour"),
                        accessibilityID: "byPercentModeCard"
                    ) {
                        inputMode = .byPercent
                        navPath.append(.details)
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            isRecipeNameFocused = true
                        }
                    }

                    ModeCard(
                        icon: "scalemass",
                        title: String(localized: "create.mode.weight.title", defaultValue: "By Weight"),
                        description: String(localized: "create.mode.weight.description", defaultValue: "Best for recipes without flour, or when you want to keep exact gram amounts"),
                        accessibilityID: "byWeightModeCard"
                    ) {
                        inputMode = .byWeight
                        navPath.append(.details)
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            isRecipeNameFocused = true
                        }
                    }

                    scanCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("New Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pendingValueRowID) { _, id in
            focusedValueRowID = id
            pendingValueRowID = nil
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                closeButton
                    .accessibilityIdentifier("modeSelectionCancelButton")
            }
        }
    }
    
    private var closeButton: some View {
        Button("Close", systemImage: "xmark") {
            requestDismiss()
        }
        .confirmationDialog("Are you sure? You will lose unsaved changes", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("action.discard", role: .destructive) { dismiss() }
                .accessibilityIdentifier("discardChangesButton")
            Button("action.keep_editing", role: .cancel) {}
                .accessibilityIdentifier("keepEditingButton")
        }
    }

    @ViewBuilder
    private var scanCard: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            scanCardForAvailableOS
        } else {
            ModeCard(
                icon: "camera.viewfinder",
                title: String(localized: "create.mode.scan.title", defaultValue: "Scan a Recipe"),
                description: String(localized: "create.mode.scan.unavailable", defaultValue: "Requires iOS 26 or later with Apple Intelligence"),
                enabled: false
            ) {}
        }
        #else
        ModeCard(
            icon: "camera.viewfinder",
            title: String(localized: "create.mode.scan.title", defaultValue: "Scan a Recipe"),
            description: String(localized: "create.mode.scan.unavailable", defaultValue: "Requires iOS 26 or later with Apple Intelligence"),
            enabled: false
        ) {}
        #endif
    }

    @available(iOS 26, *)
    @ViewBuilder
    private var scanCardForAvailableOS: some View {
        let aiUnavailable = ModeCard(
            icon: "camera.viewfinder",
            title: String(localized: "create.mode.scan.title", defaultValue: "Scan a Recipe"),
            description: String(localized: "create.mode.scan.apple_intelligence_not_enabled", defaultValue: "Enable Apple Intelligence in Settings > Apple Intelligence & Siri"),
            enabled: false
        ) {}
        switch SystemLanguageModel.default.availability {
        case .available:
            ModeCard(
                icon: "camera.viewfinder",
                title: String(localized: "create.mode.scan.title", defaultValue: "Scan a Recipe"),
                description: String(localized: "create.mode.scan.description", defaultValue: "Use Apple Intelligence to read a recipe from a photo or screenshot, entirely on-device and offline")
            ) {
                showScanOptions = true
            }
        case .unavailable(.deviceNotEligible):
            ModeCard(
                icon: "camera.viewfinder",
                title: String(localized: "create.mode.scan.title", defaultValue: "Scan a Recipe"),
                description: String(localized: "create.mode.scan.device_not_eligible", defaultValue: "Requires iPhone 15 or later"),
                enabled: false
            ) {}
        case .unavailable(.modelNotReady):
            ModeCard(
                icon: "camera.viewfinder",
                title: String(localized: "create.mode.scan.title", defaultValue: "Scan a Recipe"),
                description: String(localized: "create.mode.scan.model_not_ready", defaultValue: "Apple Intelligence is still setting up"),
                enabled: false
            ) {}
        case .unavailable(.appleIntelligenceNotEnabled):
            aiUnavailable
        @unknown default:
            aiUnavailable
        }
    }

    // MARK: - Scan Review

    private var scanReviewForm: some View {
        Form {
            Section {
                ForEach(pendingNameChoices.indices, id: \.self) { index in
                    ScanAlternativeReviewRow(
                        primaryName: pendingNameChoices[index].primaryName,
                        alternativeName: pendingNameChoices[index].alternativeName,
                        selectedName: $pendingNameChoices[index].selectedName
                    )
                    .accessibilityIdentifier("scanAlternativeReviewRow_\(index)")
                }
            } header: {
                Text("Ingredient Choices")
            } footer: {
                Text("Pick the ingredient name to use, or enter the corrected name from the source recipe.")
            }
        }
        .navigationTitle("Review Scan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", systemImage: "xmark") {
                    requestDismiss()
                }
                .accessibilityIdentifier("scanReviewCancelButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Continue") {
                    applyNameChoices()
                    navPath.append(.details)
                    scheduleNextScanPrompt()
                }
                .disabled(!scanReviewReady)
                .accessibilityIdentifier("scanReviewContinueButton")
            }
        }
        .keyboardDismissible()
    }

    private var scanReviewReady: Bool {
        pendingNameChoices.allSatisfy { !$0.selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // MARK: - Step 1: Details

    private var detailsForm: some View {
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
                        if collectionName.isEmpty, let first = collections.first {
                            collectionName = first
                            // This is an automatic default, not a user edit — update the
                            // baseline so it doesn't trip the discard-changes safeguard.
                            initialSnapshot.collectionName = first
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

    private var detailsReady: Bool {
        !recipeName.trimmingCharacters(in: .whitespaces).isEmpty
            && !(isNewCollection
                 ? newCollectionText.trimmingCharacters(in: .whitespaces).isEmpty
                 : collectionName.isEmpty)
            && (inputMode == .byWeight || (defaultWeight != nil && (defaultWeight ?? 0) > 0))
    }

    // MARK: - Step 2: Ingredients (flours + other, combined)

    /// Units offered when switching the unit of an "extra" ingredient (one that's
    /// measured by volume/count rather than converted to grams).
    private var extraIngredientUnits: [String] {
        switch Settings.shared.preferredVolumeSystem() {
        case .metric:   return ["milliliter", "deciliter", "liter", "count"]
        case .imperial: return ["teaspoon", "tablespoon", "cup", "ounce", "count"]
        }
    }

    private static let seededFlourSuggestions: [String] =
        IngredientCategory.allCases
            .filter { $0.group == .flours }
            .map(\.localizedDisplayName)

    private static let seededIngredientSuggestions: [String] = {
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

    private var allFlourSuggestions: [String] {
        suggestionsSorted(isFlour: true)
    }

    private var allIngredientSuggestions: [String] {
        suggestionsSorted(isFlour: false)
    }

    /// Builds the suggestion list for flour or ingredient name fields.
    /// Names used in the chosen collection are ranked by how often they appear there;
    /// names from other collections and static seeds follow at count 0.
    /// Within the same count, names are sorted alphabetically.
    private func suggestionsSorted(isFlour: Bool) -> [String] {
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

    private var ingredientsForm: some View {
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
                                .accessibilityLabel("\(flours[index].name.isEmpty ? "Flour" : flours[index].name), \(isPercent ? "percentage" : "grams")")
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
                                    .accessibilityLabel("\(ingredients[index].name.isEmpty ? "Ingredient" : ingredients[index].name), \(isPercent ? "percentage" : "grams")")
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

    /// Scans `extraIngredients` for ones that match a known gram conversion (eggs,
    /// ounces, or volume ingredients with a recognized `IngredientCategory`), so the
    /// user can choose to fold them into the weight-based ingredients.
    private func scanExtraIngredientConversions() -> [ExtraIngredientConversionCandidate] {
        extraIngredients.enumerated().compactMap { index, extra in
            guard let suggestion = ExtraIngredientConversion.suggest(name: extra.name, amount: extra.amount, unit: extra.unit) else {
                return nil
            }
            return ExtraIngredientConversionCandidate(extraIndex: index, name: extra.name,
                                                        grams: suggestion.grams, description: suggestion.description)
        }
    }

    private func extraIngredientConversionSheet(for data: ExtraIngredientConversionSheetData) -> some View {
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
    private func applyExtraIngredientConversions() {
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
    private func convertedValue(grams: Double, isPreferment: Bool) -> Double? {
        if inputMode == .byWeight { return grams }
        guard let (totalPercent, totalWeight) = percentBasis(isPreferment: isPreferment), totalWeight > grams else {
            return nil
        }
        return grams * totalPercent / (totalWeight - grams)
    }

    /// The total baker's percentage and corresponding weight that a new ingredient's
    /// percentage should be computed against: the whole recipe for main-dough
    /// ingredients, or just the preferment for preferment ingredients.
    private func percentBasis(isPreferment: Bool) -> (totalPercent: Double, totalWeight: Double)? {
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
    private func addConvertedIngredient(name: String, value: Double, isPreferment: Bool) {
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

    private var ingredientsReady: Bool {
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
    private func syncMainDoughFromPreferment() {
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
    private func prefermentContribution(_ prefValue: Double?) -> Double {
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
    private func renormalizeFlourPercentages() {
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
    private var combinedFlours: [FlourRow] {
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

    private var combinedIngredients: [IngredientRow] {
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

    // MARK: - Step 3: Preferment (optional)

    private var prefermentForm: some View {
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

    private var prefermentReady: Bool {
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

    private func formatGrams(_ value: Double) -> String {
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

    private var previewForm: some View {
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
                Text(String(localized: "create.instructions.tap_hint", defaultValue: "Tap to edit, hold to move or delete, drag to reorder."))
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

            if let diagnostics = lastScanDiagnostics {
                Section {
                    Button("Copy Scan Diagnostics") {
                        UIPasteboard.general.string = diagnostics
                    }
                } footer: {
                    Text("Copies the scan's OCR text and parsed ingredient data to the clipboard for debugging.")
                }
            }
        }
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

    // MARK: - AI scan processing

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func processPickedPhoto(_ item: PhotosPickerItem) async {
        isScanning = true
        defer {
            isScanning = false
            selectedPhotoItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                scanError = String(localized: "scan.error.load_selected_image", defaultValue: "Could not load the selected image.")
                return
            }
            sourcePhotoImage = image
            let result = try await RecipeScanner.shared.scan(image: image)
            try applyParsed(result)
        } catch {
            scanError = error.localizedDescription
        }
    }

    @available(iOS 26, *)
    private func processImage(_ image: UIImage) async {
        isScanning = true
        sourcePhotoImage = image
        defer { isScanning = false }
        do {
            let result = try await RecipeScanner.shared.scan(image: image)
            try applyParsed(result)
        } catch {
            scanError = error.localizedDescription
        }
    }

    /// Returns the localized display name for a scanned ingredient when its category is a
    /// known enum case, falling back to the raw scanned name for `.other`.
    @available(iOS 26, *)
    private func localizedIngredientName(for ingredient: ResolvedIngredient) -> String {
        guard ingredient.category != .other,
              let cat = IngredientCategory(rawValue: ingredient.category.rawValue) else {
            return ingredient.name
        }
        return cat.localizedDisplayName
    }

    /// Reverse-looks-up an IngredientCategory by its English display name and returns the
    /// localized name, falling back to `name` when no match is found. Used to localize
    /// alternative ingredient names from the scanner (e.g. "Bread Flour" → "Harina de fuerza").
    private func localizedAltName(_ name: String) -> String {
        IngredientCategory.allCases
            .first { $0.displayName.caseInsensitiveCompare(name) == .orderedSame }
            .map(\.localizedDisplayName) ?? name
    }

    @available(iOS 26, *)
    private func applyParsed(_ result: ScanResult) throws {
        let parsed = result.resolvedRecipe
        let valid = parsed.ingredients.filter { $0.weightGrams > 0 }
        let extras = parsed.ingredients.filter { $0.isExtra }

        let mainFlours = valid.filter { !$0.isPreferment && $0.isFlour }
        let mainOthers = valid.filter { !$0.isPreferment && !$0.isFlour }
        let prefFlours = valid.filter { $0.isPreferment && $0.isFlour }
        let prefOthers = valid.filter { $0.isPreferment && !$0.isFlour }

        let totalMainFlourWeight = mainFlours.reduce(0) { $0 + $1.weightGrams }
        let totalPrefFlourWeight = prefFlours.reduce(0) { $0 + $1.weightGrams }
        let totalFlourWeight = totalMainFlourWeight + totalPrefFlourWeight
        guard totalFlourWeight > 0 else {
            lastScanDiagnostics = makeScanDiagnostics(result: result, defaultWeightGrams: nil,
                                                       flours: [], ingredients: [], extras: [], preferment: nil)
            throw ScanError.noFlourFound
        }

        let langRecognizer = NLLanguageRecognizer()
        langRecognizer.processString(result.ocrText)
        if let detected = langRecognizer.dominantLanguage {
            let appLang = Bundle.main.preferredLocalizations.first ?? "en"
            let appPrimary = appLang.components(separatedBy: "-").first ?? appLang
            let detectedPrimary = detected.rawValue.components(separatedBy: "-").first ?? detected.rawValue
            if appPrimary != detectedPrimary {
                detectedRecipeLanguage = Locale(identifier: appLang).localizedString(forLanguageCode: detected.rawValue)
            } else {
                detectedRecipeLanguage = nil
            }
        } else {
            detectedRecipeLanguage = nil
        }

        recipeName = parsed.name
        defaultWeight = valid.reduce(0) { $0 + $1.weightGrams }

        pendingNameChoices = []
        activeConversion = nil

        flours = mainFlours.map {
            FlourRow(name: localizedIngredientName(for: $0), value: $0.weightGrams)
        }
        queueNameChoices(source: mainFlours, rows: flours, kind: .flour)
        if flours.isEmpty { flours = [FlourRow()] }

        ingredients = mainOthers.map {
            IngredientRow(name: localizedIngredientName(for: $0), value: $0.weightGrams, tempValue: scannedTempValue(for: $0))
        }
        queueNameChoices(source: mainOthers, rows: ingredients, kind: .ingredient)
        if ingredients.isEmpty { ingredients = [IngredientRow()] }

        instructions = parsed.instructions.map { InstructionRow(text: $0) }

        var diagPreferment: ScanDiagnostics.DiagFinalRecipe.DiagPreferment? = nil
        if parsed.hasPreferment && totalPrefFlourWeight > 0 {
            containsPreferment = true
            prefermentName = parsed.prefermentName
            prefermentFlourPercent = totalPrefFlourWeight / totalFlourWeight * 100

            let prefFlourRows = prefFlours.map {
                FlourRow(name: localizedIngredientName(for: $0), value: $0.weightGrams)
            }
            queueNameChoices(source: prefFlours, rows: prefFlourRows, kind: .prefermentFlour)
            prefermentFlours = prefFlourRows.isEmpty ? [FlourRow()] : prefFlourRows

            let prefIngRows = prefOthers.map {
                IngredientRow(name: localizedIngredientName(for: $0), value: $0.weightGrams, tempValue: scannedTempValue(for: $0))
            }
            queueNameChoices(source: prefOthers, rows: prefIngRows, kind: .prefermentIngredient)
            prefermentIngredientRows = prefIngRows.isEmpty ? [IngredientRow()] : prefIngRows

            // Pre-seed the "Main Dough" step with any preferment ingredient names not
            // already present (e.g. when all of a flour is in the preferment).
            syncMainDoughFromPreferment()

            diagPreferment = .init(
                name: prefermentName,
                flourPercentOfTotalFlour: prefermentFlourPercent ?? 0,
                ingredients: prefFlourRows.map { .init(name: $0.name, percent: $0.value ?? 0) }
                    + prefIngRows.map { .init(name: $0.name, percent: $0.value ?? 0) }
            )
        } else {
            containsPreferment = false
        }

        logScanAlternatives(in: parsed.ingredients, queuedPromptCount: pendingNameChoices.count)

        // Extra ingredients with no reliable gram conversion: queue a prompt for each so
        // the user can teach us the conversion (used now and remembered for next time)
        // or leave it in its original unit.
        lastTotalFlourWeight = totalFlourWeight
        lastTotalPrefFlourWeight = totalPrefFlourWeight
        extraIngredients = []
        pendingConversions = []
        for extra in extras {
            if IngredientConversionStore.shared.isAlwaysExtra(name: extra.name, unit: extra.extraUnit.rawValue) {
                extraIngredients.append(ExtraIngredientRow(name: extra.name, amount: extra.extraAmount,
                                                             unit: extra.extraUnit.rawValue, isPreferment: extra.isPreferment))
            } else {
                pendingConversions.append(PendingConversion(name: extra.name, amount: extra.extraAmount,
                                                              unit: extra.extraUnit.rawValue, isPreferment: extra.isPreferment))
            }
        }

        lastScanDiagnostics = makeScanDiagnostics(
            result: result,
            defaultWeightGrams: defaultWeight,
            flours: flours.map { .init(name: $0.name, percent: $0.value ?? 0) },
            ingredients: ingredients.map { .init(name: $0.name, percent: $0.value ?? 0) },
            extras: extras.map { .init(name: $0.name, amount: $0.extraAmount, unit: $0.extraUnit.rawValue, isPreferment: $0.isPreferment) },
            preferment: diagPreferment
        )

        inputMode = .byWeight
        if pendingNameChoices.isEmpty {
            navPath.append(.details)
            scheduleNextScanPrompt()
        } else {
            navPath.append(.scanReview)
        }
    }

    /// Converts a resolved ingredient's water-temperature descriptor (e.g. "lukewarm"),
    /// if any, to the user's preferred temperature unit for the "Temperature (optional)"
    /// field.
    @available(iOS 26, *)
    private func scannedTempValue(for ingredient: ResolvedIngredient) -> Double? {
        guard let fahrenheit = ingredient.temperatureFahrenheit else { return nil }
        return TemperatureConverter.shared.convert(temperature: fahrenheit, source: .fahrenheit,
                                                     target: Settings.shared.preferredTemp())
    }

    /// Queues a `PendingNameChoice` for each row whose source ingredient had a non-nil
    /// `alternativeName`. `source` and `rows` must correspond 1:1 in the same order (true
    /// for the `.map` calls that build `rows` from `source`).
    @available(iOS 26, *)
    private func queueNameChoices<Row: Identifiable>(source: [ResolvedIngredient], rows: [Row], kind: IngredientRowKind) where Row.ID == UUID {
        for (resolved, row) in zip(source, rows) {
            guard let alt = resolved.alternativeName, !alt.isEmpty else { continue }
            pendingNameChoices.append(PendingNameChoice(rowID: row.id, kind: kind,
                                                          primaryName: localizedIngredientName(for: resolved),
                                                          alternativeName: localizedAltName(alt),
                                                          selectedName: localizedIngredientName(for: resolved)))
        }
    }

    @available(iOS 26, *)
    private func logScanAlternatives(in ingredients: [ResolvedIngredient], queuedPromptCount: Int) {
        let alternatives = ingredients.compactMap { ingredient -> String? in
            guard let alternative = ingredient.alternativeName,
                  !alternative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }

            return "\(ingredient.name) or \(alternative)"
        }

        guard !alternatives.isEmpty else { return }

        print("Scan alternative ingredient pairs found: \(alternatives.count); queued prompts: \(queuedPromptCount); pairs: \(alternatives.joined(separator: " | "))")
    }

    private func scheduleNextScanPrompt(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            presentNextScanPrompt()
        }
    }

    private func presentNextScanPrompt() {
        guard activeConversion == nil else { return }

        if !pendingConversions.isEmpty {
            activeConversion = pendingConversions.removeFirst()
            return
        }
    }

    @available(iOS 26, *)
    private func makeScanDiagnostics(result: ScanResult,
                                      defaultWeightGrams: Double?,
                                      flours: [ScanDiagnostics.DiagFinalRecipe.DiagPercent],
                                      ingredients: [ScanDiagnostics.DiagFinalRecipe.DiagPercent],
                                      extras: [ScanDiagnostics.DiagFinalRecipe.DiagExtra],
                                      preferment: ScanDiagnostics.DiagFinalRecipe.DiagPreferment?) -> String {
        let rawIngredients = result.rawRecipe.ingredients.map {
            ScanDiagnostics.DiagIngredient(name: $0.name,
                                            alternativeName: $0.alternativeName.isEmpty ? nil : $0.alternativeName,
                                            category: $0.category.rawValue,
                                            weightGrams: $0.weightGrams,
                                            volumeAmount: $0.volumeAmount,
                                            volumeUnit: $0.volumeUnit.rawValue,
                                            isFlour: $0.isFlour,
                                            isPreferment: $0.isPreferment,
                                            isExtra: false)
        }
        let resolvedIngredients = result.resolvedRecipe.ingredients.map {
            ScanDiagnostics.DiagIngredient(name: $0.name,
                                            alternativeName: $0.alternativeName,
                                            category: $0.category.rawValue,
                                            weightGrams: $0.weightGrams,
                                            volumeAmount: $0.extraAmount,
                                            volumeUnit: $0.extraUnit.rawValue,
                                            isFlour: $0.isFlour,
                                            isPreferment: $0.isPreferment,
                                            isExtra: $0.isExtra)
        }
        let diagnostics = ScanDiagnostics(
            ocrText: result.ocrText,
            rawIngredients: rawIngredients,
            resolvedIngredients: resolvedIngredients,
            finalRecipe: .init(name: result.resolvedRecipe.name,
                                defaultWeightGrams: defaultWeightGrams,
                                flours: flours,
                                ingredients: ingredients,
                                extraIngredients: extras,
                                preferment: preferment)
        )
        return diagnostics.jsonString()
    }
    #endif

    /// Handles the user's response to an "unknown ingredient" conversion prompt: either
    /// saves the provided gram conversion and folds the ingredient into the regular
    /// percent-based ingredients, or keeps it as an "extra" ingredient in its original unit.
    private func resolveConversionPrompt(useGrams: Bool) {
        guard let pending = activeConversion else { return }
        activeConversion = nil
        defer {
            conversionGramsText = ""
            scheduleNextScanPrompt(after: 0.4)
        }

        if useGrams, let perUnit = Double(conversionGramsText), perUnit > 0 {
            IngredientConversionStore.shared.save(name: pending.name, unit: pending.unit, gramsPerUnit: perUnit)
            let totalGrams = pending.amount * perUnit

            if pending.isPreferment {
                guard lastTotalPrefFlourWeight > 0 else {
                    extraIngredients.append(ExtraIngredientRow(name: pending.name, amount: pending.amount,
                                                                 unit: pending.unit, isPreferment: pending.isPreferment))
                    return
                }
                let percent = totalGrams / lastTotalPrefFlourWeight * 100
                if prefermentIngredientRows.count == 1, prefermentIngredientRows[0].name.trimmingCharacters(in: .whitespaces).isEmpty {
                    prefermentIngredientRows[0] = IngredientRow(name: pending.name, value: percent)
                } else {
                    prefermentIngredientRows.append(IngredientRow(name: pending.name, value: percent))
                }
            } else {
                guard lastTotalFlourWeight > 0 else {
                    extraIngredients.append(ExtraIngredientRow(name: pending.name, amount: pending.amount,
                                                                 unit: pending.unit, isPreferment: pending.isPreferment))
                    return
                }
                let percent = totalGrams / lastTotalFlourWeight * 100
                if ingredients.count == 1, ingredients[0].name.trimmingCharacters(in: .whitespaces).isEmpty {
                    ingredients[0] = IngredientRow(name: pending.name, value: percent)
                } else {
                    ingredients.append(IngredientRow(name: pending.name, value: percent))
                }
            }
        } else {
            IngredientConversionStore.shared.markAsExtra(name: pending.name, unit: pending.unit)
            extraIngredients.append(ExtraIngredientRow(name: pending.name, amount: pending.amount,
                                                         unit: pending.unit, isPreferment: pending.isPreferment))
        }
    }

    private func applyNameChoices() {
        for pending in pendingNameChoices {
            let selected = pending.selectedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selected.isEmpty else { continue }

            switch pending.kind {
            case .flour:
                if let index = flours.firstIndex(where: { $0.id == pending.rowID }) {
                    flours[index].name = selected
                }
            case .ingredient:
                if let index = ingredients.firstIndex(where: { $0.id == pending.rowID }) {
                    ingredients[index].name = selected
                }
            case .prefermentFlour:
                if let index = prefermentFlours.firstIndex(where: { $0.id == pending.rowID }) {
                    prefermentFlours[index].name = selected
                }
            case .prefermentIngredient:
                if let index = prefermentIngredientRows.firstIndex(where: { $0.id == pending.rowID }) {
                    prefermentIngredientRows[index].name = selected
                }
            }
        }
    }

    // MARK: - Save

    private func saveRecipe() {
        do {
            let recipe = try buildRecipe()
            if let existing = editingRecipe {
                try store.update(recipe: recipe, existingName: existing.name, existingCollection: existing.collection)
            } else {
                try store.save(recipe: recipe)
            }
            dismiss()
        } catch RecipeBuilderError.missingName {
            saveError = String(localized: "create.error.missing_name", defaultValue: "Recipe name is missing.")
        } catch RecipeBuilderError.missingCollection {
            saveError = String(localized: "create.error.missing_collection", defaultValue: "Collection name is missing.")
        } catch RecipeBuilderError.missingDefaultWeight {
            saveError = String(localized: "create.error.missing_default_weight", defaultValue: "Default weight is missing.")
        } catch RecipeBuilderError.invalidIngredients {
            saveError = String(localized: "create.error.invalid_ingredients", defaultValue: "One or more ingredients are invalid. Please review your recipe.")
        } catch RecipeBuilderError.mainDoughLessThanPreferment(let main, let pref) {
            saveError = String(
                format: String(localized: "create.error.main_dough_less_than_preferment", defaultValue: "%@ in the main dough must be at least as much as in the preferment (%@)."),
                main.name,
                pref.name
            )
        } catch RecipeBuilderError.mainDoughMissingPreferment(let ing) {
            saveError = String(
                format: String(localized: "create.error.main_dough_missing_preferment", defaultValue: "Preferment ingredient \"%@\" is not in the main dough."),
                ing.name
            )
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func buildRecipe() throws -> any RecipeProtocol {
        let builder = RecipeBuilder()
        builder.name = recipeName.trimmingCharacters(in: .whitespaces)
        builder.collection = effectiveCollection.trimmingCharacters(in: .whitespaces)
        builder.instructions = instructions.map { Instruction(step: $0.text) }
        builder.containsPreferment = containsPreferment
        builder.measurementMode = inputMode == .byWeight ? .weight : .percent
        builder.mainDoughBuilder = MainDoughBuilder()

        let tempMeasurement = Settings.shared.preferredTemp()

        if inputMode == .byWeight {
            // With a preferment, `flours`/`ingredients` hold only the *additional*
            // amounts used in the main dough; combine them with the preferment's own
            // amounts to get the recipe-wide totals.
            let useFlours = containsPreferment ? combinedFlours : flours
            let useIngredients = containsPreferment ? combinedIngredients : ingredients

            let totalFlourWeight = useFlours.compactMap(\.value).reduce(0, +)
            if containsPreferment && totalFlourWeight <= 0 { throw RecipeBuilderError.invalidIngredients }

            for flour in useFlours where !flour.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let fb = FlourBuilder()
                fb.name = flour.name.trimmingCharacters(in: .whitespaces)
                fb.percent = totalFlourWeight > 0 ? ((flour.value ?? 0) / totalFlourWeight) * 100 : 0
                fb.weight = flour.value
                builder.mainDoughBuilder.flourBuilders.append(fb)
            }

            for ing in useIngredients where !ing.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let ib = IngredientBuilder()
                ib.name = ing.name.trimmingCharacters(in: .whitespaces)
                ib.mode = .weight
                ib.weight = ing.value
                if let tv = ing.tempValue {
                    ib.temperature = Temperature(value: tv, measurement: tempMeasurement)
                }
                builder.mainDoughBuilder.ingredientBuilders.append(ib)
            }

            // Total weight = sum of all entered weights
            let totalWeight = useFlours.compactMap(\.value).reduce(0, +)
                            + useIngredients.compactMap(\.value).reduce(0, +)
            builder.defaultWeight = totalWeight

        } else {
            builder.defaultWeight = defaultWeight

            // With a preferment, `flours`/`ingredients` hold only the *additional*
            // percentages used in the main dough; combine them with the preferment's
            // contribution to get the recipe-wide totals.
            let useFlours = containsPreferment ? combinedFlours : flours
            let useIngredients = containsPreferment ? combinedIngredients : ingredients

            for flour in useFlours where !flour.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let fb = FlourBuilder()
                fb.name = flour.name.trimmingCharacters(in: .whitespaces)
                fb.percent = flour.value
                builder.mainDoughBuilder.flourBuilders.append(fb)
            }

            for ing in useIngredients where !ing.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let ib = IngredientBuilder()
                ib.name = ing.name.trimmingCharacters(in: .whitespaces)
                ib.mode = .percent
                ib.percent = ing.value
                if let tv = ing.tempValue {
                    ib.temperature = Temperature(value: tv, measurement: tempMeasurement)
                }
                builder.mainDoughBuilder.ingredientBuilders.append(ib)
            }
        }

        for extra in extraIngredients where !extra.isPreferment && !extra.name.trimmingCharacters(in: .whitespaces).isEmpty {
            let ib = IngredientBuilder()
            ib.name = extra.name.trimmingCharacters(in: .whitespaces)
            ib.extraAmount = extra.amount
            ib.extraUnit = extra.unit
            builder.mainDoughBuilder.ingredientBuilders.append(ib)
        }

        if containsPreferment {
            builder.prefermentBuilder.name = prefermentName.trimmingCharacters(in: .whitespaces)

            if inputMode == .byWeight {
                let combinedFlourWeight = combinedFlours.compactMap(\.value).reduce(0, +)
                let prefFlourWeight = prefermentFlours.compactMap(\.value).reduce(0, +)
                guard combinedFlourWeight > 0, prefFlourWeight > 0 else {
                    throw RecipeBuilderError.invalidIngredients
                }
                builder.prefermentBuilder.totalFlourPercent = prefFlourWeight / combinedFlourWeight * 100
            } else {
                builder.prefermentBuilder.totalFlourPercent = prefermentFlourPercent
            }

            for prefFlour in prefermentFlours where !prefFlour.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let pb = PrefermentIngredientBuilder(isFlour: true)
                pb.name = prefFlour.name.trimmingCharacters(in: .whitespaces)
                if inputMode == .byWeight {
                    pb.weight = prefFlour.value
                } else {
                    pb.percent = prefFlour.value
                }
                builder.prefermentBuilder.flourBuilders.append(pb)
            }
            for prefIng in prefermentIngredientRows where !prefIng.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let pb = PrefermentIngredientBuilder(isFlour: false)
                pb.name = prefIng.name.trimmingCharacters(in: .whitespaces)
                if inputMode == .byWeight {
                    pb.weight = prefIng.value
                } else {
                    pb.percent = prefIng.value
                }
                if let tv = prefIng.tempValue {
                    pb.temperature = Temperature(value: tv, measurement: tempMeasurement)
                }
                builder.prefermentBuilder.ingredientBuilders.append(pb)
            }

            for extra in extraIngredients where extra.isPreferment && !extra.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let pb = PrefermentIngredientBuilder(isFlour: false)
                pb.name = extra.name.trimmingCharacters(in: .whitespaces)
                pb.extraAmount = extra.amount
                pb.extraUnit = extra.unit
                builder.prefermentBuilder.ingredientBuilders.append(pb)

                // Also add a matching (zero-percent) main-dough entry, since preferment
                // ingredients must have a corresponding main-dough ingredient.
                let ib = IngredientBuilder()
                ib.name = extra.name.trimmingCharacters(in: .whitespaces)
                ib.extraAmount = extra.amount
                ib.extraUnit = extra.unit
                builder.mainDoughBuilder.ingredientBuilders.append(ib)
            }
        } else {
            for extra in extraIngredients where extra.isPreferment && !extra.name.trimmingCharacters(in: .whitespaces).isEmpty {
                let ib = IngredientBuilder()
                ib.name = extra.name.trimmingCharacters(in: .whitespaces)
                ib.extraAmount = extra.amount
                ib.extraUnit = extra.unit
                builder.mainDoughBuilder.ingredientBuilders.append(ib)
            }
        }

        return try builder.build()
    }
}

// MARK: - Keyboard dismiss

private extension View {
    func keyboardDismissible() -> some View {
        scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - ModeCard

private struct ModeCard: View {
    let icon: String
    let title: String
    let description: String
    var enabled: Bool = true
    var accessibilityID: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 36)
                    .foregroundStyle(enabled ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(enabled ? Color.primary : Color.secondary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if enabled {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .flipsForRightToLeftLayoutDirection(true)
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
        .opacity(enabled ? 1.0 : 0.5)
        .modifier(OptionalAccessibilityIdentifier(id: accessibilityID))
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let id: String?

    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

// MARK: - Source photo PiP

private struct SourcePhotoPipView: View {
    let image: UIImage
    @Binding var corner: SourcePhotoCorner
    let action: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var keyboardHeight: CGFloat = 0
    @State private var edgeAttachment: SourcePhotoEdgeAttachment?
    @State private var isEdgeHidden = false

    private let margin: CGFloat = 16
    private let revealWidth: CGFloat = 22
    private let thumbnailSize = CGSize(width: 104, height: 132)

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.85), lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 6)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(String(localized: "source_photo.open", defaultValue: "Open source photo"))
                .accessibilityAddTraits(.isButton)
                .position(currentPosition(in: proxy))
                .offset(dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            guard !isTap(value.translation) else {
                                handleTap()
                                return
                            }

                            let base = currentPosition(in: proxy)
                            let projected = CGPoint(
                                x: base.x + value.predictedEndTranslation.width,
                                y: base.y + value.predictedEndTranslation.height
                            )
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                if let edge = hiddenEdge(for: projected, in: proxy) {
                                    edgeAttachment = SourcePhotoEdgeAttachment(
                                        edge: edge,
                                        y: clampedY(projected.y, in: proxy)
                                    )
                                    isEdgeHidden = true
                                } else if let edge = attachedEdge(for: projected, in: proxy) {
                                    edgeAttachment = SourcePhotoEdgeAttachment(
                                        edge: edge,
                                        y: clampedY(projected.y, in: proxy)
                                    )
                                    isEdgeHidden = false
                                } else {
                                    edgeAttachment = nil
                                    isEdgeHidden = false
                                    corner = nearestCorner(to: projected, in: proxy)
                                }
                                dragOffset = .zero
                            }
                        }
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: corner)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: edgeAttachment)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isEdgeHidden)
        }
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            updateKeyboardHeight(from: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private func currentPosition(in proxy: GeometryProxy) -> CGPoint {
        if let edgeAttachment {
            return edgePosition(
                for: edgeAttachment.edge,
                y: edgeAttachment.y,
                hidden: isEdgeHidden,
                in: proxy
            )
        }

        return position(for: corner, in: proxy)
    }

    private func edgePosition(for edge: SourcePhotoHiddenEdge, y: CGFloat, hidden: Bool, in proxy: GeometryProxy) -> CGPoint {
        let x: CGFloat
        switch edge {
        case .leading:
            x = hidden ? revealWidth - thumbnailSize.width / 2 : visibleEdgeX(for: .leading, in: proxy)
        case .trailing:
            x = hidden ? proxy.size.width - revealWidth + thumbnailSize.width / 2 : visibleEdgeX(for: .trailing, in: proxy)
        }
        return CGPoint(x: x, y: clampedY(y, in: proxy))
    }

    private func position(for corner: SourcePhotoCorner, in proxy: GeometryProxy) -> CGPoint {
        let x: CGFloat
        let y: CGFloat
        let bounds = verticalBounds(in: proxy)

        switch corner {
        case .topLeading, .bottomLeading:
            x = visibleEdgeX(for: .leading, in: proxy)
        case .topTrailing, .bottomTrailing:
            x = visibleEdgeX(for: .trailing, in: proxy)
        }

        switch corner {
        case .topLeading, .topTrailing:
            y = bounds.top
        case .bottomLeading, .bottomTrailing:
            y = bounds.bottom
        }

        return CGPoint(x: x, y: y)
    }

    private func visibleEdgeX(for edge: SourcePhotoHiddenEdge, in proxy: GeometryProxy) -> CGFloat {
        switch edge {
        case .leading:
            return margin + thumbnailSize.width / 2
        case .trailing:
            return proxy.size.width - margin - thumbnailSize.width / 2
        }
    }

    private func verticalBounds(in proxy: GeometryProxy) -> (top: CGFloat, bottom: CGFloat) {
        let top = proxy.safeAreaInsets.top + margin + thumbnailSize.height / 2
        let keyboardInset = max(proxy.safeAreaInsets.bottom, keyboardHeight)
        let bottom = max(top, proxy.size.height - keyboardInset - margin - thumbnailSize.height / 2)
        return (top, bottom)
    }

    private func clampedY(_ y: CGFloat, in proxy: GeometryProxy) -> CGFloat {
        let bounds = verticalBounds(in: proxy)
        return min(max(y, bounds.top), bounds.bottom)
    }

    private func hiddenEdge(for point: CGPoint, in proxy: GeometryProxy) -> SourcePhotoHiddenEdge? {
        let dockThreshold = thumbnailSize.width * 0.35
        if point.x <= dockThreshold {
            return .leading
        }
        if point.x >= proxy.size.width - dockThreshold {
            return .trailing
        }
        return nil
    }

    private func attachedEdge(for point: CGPoint, in proxy: GeometryProxy) -> SourcePhotoHiddenEdge? {
        if let edge = edgeAttachment?.edge {
            let edgeLaneWidth = thumbnailSize.width * 0.75
            if abs(point.x - visibleEdgeX(for: edge, in: proxy)) <= edgeLaneWidth {
                return edge
            }
        }

        return nil
    }

    private func nearestCorner(to point: CGPoint, in proxy: GeometryProxy) -> SourcePhotoCorner {
        SourcePhotoCorner.allCases.min { lhs, rhs in
            distanceSquared(from: point, to: position(for: lhs, in: proxy))
                < distanceSquared(from: point, to: position(for: rhs, in: proxy))
        } ?? .topTrailing
    }

    private func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private func isTap(_ translation: CGSize) -> Bool {
        abs(translation.width) < 6 && abs(translation.height) < 6
    }

    private func handleTap() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            dragOffset = .zero
            if isEdgeHidden {
                isEdgeHidden = false
            } else {
                action()
            }
        }
    }

    private func updateKeyboardHeight(from note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.keyWindow
        else {
            keyboardHeight = 0
            return
        }

        let converted = window.convert(frame, from: nil)
        keyboardHeight = max(0, window.bounds.maxY - converted.minY)
    }
}

private struct SourcePhotoViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            SourcePhotoLiveTextView(image: image)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                    .padding(18)
            }
            .accessibilityLabel(String(localized: "action.close", defaultValue: "Close"))
        }
    }
}

private struct SourcePhotoLiveTextView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> SourcePhotoViewController {
        SourcePhotoViewController(image: image)
    }

    func updateUIViewController(_ viewController: SourcePhotoViewController, context: Context) {
        viewController.setImage(image)
    }
}

private final class SourcePhotoViewController: UIViewController, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var currentImage: UIImage?
    private var shouldResetZoom = true
    private var lastLayoutBounds: CGSize = .zero

    #if canImport(VisionKit)
    private let analyzer = ImageAnalyzer()
    private let interaction = ImageAnalysisInteraction()
    private var analysisTask: Task<Void, Never>?
    #endif

    init(image: UIImage) {
        self.currentImage = image
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.maximumZoomScale = 5
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        #if canImport(VisionKit)
        imageView.addInteraction(interaction)
        interaction.preferredInteractionTypes = .textSelection
        #endif

        if let currentImage {
            setImage(currentImage)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        layoutImage()
    }

    func setImage(_ image: UIImage) {
        guard currentImage !== image || imageView.image == nil else { return }
        currentImage = image
        imageView.image = image
        shouldResetZoom = true
        view.setNeedsLayout()
        analyzeImage(image)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    deinit {
        #if canImport(VisionKit)
        analysisTask?.cancel()
        #endif
    }

    private func layoutImage() {
        guard let image = imageView.image, scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }

        let boundsSize = scrollView.bounds.size
        let layoutBoundsChanged = lastLayoutBounds != boundsSize
        lastLayoutBounds = boundsSize

        let fittedSize = aspectFitSize(for: image.size, in: boundsSize)
        imageView.bounds = CGRect(origin: .zero, size: fittedSize)
        imageView.center = CGPoint(x: fittedSize.width / 2, y: fittedSize.height / 2)
        scrollView.contentSize = fittedSize
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5

        if shouldResetZoom || layoutBoundsChanged {
            scrollView.zoomScale = 1
            shouldResetZoom = false
        } else if scrollView.zoomScale < scrollView.minimumZoomScale {
            scrollView.zoomScale = scrollView.minimumZoomScale
        }

        centerImage()
    }

    private func aspectFitSize(for imageSize: CGSize, in boundsSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return boundsSize }
        let scale = min(boundsSize.width / imageSize.width, boundsSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func centerImage() {
        let horizontalInset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
        let verticalInset = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
    }

    private func analyzeImage(_ image: UIImage) {
        #if canImport(VisionKit)
        guard ImageAnalyzer.isSupported else { return }
        analysisTask?.cancel()
        interaction.analysis = nil
        analysisTask = Task { [analyzer, interaction] in
            do {
                let analysis = try await analyzer.analyze(image, configuration: ImageAnalyzer.Configuration([.text]))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    interaction.analysis = analysis
                    interaction.preferredInteractionTypes = .textSelection
                }
            } catch {
                // The image remains zoomable even when Live Text analysis is unavailable.
            }
        }
        #endif
    }
}

// MARK: - CameraPickerView

private struct CameraPickerView: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            completion(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            completion(nil)
        }
    }
}
