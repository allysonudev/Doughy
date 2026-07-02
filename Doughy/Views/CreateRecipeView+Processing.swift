//
//  CreateRecipeView+Processing.swift
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
    // MARK: - Website import processing

    func applyWebsiteDraft(_ draft: WebsiteRecipeDraft) {
        recipeName = draft.name
        inputMode = .byWeight
        defaultWeight = nil
        detectedRecipeLanguage = nil
        containsPreferment = false
        prefermentName = ""
        prefermentFlourPercent = nil
        prefermentFlours = [FlourRow()]
        prefermentIngredientRows = [IngredientRow()]
        pendingNameChoices = []
        pendingUncertainIngredients = []
        pendingConversions = []
        activeConversion = nil
        conversionSheetData = nil
        #if DOUGHY_SCAN_DIAGNOSTICS
        lastScanDiagnostics = nil
        #endif
        sourcePhotoImage = nil

        let weightedIngredients = draft.resolvedIngredients
            .filter { !$0.isExtra && $0.weightGrams > 0 }
        let totalFlourWeight = weightedIngredients
            .filter(\.isFlour)
            .reduce(0) { $0 + $1.weightGrams }

        let importedFlours = weightedIngredients
            .filter(\.isFlour)
            .map { FlourRow(name: $0.name, value: $0.weightGrams) }
        flours = importedFlours.isEmpty ? [FlourRow()] : importedFlours

        var importedIngredients = weightedIngredients
            .filter { !$0.isFlour }
            .map { IngredientRow(name: $0.name, value: $0.weightGrams) }

        let resolvedLines = Set(draft.resolvedIngredients.map(\.originalLine))
        let unresolvedRows = draft.ingredientLines
            .filter { !resolvedLines.contains($0) }
            .map { IngredientRow(name: $0, value: nil) }
        importedIngredients.append(contentsOf: unresolvedRows)
        ingredients = importedIngredients.isEmpty ? [IngredientRow()] : importedIngredients

        lastTotalFlourWeight = totalFlourWeight
        lastTotalPrefFlourWeight = 0
        extraIngredients = []
        pendingConversions = []
        for extra in draft.resolvedIngredients where extra.isExtra && extra.extraAmount > 0 {
            if !ExtraIngredientConversion.canLearnGramConversion(for: extra.extraUnit)
                || IngredientConversionStore.shared.isAlwaysExtra(name: extra.name, unit: extra.extraUnit) {
                extraIngredients.append(ExtraIngredientRow(name: extra.name,
                                                           amount: extra.extraAmount,
                                                           unit: extra.extraUnit,
                                                           isPreferment: false))
            } else {
                pendingConversions.append(PendingConversion(name: extra.name,
                                                            amount: extra.extraAmount,
                                                            unit: extra.extraUnit,
                                                            isPreferment: false))
            }
        }

        instructions = draft.instructions.map { InstructionRow(text: $0) }
        navPath = [.details]
        scheduleNextScanPrompt(after: 0.4)
    }

    // MARK: - AI scan processing

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    func processPickedPhoto(_ item: PhotosPickerItem) async {
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
    func processImage(_ image: UIImage) async {
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
    func localizedIngredientName(for ingredient: ResolvedIngredient) -> String {
        guard ingredient.category != .other,
              let cat = IngredientCategory(rawValue: ingredient.category.rawValue) else {
            return ingredient.name
        }
        return cat.localizedDisplayName
    }

    /// Reverse-looks-up an IngredientCategory by its English display name and returns the
    /// localized name, falling back to `name` when no match is found. Used to localize
    /// alternative ingredient names from the scanner (e.g. "Bread Flour" → "Harina de fuerza").
    func localizedAltName(_ name: String) -> String {
        IngredientCategory.allCases
            .first { $0.displayName.caseInsensitiveCompare(name) == .orderedSame }
            .map(\.localizedDisplayName) ?? name
    }

    @available(iOS 26, *)
    func applyParsed(_ result: ScanResult) throws {
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
            #if DOUGHY_SCAN_DIAGNOSTICS
            lastScanDiagnostics = makeScanDiagnostics(result: result, defaultWeightGrams: nil,
                                                       flours: [], ingredients: [], extras: [], preferment: nil)
            #endif
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
        pendingUncertainIngredients = []
        activeConversion = nil

        flours = mainFlours.map {
            FlourRow(name: localizedIngredientName(for: $0), value: $0.weightGrams)
        }
        queueNameChoices(source: mainFlours, rows: flours, kind: .flour)
        queueUncertainIngredients(source: mainFlours, rows: flours, kind: .flour)
        if flours.isEmpty { flours = [FlourRow()] }

        ingredients = mainOthers.map {
            IngredientRow(name: localizedIngredientName(for: $0), value: $0.weightGrams, tempValue: scannedTempValue(for: $0))
        }
        queueNameChoices(source: mainOthers, rows: ingredients, kind: .ingredient)
        queueUncertainIngredients(source: mainOthers, rows: ingredients, kind: .ingredient)
        if ingredients.isEmpty { ingredients = [IngredientRow()] }

        instructions = parsed.instructions.map { InstructionRow(text: $0) }

        #if DOUGHY_SCAN_DIAGNOSTICS
        var diagPreferment: ScanDiagnostics.DiagFinalRecipe.DiagPreferment? = nil
        #endif
        if parsed.hasPreferment && totalPrefFlourWeight > 0 {
            containsPreferment = true
            prefermentName = parsed.prefermentName
            prefermentFlourPercent = totalPrefFlourWeight / totalFlourWeight * 100

            let prefFlourRows = prefFlours.map {
                FlourRow(name: localizedIngredientName(for: $0), value: $0.weightGrams)
            }
            queueNameChoices(source: prefFlours, rows: prefFlourRows, kind: .prefermentFlour)
            queueUncertainIngredients(source: prefFlours, rows: prefFlourRows, kind: .prefermentFlour)
            prefermentFlours = prefFlourRows.isEmpty ? [FlourRow()] : prefFlourRows

            let prefIngRows = prefOthers.map {
                IngredientRow(name: localizedIngredientName(for: $0), value: $0.weightGrams, tempValue: scannedTempValue(for: $0))
            }
            queueNameChoices(source: prefOthers, rows: prefIngRows, kind: .prefermentIngredient)
            queueUncertainIngredients(source: prefOthers, rows: prefIngRows, kind: .prefermentIngredient)
            prefermentIngredientRows = prefIngRows.isEmpty ? [IngredientRow()] : prefIngRows

            // Pre-seed the "Main Dough" step with any preferment ingredient names not
            // already present (e.g. when all of a flour is in the preferment).
            syncMainDoughFromPreferment()

            #if DOUGHY_SCAN_DIAGNOSTICS
            diagPreferment = .init(
                name: prefermentName,
                flourPercentOfTotalFlour: prefermentFlourPercent ?? 0,
                ingredients: prefFlourRows.map { .init(name: $0.name, percent: $0.value ?? 0) }
                    + prefIngRows.map { .init(name: $0.name, percent: $0.value ?? 0) }
            )
            #endif
        } else {
            containsPreferment = false
        }

        logScanAlternatives(in: parsed.ingredients, queuedPromptCount: pendingNameChoices.count)

        // Extra ingredients with no reliable volume conversion: queue a prompt for each so
        // the user can teach us the conversion (used now and remembered for next time)
        // or leave it in its original unit. Count-based extras are not learnable volume
        // conversions, so they stay as extras without prompting.
        lastTotalFlourWeight = totalFlourWeight
        lastTotalPrefFlourWeight = totalPrefFlourWeight
        extraIngredients = []
        pendingConversions = []
        for extra in extras {
            let unit = extra.extraUnit.rawValue
            if !ExtraIngredientConversion.canLearnGramConversion(for: unit)
                || IngredientConversionStore.shared.isAlwaysExtra(name: extra.name, unit: unit) {
                extraIngredients.append(ExtraIngredientRow(name: extra.name, amount: extra.extraAmount,
                                                             unit: unit, isPreferment: extra.isPreferment))
            } else {
                pendingConversions.append(PendingConversion(name: extra.name, amount: extra.extraAmount,
                                                              unit: unit, isPreferment: extra.isPreferment))
            }
        }

        #if DOUGHY_SCAN_DIAGNOSTICS
        lastScanDiagnostics = makeScanDiagnostics(
            result: result,
            defaultWeightGrams: defaultWeight,
            flours: flours.map { .init(name: $0.name, percent: $0.value ?? 0) },
            ingredients: ingredients.map { .init(name: $0.name, percent: $0.value ?? 0) },
            extras: extras.map { .init(name: $0.name, amount: $0.extraAmount, unit: $0.extraUnit.rawValue, isPreferment: $0.isPreferment) },
            preferment: diagPreferment
        )
        #endif

        inputMode = .byWeight
        if pendingNameChoices.isEmpty && pendingUncertainIngredients.isEmpty {
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
    func scannedTempValue(for ingredient: ResolvedIngredient) -> Double? {
        guard let fahrenheit = ingredient.temperatureFahrenheit else { return nil }
        return TemperatureConverter.shared.convert(temperature: fahrenheit, source: .fahrenheit,
                                                     target: Settings.shared.preferredTemp())
    }

    /// Queues a `PendingNameChoice` for each row whose source ingredient had a non-nil
    /// `alternativeName`. `source` and `rows` must correspond 1:1 in the same order (true
    /// for the `.map` calls that build `rows` from `source`).
    @available(iOS 26, *)
    func queueNameChoices<Row: Identifiable>(source: [ResolvedIngredient], rows: [Row], kind: IngredientRowKind) where Row.ID == UUID {
        for (resolved, row) in zip(source, rows) {
            guard let alt = resolved.alternativeName, !alt.isEmpty else { continue }
            pendingNameChoices.append(PendingNameChoice(rowID: row.id, kind: kind,
                                                          primaryName: localizedIngredientName(for: resolved),
                                                          alternativeName: localizedAltName(alt),
                                                          selectedName: localizedIngredientName(for: resolved)))
        }
    }

    /// Queues a `PendingUncertainIngredient` for each row whose source ingredient was
    /// flagged by the on-device cleanup pass. Same 1:1 pairing contract as `queueNameChoices`.
    @available(iOS 26, *)
    func queueUncertainIngredients<Row: Identifiable>(source: [ResolvedIngredient], rows: [Row], kind: IngredientRowKind) where Row.ID == UUID {
        for (resolved, row) in zip(source, rows) {
            guard resolved.isUncertain else { continue }
            let name = localizedIngredientName(for: resolved)
            pendingUncertainIngredients.append(PendingUncertainIngredient(rowID: row.id, kind: kind,
                                                                            suggestedName: name,
                                                                            editedName: name))
        }
    }

    @available(iOS 26, *)
    func logScanAlternatives(in ingredients: [ResolvedIngredient], queuedPromptCount: Int) {
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

    func scheduleNextScanPrompt(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            presentNextScanPrompt()
        }
    }

    func presentNextScanPrompt() {
        guard activeConversion == nil else { return }

        if !pendingConversions.isEmpty {
            activeConversion = pendingConversions.removeFirst()
            return
        }
    }

    #if DOUGHY_SCAN_DIAGNOSTICS
    @available(iOS 26, *)
    func makeScanDiagnostics(result: ScanResult,
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
    #endif

    /// Handles the user's response to an "unknown ingredient" conversion prompt: either
    /// saves the provided gram conversion and folds the ingredient into the regular
    /// percent-based ingredients, or keeps it as an "extra" ingredient in its original unit.
    func resolveConversionPrompt(useGrams: Bool) {
        guard let pending = activeConversion else { return }
        activeConversion = nil
        defer {
            conversionGramsText = ""
            scheduleNextScanPrompt(after: 0.4)
        }

        if useGrams, let perUnit = Double(conversionGramsText), perUnit > 0 {
            IngredientConversionStore.shared.save(name: pending.name, unit: pending.unit, gramsPerUnit: perUnit)
            let totalGrams = pending.amount * perUnit

            if let value = convertedValue(grams: totalGrams, isPreferment: pending.isPreferment) {
                addConvertedIngredient(name: pending.name, value: value, isPreferment: pending.isPreferment)
            } else {
                extraIngredients.append(ExtraIngredientRow(name: pending.name, amount: pending.amount,
                                                             unit: pending.unit, isPreferment: pending.isPreferment))
            }
        } else {
            IngredientConversionStore.shared.markAsExtra(name: pending.name, unit: pending.unit)
            extraIngredients.append(ExtraIngredientRow(name: pending.name, amount: pending.amount,
                                                         unit: pending.unit, isPreferment: pending.isPreferment))
        }
    }

    func applyNameChoices() {
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

    /// Applies the user's edited name for each flagged ingredient, or removes the row
    /// entirely when marked for removal.
    func applyUncertainIngredients() {
        for pending in pendingUncertainIngredients {
            if pending.shouldRemove {
                switch pending.kind {
                case .flour:
                    flours.removeAll { $0.id == pending.rowID }
                case .ingredient:
                    ingredients.removeAll { $0.id == pending.rowID }
                case .prefermentFlour:
                    prefermentFlours.removeAll { $0.id == pending.rowID }
                case .prefermentIngredient:
                    prefermentIngredientRows.removeAll { $0.id == pending.rowID }
                }
                continue
            }

            let edited = pending.editedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !edited.isEmpty else { continue }

            switch pending.kind {
            case .flour:
                if let index = flours.firstIndex(where: { $0.id == pending.rowID }) {
                    flours[index].name = edited
                }
            case .ingredient:
                if let index = ingredients.firstIndex(where: { $0.id == pending.rowID }) {
                    ingredients[index].name = edited
                }
            case .prefermentFlour:
                if let index = prefermentFlours.firstIndex(where: { $0.id == pending.rowID }) {
                    prefermentFlours[index].name = edited
                }
            case .prefermentIngredient:
                if let index = prefermentIngredientRows.firstIndex(where: { $0.id == pending.rowID }) {
                    prefermentIngredientRows[index].name = edited
                }
            }
        }
    }

    // MARK: - Save

    func saveRecipe() {
        do {
            let recipe = try buildRecipe()
            if let existing = editingRecipe {
                try store.update(recipe: recipe, existingName: existing.name, existingCollection: existing.collection)
            } else {
                try store.save(recipe: recipe, recordsAddedCollection: copyingRecipe == nil)
            }
            appearanceStore.set(
                CollectionAppearance(iconKey: collectionIconKey, colorKey: collectionColorKey),
                for: effectiveCollection.trimmingCharacters(in: .whitespaces)
            )
            onSave?(recipe)
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

    func buildRecipe() throws -> any RecipeProtocol {
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
