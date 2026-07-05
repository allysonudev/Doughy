//
//  CreateRecipeView+Body.swift
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
    // MARK: - Body

    var body: some View {
        coreView
            .overlay { if isScanning { scanningOverlay } }
            .overlay {
                if let image = sourcePhotoImages.first, !isScanning, !usesRecipeStudio {
                    SourcePhotoPipView(
                        image: image,
                        imageCount: sourcePhotoImages.count,
                        corner: $sourcePhotoCorner
                    ) {
                        showSourcePhotoViewer = true
                    }
                }
            }
            .fullScreenCover(isPresented: $showSourcePhotoViewer) {
                if !sourcePhotoImages.isEmpty {
                    SourcePhotoViewer(images: sourcePhotoImages)
                }
            }
            .task {
                openInitialWebsiteImportIfNeeded()
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
                    guard let image else {
                        if cameraScanImages.isEmpty {
                            showCameraScanOptions = false
                        }
                        return
                    }
                    cameraScanImages.append(image)
                    showCameraScanOptions = true
                }
            }
            .confirmationDialog(
                String(localized: "create.scan.camera.pages.title", defaultValue: "Scan Pages"),
                isPresented: $showCameraScanOptions,
                titleVisibility: .visible
            ) {
                Button(String(
                    format: String(localized: "create.scan.camera.scan_count", defaultValue: "Scan %d Photo(s)"),
                    cameraScanImages.count
                )) {
                    let images = cameraScanImages
                    cameraScanImages = []
                    #if canImport(FoundationModels)
                    if #available(iOS 26, *) {
                        Task { await processImages(images) }
                    }
                    #endif
                }
                Button(String(localized: "create.scan.camera.add_another", defaultValue: "Take Another Photo")) {
                    showCamera = true
                }
                Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
                Button(String(localized: "create.scan.camera.discard", defaultValue: "Discard Photos"), role: .destructive) {
                    cameraScanImages = []
                }
            } message: {
                Text(String(localized: "create.scan.camera.pages.message", defaultValue: "Take photos in recipe order. Doughy will read them together."))
            }
            .sheet(isPresented: $showWebsiteImportSheet) {
                WebsiteRecipeImportView(initialURL: websiteImportSheetInitialURL) {
                    showWebsiteImportSheet = false
                    websiteImportSheetInitialURL = nil
                } onImport: { draft in
                    showWebsiteImportSheet = false
                    websiteImportSheetInitialURL = nil
                    applyWebsiteDraft(draft)
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

    func openInitialScanOptionsIfNeeded() {
        guard openScanOptionsOnAppear, !didOpenInitialScanOptions else { return }
        didOpenInitialScanOptions = true
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if usesStudioStart {
                selectedStudioStartOption = .scan
            }
            showScanOptions = true
        }
        #endif
    }

    func openInitialWebsiteImportIfNeeded() {
        guard let url = initialWebsiteImportURL, !didOpenInitialWebsiteImport else { return }
        didOpenInitialWebsiteImport = true
        websiteImportSheetInitialURL = url
        showWebsiteImportSheet = true
    }

    @ViewBuilder
    var coreView: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            createSurface
                .photosPicker(isPresented: $showPhotoPicker,
                               selection: $selectedPhotoItems,
                               maxSelectionCount: 12,
                               selectionBehavior: .ordered,
                               matching: .images)
                .onChange(of: selectedPhotoItems) { _, items in
                    guard !items.isEmpty else { return }
                    Task { await processPickedPhotos(items) }
                }
        } else {
            createSurface
        }
        #else
        createSurface
        #endif
    }

    @ViewBuilder
    var createSurface: some View {
        if usesStudioStart {
            tabletModeSelectionStudio
        } else if usesRecipeStudio {
            tabletRecipeStudio
        } else {
            navigationStack
        }
    }

    var usesStudioStart: Bool {
        horizontalSizeClass == .regular && editingRecipe == nil && copyingRecipe == nil && inputMode == nil
    }

    var usesRecipeStudio: Bool {
        horizontalSizeClass == .regular && (editingRecipe != nil || copyingRecipe != nil || inputMode != nil)
    }

    var tabletModeSelectionStudio: some View {
        NavigationStack {
            GeometryReader { proxy in
                let usesPortraitLayout = tabletStudioUsesPortraitLayout(proxy.size)

                HStack(spacing: 0) {
                    studioStartOutline
                        .frame(width: usesPortraitLayout ? 190 : 220)

                    PaneDivider()

                    studioStartEditor(showsCompactAction: usesPortraitLayout)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !usesPortraitLayout {
                        PaneDivider()

                        studioStartPreviewPane
                            .frame(width: 400)
                    }
                }
                .paneBackground(Color(.systemGroupedBackground))
            }
            .navigationTitle(String(localized: "create.title.new", defaultValue: "New Recipe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                        .accessibilityIdentifier("studioStartCloseButton")
                }
            }
        }
    }

    var studioStartOutline: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "create.title.new", defaultValue: "New Recipe"))
                    .font(.headline)
                Text("Choose a starting point")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Label("Start", systemImage: "sparkles")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                Label("Details", systemImage: "text.cursor")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                Label("Ingredients", systemImage: "list.bullet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                Label("Preview & Save", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
            }

            Spacer()
        }
        .padding(18)
        .paneBackground(Color(.systemBackground))
    }

    func studioStartEditor(showsCompactAction: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose Starting Point")
                        .font(.title2.bold())
                    Text("Pick how you want to build this recipe. The next step opens in the Recipe Studio.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color(.systemBackground))

            VStack(alignment: .leading, spacing: 14) {
                ForEach(StudioStartOption.allCases, id: \.self) { option in
                    studioStartOptionButton(option)
                }
                Spacer()
            }
            .padding(24)

            if showsCompactAction {
                Divider()
                studioStartCompactActionPane
            }
        }
    }

    func studioStartOptionButton(_ option: StudioStartOption) -> some View {
        let isSelected = selectedStudioStartOption == option
        let isEnabled = studioStartOptionIsEnabled(option)

        return Button {
            selectedStudioStartOption = option
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: option.systemImage)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(option.title)
                    .font(.headline)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.65) : Color(.separator), lineWidth: isSelected ? 1.5 : 0.7)
            }
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityIdentifier("studioStartOption_\(option)")
    }

    var studioStartPreviewPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Starting Point")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: selectedStudioStartOption.systemImage)
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 48, height: 48)

                    Text(selectedStudioStartOption.title)
                        .font(.title3.bold())

                    Text(selectedStudioStartOption == .scan && !selectedStudioStartOptionIsEnabled
                         ? studioScanUnavailableMessage
                         : selectedStudioStartOption.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 0.7)
                }

                HStack {
                    Button(studioStartPrimaryTitle) {
                        continueFromStudioStart()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!selectedStudioStartOptionIsEnabled)
                    .scanSourceConfirmationDialog(
                        isPresented: $showScanOptions,
                        showPhotoPicker: $showPhotoPicker,
                        showCamera: $showCamera
                    )
                    Spacer()
                }
            }
            .padding(18)
        }
        .paneBackground(Color(.secondarySystemGroupedBackground))
    }

    var studioStartCompactActionPane: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: selectedStudioStartOption.systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedStudioStartOption.title)
                    .font(.headline)
                Text(selectedStudioStartOption == .scan && !selectedStudioStartOptionIsEnabled
                     ? studioScanUnavailableMessage
                     : selectedStudioStartOption.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button(studioStartPrimaryTitle) {
                continueFromStudioStart()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!selectedStudioStartOptionIsEnabled)
            .scanSourceConfirmationDialog(
                isPresented: $showScanOptions,
                showPhotoPicker: $showPhotoPicker,
                showCamera: $showCamera
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .paneBackground(Color(.systemBackground))
    }

    var studioStartPrimaryTitle: String {
        selectedStudioStartOption == .scan ? "Choose Source" : "Continue"
    }

    var selectedStudioStartOptionIsEnabled: Bool {
        studioStartOptionIsEnabled(selectedStudioStartOption)
    }

    func studioStartOptionIsEnabled(_ option: StudioStartOption) -> Bool {
        option != .scan || studioScanAvailable
    }

    var studioScanAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
    }

    var studioScanUnavailableMessage: String {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return StudioStartOption.scan.subtitle
            case .unavailable(.deviceNotEligible):
                return String(localized: "create.mode.scan.device_not_eligible", defaultValue: "Requires iPhone 15 or later")
            case .unavailable(.modelNotReady):
                return String(localized: "create.mode.scan.model_not_ready", defaultValue: "Apple Intelligence is still setting up")
            case .unavailable(.appleIntelligenceNotEnabled):
                return String(localized: "create.mode.scan.apple_intelligence_not_enabled", defaultValue: "Enable Apple Intelligence in Settings > Apple Intelligence & Siri")
            @unknown default:
                return String(localized: "create.mode.scan.unavailable", defaultValue: "Requires iOS 26 or later with Apple Intelligence")
            }
        }
        #endif
        return String(localized: "create.mode.scan.unavailable", defaultValue: "Requires iOS 26 or later with Apple Intelligence")
    }

    func continueFromStudioStart() {
        switch selectedStudioStartOption {
        case .percent:
            enterStudio(mode: .byPercent)
        case .weight:
            enterStudio(mode: .byWeight)
        case .websiteImport:
            websiteImportSheetInitialURL = nil
            showWebsiteImportSheet = true
        case .scan:
            guard studioScanAvailable else { return }
            showScanOptions = true
        }
    }

    func enterStudio(mode: RecipeInputMode) {
        let previousMode = inputMode ?? modeBeforeReturningToStudioStart
        if let previousMode, previousMode != mode {
            resetModeSpecificDraftFields()
        }
        modeBeforeReturningToStudioStart = nil
        inputMode = mode
        selectedStudioStep = .details
        focusRecipeNameAfterDelay()
    }

    func focusRecipeNameAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            isRecipeNameFocused = true
        }
    }

    var tabletRecipeStudio: some View {
        NavigationStack {
            GeometryReader { proxy in
                let usesPortraitLayout = tabletStudioUsesPortraitLayout(proxy.size)

                HStack(spacing: 0) {
                    studioOutline(showsLandscapeHint: usesPortraitLayout)
                        .frame(width: usesPortraitLayout ? 190 : 220)

                    PaneDivider()

                    studioEditor
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scrollsUnderHomeIndicator()

                    if !usesPortraitLayout && showsStudioSourcePane {
                        PaneDivider()

                        studioPreviewPane
                            .frame(width: 400)
                    }
                }
                .paneBackground(Color(.systemGroupedBackground))
            }
            .navigationTitle(studioTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                        .accessibilityIdentifier("studioCloseButton")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if studioCanMoveBackward {
                        Button("Previous") {
                            studioPreviousAction()
                        }
                        .accessibilityIdentifier("studioPreviousButton")
                    }
                    Button(studioPrimaryActionTitle) {
                        studioPrimaryAction()
                    }
                    .fontWeight(selectedStudioStep == .preview ? .bold : .regular)
                    .disabled(!studioPrimaryActionEnabled)
                    .accessibilityIdentifier("studioPrimaryActionButton")
                }
            }
        }
        .sheet(item: $conversionSheetData) { data in
            extraIngredientConversionSheet(for: data)
        }
        .onChange(of: inputMode) { oldValue, newValue in
            guard let oldValue, let newValue, oldValue != newValue else { return }
            resetModeSpecificDraftFields()
        }
        .onChange(of: containsPreferment) { _, includesPreferment in
            if !includesPreferment && selectedStudioStep == .preferment {
                selectedStudioStep = .ingredients
            }
        }
        .onChange(of: pendingValueRowID) { _, id in
            focusedValueRowID = id
            pendingValueRowID = nil
        }
        .onChange(of: pendingNameChoices.count) { _, count in
            if count > 0 {
                selectedStudioStep = .scanReview
            }
        }
        .onChange(of: pendingUncertainIngredients.count) { _, count in
            if count > 0 {
                selectedStudioStep = .scanReview
            }
        }
    }

    var showsStudioSourcePane: Bool {
        !sourcePhotoImages.isEmpty
    }

    func tabletStudioUsesPortraitLayout(_ size: CGSize) -> Bool {
        size.width < size.height
    }

    var studioTitle: String {
        editingRecipe != nil
            ? String(localized: "create.title.edit", defaultValue: "Edit Recipe")
            : copyingRecipe != nil
            ? String(localized: "create.title.copy", defaultValue: "Copy Recipe")
            : String(localized: "create.title.new", defaultValue: "New Recipe")
    }

    func studioOutline(showsLandscapeHint: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(studioTitle)
                    .font(.headline)
                Text(inputMode == .byWeight
                     ? String(localized: "create.mode.weight.title", defaultValue: "By Weight")
                     : String(localized: "create.mode.percent.title", defaultValue: "By Baker's Percentage"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                if !pendingNameChoices.isEmpty || !pendingUncertainIngredients.isEmpty {
                    studioOutlineButton(step: .scanReview, title: "Scan Review", systemImage: "checklist")
                }
                studioOutlineButton(step: .details, title: "Details", systemImage: "text.cursor")
                if containsPreferment {
                    studioOutlineButton(step: .preferment, title: "Preferment", systemImage: "timer")
                }
                studioOutlineButton(step: .ingredients, title: containsPreferment ? "Main Dough" : "Ingredients", systemImage: "list.bullet")
                studioOutlineButton(step: .preview, title: "Preview & Save", systemImage: "checkmark.circle")
            }

            Spacer()

            #if DOUGHY_SCAN_DIAGNOSTICS
            let showsScanStatus = !sourcePhotoImages.isEmpty || lastScanDiagnostics != nil || !pendingNameChoices.isEmpty || !pendingUncertainIngredients.isEmpty
            #else
            let showsScanStatus = !sourcePhotoImages.isEmpty || !pendingNameChoices.isEmpty || !pendingUncertainIngredients.isEmpty
            #endif

            if showsScanStatus {
                if !sourcePhotoImages.isEmpty {
                    Button {
                        showSourcePhotoViewer = true
                    } label: {
                        studioScanStatusCard(showsLandscapeHint: showsLandscapeHint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("studioSourcePhotoButton")
                } else {
                    studioScanStatusCard(showsLandscapeHint: false)
                }
            }
        }
        .padding(18)
        .paneBackground(Color(.systemBackground))
    }

    func studioScanStatusCard(showsLandscapeHint: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan Review")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            if !pendingNameChoices.isEmpty {
                Text(String(format: "%d ingredient choices", pendingNameChoices.count))
                    .font(.subheadline)
            }
            if !pendingUncertainIngredients.isEmpty {
                Text(String(format: "%d flagged ingredients", pendingUncertainIngredients.count))
                    .font(.subheadline)
            }
            #if DOUGHY_SCAN_DIAGNOSTICS
            if lastScanDiagnostics != nil {
                Text("Diagnostics available")
                    .font(.subheadline)
            }
            #endif
            if !sourcePhotoImages.isEmpty {
                Label(sourcePhotoImages.count == 1 ? "Source photo attached" : "\(sourcePhotoImages.count) source photos attached", systemImage: "photo.on.rectangle")
                    .font(.subheadline)
            }
            if showsLandscapeHint {
                Label("Rotate to landscape to compare with the source images.", systemImage: "rotate.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    func studioOutlineButton(step: CreateStep, title: String, systemImage: String) -> some View {
        Button {
            if studioStepIsEnabled(step) {
                selectedStudioStep = step
            }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.body.weight(selectedStudioStep == step ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(selectedStudioStep == step ? Color.accentColor.opacity(0.14) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(studioStepIsEnabled(step) ? .primary : .secondary)
        .disabled(!studioStepIsEnabled(step))
    }

    var studioEditor: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(studioStepTitle)
                        .font(.title2.bold())
                    Text(studioStepSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color(.systemBackground))

            studioStepContent
        }
    }

    @ViewBuilder
    var studioStepContent: some View {
        switch selectedStudioStep {
        case .scanReview:
            scanReviewFormContent
                .keyboardDismissible()
        case .details:
            detailsFormContent
                .keyboardDismissible()
        case .preferment:
            prefermentFormContent
                .keyboardDismissible()
        case .ingredients:
            ingredientsFormContent
                .keyboardDismissible()
        case .preview:
            previewFormContent
                .environment(\.editMode, .constant(.active))
                .keyboardDismissible()
        }
    }

    var studioPreviewPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Preview / Source")
                    .font(.headline)

                if let image = sourcePhotoImages.first {
                    Button {
                        showSourcePhotoViewer = true
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(sourcePhotoImages.count == 1 ? "Imported Image" : "\(sourcePhotoImages.count) Imported Images", systemImage: "photo.on.rectangle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemBackground))
                        }
                        .padding(10)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor.opacity(0.55), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                }

            }
            .padding(18)
        }
        .paneBackground(Color(.secondarySystemGroupedBackground))
    }

    var activeFlourRows: [FlourRow] {
        containsPreferment ? combinedFlours.filter { !$0.name.isEmpty } : flours.filter { !$0.name.isEmpty }
    }

    var activeIngredientRows: [IngredientRow] {
        containsPreferment ? combinedIngredients.filter { !$0.name.isEmpty } : ingredients.filter { !$0.name.isEmpty }
    }

    var studioCanOpenPreview: Bool {
        detailsReady && (!containsPreferment || prefermentReady) && ingredientsReady
    }

    var studioCanMoveBackward: Bool {
        switch selectedStudioStep {
        case .scanReview, .preferment, .ingredients, .preview:
            true
        case .details:
            editingRecipe == nil && copyingRecipe == nil
        }
    }

    var studioPrimaryActionTitle: String {
        switch selectedStudioStep {
        case .preview:
            editingRecipe != nil
                ? String(localized: "create.action.save_changes", defaultValue: "Save Changes")
                : String(localized: "create.action.save_recipe", defaultValue: "Save Recipe")
        default:
            "Next"
        }
    }

    var studioPrimaryActionEnabled: Bool {
        switch selectedStudioStep {
        case .scanReview:
            scanReviewReady
        case .details:
            detailsReady
        case .preferment:
            prefermentReady
        case .ingredients:
            ingredientsReady
        case .preview:
            studioCanOpenPreview
        }
    }

    var studioStepTitle: String {
        switch selectedStudioStep {
        case .scanReview:
            return "Review Scan"
        case .details:
            return "Recipe Details"
        case .preferment:
            return "Preferment"
        case .ingredients:
            return containsPreferment ? "Main Dough" : "Ingredients"
        case .preview:
            return "Preview & Save"
        }
    }

    var studioStepSubtitle: String {
        switch selectedStudioStep {
        case .scanReview:
            return "Resolve anything uncertain before editing the recipe."
        case .details:
            return "Name the recipe, choose its collection, and set the default batch size."
        case .preferment:
            return "Describe the separately fermented portion before the main dough."
        case .ingredients:
            return containsPreferment
                ? "Add the main dough amounts on top of the preferment."
                : "Enter flours, ingredients, optional temperatures, and extra units."
        case .preview:
            return "Review the recipe, add instructions, and save it to the library."
        }
    }

    func studioStepIsEnabled(_ step: CreateStep) -> Bool {
        switch step {
        case .scanReview:
            !pendingNameChoices.isEmpty || !pendingUncertainIngredients.isEmpty
        case .details:
            true
        case .preferment:
            containsPreferment && detailsReady
        case .ingredients:
            detailsReady && (!containsPreferment || prefermentReady)
        case .preview:
            studioCanOpenPreview
        }
    }

    func studioPrimaryAction() {
        switch selectedStudioStep {
        case .scanReview:
            applyNameChoices()
            applyUncertainIngredients()
            scheduleNextScanPrompt()
            selectedStudioStep = .details
        case .details:
            selectedStudioStep = containsPreferment ? .preferment : .ingredients
        case .preferment:
            syncMainDoughFromPreferment()
            selectedStudioStep = .ingredients
        case .ingredients:
            let candidates = scanExtraIngredientConversions()
            if candidates.isEmpty {
                selectedStudioStep = .preview
            } else {
                conversionSheetData = ExtraIngredientConversionSheetData(candidates: candidates)
            }
        case .preview:
            saveRecipe()
        }
    }

    func studioPreviousAction() {
        switch selectedStudioStep {
        case .scanReview, .details:
            returnToStudioStart()
        case .preferment:
            selectedStudioStep = .details
        case .ingredients:
            selectedStudioStep = containsPreferment ? .preferment : .details
        case .preview:
            selectedStudioStep = .ingredients
        }
    }

    func returnToStudioStart() {
        guard editingRecipe == nil, copyingRecipe == nil else { return }
        if !sourcePhotoImages.isEmpty {
            selectedStudioStartOption = .scan
        } else if inputMode == .byWeight {
            selectedStudioStartOption = .weight
        } else {
            selectedStudioStartOption = .percent
        }
        modeBeforeReturningToStudioStart = inputMode
        inputMode = nil
        selectedStudioStep = .details
    }

    var navigationStack: some View {
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
            resetModeSpecificDraftFields()
        }
    }

    func resetModeSpecificDraftFields() {
        defaultWeight = nil
        for i in flours.indices { flours[i].value = nil }
        for i in ingredients.indices { ingredients[i].value = nil }
        prefermentFlourPercent = nil
        for i in prefermentFlours.indices { prefermentFlours[i].value = nil }
        for i in prefermentIngredientRows.indices { prefermentIngredientRows[i].value = nil }
        detectedRecipeLanguage = nil
    }

}
