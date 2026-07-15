//
//  CreateRecipeTypes.swift
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

// MARK: - Types

enum RecipeInputMode {
    case byPercent
    case byWeight
}

enum StudioStartOption: CaseIterable {
    case percent
    case weight
    case websiteImport
    case scan

    var title: String {
        switch self {
        case .percent:
            return String(localized: "create.mode.percent.title", defaultValue: "By Baker's Percentage")
        case .weight:
            return String(localized: "create.mode.weight.title", defaultValue: "By Weight")
        case .websiteImport:
            return String(localized: "create.mode.website_import.title", defaultValue: "Import from Link")
        case .scan:
            return String(localized: "create.mode.scan.title", defaultValue: "Scan a Recipe")
        }
    }

    var subtitle: String {
        switch self {
        case .percent:
            return String(localized: "create.mode.percent.description", defaultValue: "Best for flour-based doughs where ingredients scale from total flour")
        case .weight:
            return String(localized: "create.mode.weight.description", defaultValue: "Best for entering an existing recipe as-is, recipes without flour, or exact gram amounts")
        case .websiteImport:
            return String(localized: "create.mode.website_import.description", defaultValue: "Paste a recipe URL and review the structured recipe data Doughy finds")
        case .scan:
            return String(localized: "create.mode.scan.description", defaultValue: "Use Apple Intelligence to read a recipe from a photo or screenshot, entirely on-device and offline")
        }
    }

    var systemImage: String {
        switch self {
        case .percent: return "percent"
        case .weight: return "scalemass"
        case .websiteImport: return "link"
        case .scan: return "camera.viewfinder"
        }
    }
}

enum SourcePhotoCorner: CaseIterable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

enum SourcePhotoHiddenEdge: Equatable {
    case leading
    case trailing
}

struct SourcePhotoEdgeAttachment: Equatable {
    var edge: SourcePhotoHiddenEdge
    var y: CGFloat
}

struct FlourRow: Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var value: Double? = nil  // percent in .byPercent, grams in .byWeight

    static func == (lhs: FlourRow, rhs: FlourRow) -> Bool {
        lhs.name == rhs.name && lhs.value == rhs.value
    }
}

struct IngredientRow: Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var value: Double? = nil  // percent or grams depending on mode
    var tempValue: Double? = nil

    static func == (lhs: IngredientRow, rhs: IngredientRow) -> Bool {
        lhs.name == rhs.name && lhs.value == rhs.value && lhs.tempValue == rhs.tempValue
    }
}

struct InstructionRow: Identifiable {
    var id = UUID()
    var text: String
}

/// A ParseableFormatStyle for decimal number fields (.decimalPad keyboard) that displays
/// with the app language's decimal separator but accepts both "." and "," when parsing,
/// so hardware-keyboard input works correctly in any locale (e.g. German/Icelandic where
/// "." is a grouping separator and would otherwise be misread as a thousands separator).
struct FlexibleDecimalStyle: ParseableFormatStyle {
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

struct FlexibleDecimalParseStrategy: ParseStrategy {
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
struct ExtraIngredientRow: Identifiable, Equatable {
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
struct IngredientNameField: View {
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

    @FocusState var isFocused: Bool

    var filtered: [String] {
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
                            .accessibilityIdentifier("suggestionChip_\(name)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

struct MoveStepSheet: View {
    let total: Int
    let currentIndex: Int
    @Binding var text: String
    let onMove: (Int) -> Void
    let onDismiss: () -> Void

    @FocusState var isFocused: Bool

    var target: Int? { Int(text).map { $0 - 1 } }
    var isValid: Bool {
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
                .accessibilityIdentifier("moveStepPositionField")
            HStack {
                Spacer()
                Button(String(localized: "action.cancel", defaultValue: "Cancel")) { onDismiss() }
                    .accessibilityIdentifier("moveStepCancelButton")
                Button(String(localized: "create.instructions.move_step.action", defaultValue: "Move")) {
                    if isValid, let t = target { onMove(t) }
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .accessibilityIdentifier("moveStepConfirmButton")
            }
        }
        .padding(24)
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.hidden)
        .onAppear { isFocused = true }
    }
}

struct ScanAlternativeReviewRow: View {
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

/// A row for a `PendingUncertainIngredient`: an editable name (pre-filled with the model's
/// cleaned-up suggestion) plus a toggle to remove the row instead, for ingredients the
/// on-device cleanup pass wasn't confident about.
struct UncertainIngredientReviewRow: View {
    @Binding var editedName: String
    @Binding var shouldRemove: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("We're not sure this is a real ingredient", systemImage: "questionmark.circle")
                .font(.subheadline)
                .foregroundStyle(.orange)

            TextField("Ingredient name", text: $editedName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .strikethrough(shouldRemove)
                .disabled(shouldRemove)

            Toggle("Remove this ingredient", isOn: $shouldRemove)
        }
        .padding(.vertical, 4)
    }
}

/// A suggestion to convert an "additional ingredient" (e.g. "2 large eggs") to a
/// weight-based ingredient, presented to the user with a toggle before continuing
/// past the Ingredients step.
struct ExtraIngredientConversionCandidate: Identifiable {
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
struct ExtraIngredientConversionSheetData: Identifiable {
    let id = UUID()
    var candidates: [ExtraIngredientConversionCandidate]
}

/// A scanned/imported ingredient with no gram conversion, awaiting the user's input on
/// whether they know a gram conversion for it.
struct PendingConversion: Identifiable {
    var id = UUID()
    var name: String
    var amount: Double
    var unit: String
    var isPreferment: Bool
}

/// Which of the four scanned-ingredient arrays a row belongs to, so a queued name
/// choice can locate and update the right row after the user picks.
enum IngredientRowKind {
    case flour
    case ingredient
    case prefermentFlour
    case prefermentIngredient
}

/// A scanned ingredient that listed two alternative names (e.g. "all-purpose flour or
/// bread flour"), awaiting the user's choice of which one to use for that row.
struct PendingNameChoice: Identifiable {
    var id = UUID()
    var rowID: UUID
    var kind: IngredientRowKind
    var primaryName: String
    var alternativeName: String
    var selectedName: String
}

/// A scanned ingredient the on-device cleanup pass wasn't confident about - either its
/// name still needed cleanup, or it might not be a real ingredient at all (e.g. leaked
/// instruction text). Non-blocking: defaults to kept with the model's suggested name
/// rather than forcing a decision before the user can continue.
struct PendingUncertainIngredient: Identifiable {
    var id = UUID()
    var rowID: UUID
    var kind: IngredientRowKind
    var suggestedName: String
    var editedName: String
    var shouldRemove: Bool = false
}

enum CreateStep: Hashable {
    case scanReview
    case details
    case ingredients
    case preferment
    case preview
}

/// A snapshot of the editable fields of the recipe draft, used to detect unsaved changes
/// so the user can be warned before discarding them.
struct DraftSnapshot: Equatable {
    var recipeName = ""
    var collectionName = ""
    var isNewCollection = false
    var newCollectionText = ""
    var defaultWeight: Double? = nil
    var containsPreferment = false
    var sourceURL: String?
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
#if DOUGHY_SCAN_DIAGNOSTICS
struct ScanDiagnostics: Codable {
    var sourceKind: String?
    var sourceURL: String?
    var structuredRecipeJSON: String?
    var ocrText: String
    var pageOCR: [DiagPageOCR]?
    var websiteIngredientLines: [String]?
    var websiteInstructions: [String]?
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

    struct DiagPageOCR: Codable {
        var imageIndex: Int
        var text: String
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
#endif
