//
//  CreateRecipeView+ModeScan.swift
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
    // MARK: - Scanning overlay

    var scanningOverlay: some View {
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

    var modeSelectionPage: some View {
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
                        description: String(localized: "create.mode.weight.description", defaultValue: "Best for entering an existing recipe as-is, recipes without flour, or exact gram amounts"),
                        accessibilityID: "byWeightModeCard"
                    ) {
                        inputMode = .byWeight
                        navPath.append(.details)
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            isRecipeNameFocused = true
                        }
                    }

                    ModeCard(
                        icon: "link",
                        title: String(localized: "create.mode.website_import.title", defaultValue: "Import from Link"),
                        description: String(localized: "create.mode.website_import.description", defaultValue: "Paste a recipe URL and review the structured recipe data Doughy finds")
                    ) {
                        websiteImportSheetInitialURL = nil
                        showWebsiteImportSheet = true
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
    
    var closeButton: some View {
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
    var scanCard: some View {
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
    var scanCardForAvailableOS: some View {
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
                description: String(localized: "create.mode.scan.description", defaultValue: "Use Apple Intelligence to read a recipe from photos or screenshots, entirely on-device and offline")
            ) {
                showScanOptions = true
            }
            .scanSourceConfirmationDialog(
                isPresented: $showScanOptions,
                showPhotoPicker: $showPhotoPicker,
                showCamera: $showCamera
            )
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

    var scanReviewFormContent: some View {
        Form {
            if !pendingNameChoices.isEmpty {
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

            if !pendingUncertainIngredients.isEmpty {
                Section {
                    ForEach(pendingUncertainIngredients.indices, id: \.self) { index in
                        UncertainIngredientReviewRow(
                            editedName: $pendingUncertainIngredients[index].editedName,
                            shouldRemove: $pendingUncertainIngredients[index].shouldRemove
                        )
                        .accessibilityIdentifier("uncertainIngredientReviewRow_\(index)")
                    }
                } header: {
                    Text("Flagged Ingredients")
                } footer: {
                    Text("These didn't clearly match a real ingredient. Fix the name, or remove the row if it shouldn't be here.")
                }
            }
        }
    }

    var scanReviewForm: some View {
        scanReviewFormContent
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
                    applyUncertainIngredients()
                    navPath.append(.details)
                    scheduleNextScanPrompt()
                }
                .disabled(!scanReviewReady)
                .accessibilityIdentifier("scanReviewContinueButton")
            }
        }
        .keyboardDismissible()
    }

    var scanReviewReady: Bool {
        pendingNameChoices.allSatisfy { !$0.selectedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

}
