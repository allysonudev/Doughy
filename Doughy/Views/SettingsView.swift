//
//  SettingsView.swift
//  Doughy

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct AppLanguage: Identifiable {
    let code: String
    let nativeName: String
    var id: String { code }

    static let all: [AppLanguage] = [
        .init(code: "ar",    nativeName: "العربية"),
        .init(code: "da",    nativeName: "Dansk"),
        .init(code: "de",    nativeName: "Deutsch"),
        .init(code: "en",    nativeName: "English"),
        .init(code: "es",    nativeName: "Español"),
        .init(code: "fr",    nativeName: "Français"),
        .init(code: "hi",    nativeName: "हिन्दी"),
        .init(code: "is",    nativeName: "Íslenska"),
        .init(code: "it",    nativeName: "Italiano"),
        .init(code: "ja",    nativeName: "日本語"),
        .init(code: "ko",    nativeName: "한국어"),
        .init(code: "nb",    nativeName: "Norsk bokmål"),
        .init(code: "pt-BR", nativeName: "Português (Brasil)"),
        .init(code: "sv",    nativeName: "Svenska"),
    ]
}

private enum SettingsPane: Hashable, CaseIterable {
    case preferences
    case conversions
    case library
    case about

    var title: String {
        switch self {
        case .preferences:
            return String(localized: "settings.preferences.title", defaultValue: "Preferences")
        case .conversions:
            return String(localized: "conversions.title", defaultValue: "Ingredient Conversions")
        case .library:
            return String(localized: "settings.library.title", defaultValue: "Library")
        case .about:
            return String(localized: "settings.about.title", defaultValue: "About")
        }
    }

    var systemImage: String {
        switch self {
        case .preferences:
            return "slider.horizontal.3"
        case .conversions:
            return "scalemass"
        case .library:
            return "books.vertical"
        case .about:
            return "info.circle"
        }
    }

    var sortIndex: Int {
        SettingsPane.allCases.firstIndex(of: self) ?? 0
    }
}

struct SettingsView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(CollectionAppearanceStore.self) private var appearanceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTemp: Temperature.Measurement = Settings.shared.preferredTemp()
    @State private var selectedVolumeSystem: VolumeSystem = Settings.shared.preferredVolumeSystem()
    @State private var selectedLanguage: String = Settings.shared.preferredLanguageCode() ?? ""
    @State private var selectedPane: SettingsPane? = .preferences
    @State private var settingsColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var paneTransitionEdge: Edge = .bottom
    @State private var tempUpdateError: String?
    @State private var backupRestoreMessage: String?
    @State private var pendingRestoreBackup: RecipeLibraryBackup?
    @State private var showingRestoreImporter = false
    @State private var showRestartAlert = false

    let showsCloseButton: Bool

    init(showsCloseButton: Bool = false) {
        self.showsCloseButton = showsCloseButton
    }

    private var isUSRegion: Bool {
        Locale.current.region?.identifier == "US"
    }

    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }()

    private var selectedPaneBinding: Binding<SettingsPane?> {
        Binding {
            selectedPane
        } set: { newPane in
            guard let newPane else {
                selectedPane = nil
                return
            }
            if let selectedPane, selectedPane != newPane {
                paneTransitionEdge = newPane.sortIndex > selectedPane.sortIndex ? .bottom : .top
            }
            selectedPane = newPane
        }
    }

    private var paneTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: paneTransitionEdge == .bottom ? 28 : -28)),
            removal: .opacity
        )
    }

    // Extracted from `body` so the type-checker isn't inferring the whole Form chain
    // (Pickers + onChange closures + four alerts) as one expression, which times out.
    @ViewBuilder
    private var preferencesSection: some View {
        Section {
            temperatureUnitPicker
            volumeUnitsPicker
            languagePicker
        }
    }

    private var temperatureUnitPicker: some View {
        Picker("Temperature Unit", selection: $selectedTemp) {
            Text("Fahrenheit").tag(Temperature.Measurement.fahrenheit)
            Text("Celsius").tag(Temperature.Measurement.celsius)
        }
        .accessibilityIdentifier("temperatureUnitPicker")
        .onChange(of: selectedTemp) { old, new in
            if old != new {
                Settings.shared.setPreferredTemp(measurement: new)
                do {
                    try Settings.shared.updateRecipeTemps(original: old, target: new)
                    store.refresh()
                } catch {
                    tempUpdateError = String(localized: "settings.error.convert_temperatures", defaultValue: "Could not convert recipe temperatures.")
                    selectedTemp = old
                }
            }
        }
    }

    private var volumeUnitsPicker: some View {
        Picker("Volume Units", selection: $selectedVolumeSystem) {
            Text("Metric").tag(VolumeSystem.metric)
            Text("Imperial").tag(VolumeSystem.imperial)
        }
        .accessibilityIdentifier("volumeUnitsPicker")
        .onChange(of: selectedVolumeSystem) { _, new in
            Settings.shared.setPreferredVolumeSystem(new)
        }
    }

    private var languagePicker: some View {
        Picker("Language", selection: $selectedLanguage) {
            Text("System Default").tag("")
            ForEach(AppLanguage.all) { lang in
                Text(lang.nativeName).tag(lang.code)
            }
        }
        .onChange(of: selectedLanguage) { _, new in
            Settings.shared.setPreferredLanguageCode(new.isEmpty ? nil : new)
            showRestartAlert = true
        }
    }

    private var tabletPreferencesContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                tabletPreferenceRow("Temperature Unit") {
                    temperatureUnitPicker
                        .labelsHidden()
                }
                Divider()
                tabletPreferenceRow("Volume Units") {
                    volumeUnitsPicker
                        .labelsHidden()
                }
                Divider()
                tabletPreferenceRow("Language") {
                    languagePicker
                        .labelsHidden()
                }
            }
            .padding(.horizontal, 20)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 32)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
    }

    private func tabletPreferenceRow<Control: View>(
        _ title: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 24) {
            Text(title)
                .foregroundStyle(.primary)
                .frame(width: 220, alignment: .leading)
            Spacer(minLength: 24)
            control()
                .pickerStyle(.menu)
                .frame(maxWidth: 280, alignment: .trailing)
        }
        .frame(minHeight: 54)
    }

    @ViewBuilder
    private func librarySection(showHeader: Bool = true) -> some View {
        Section {
            NavigationLink {
                RecentlyDeletedRecipesView()
                    .environment(store)
            } label: {
                HStack {
                    Text("Recently Deleted")
                    Spacer()
                    if !store.deletedRecipes.isEmpty {
                        Text("\(store.deletedRecipes.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityIdentifier("recentlyDeletedLink")
            Button {
                backupLibrary()
            } label: {
                Text("Back Up Recipe Library")
            }
            Button {
                showingRestoreImporter = true
            } label: {
                Text("Restore Recipe Library")
            }
        } header: {
            if showHeader {
                Text("Library")
            }
        } footer: {
            Text(String(localized: "settings.backup.footer", defaultValue: "Backups include every recipe. Restoring a backup replaces your current recipe library."))
        }

    }

    @ViewBuilder
    private func aboutSection(showHeader: Bool = true) -> some View {
        Section {
            Link("Source Code on GitHub",
                 destination: URL(string: "https://github.com/georgie-codes/Doughy")!)
                .accessibilityIdentifier("sourceCodeLink")
            if isUSRegion {
                Link(destination: URL(string: "https://www.feedingamerica.org/find-your-local-foodbank")!) {
                    VStack(alignment: .leading) {
                        Text("Donate to your local food bank.")
                        Text("Go to feedingamerica.org")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("foodBankLink")
            }
            Link("Send Feedback",
                 destination: URL(string: "mailto:doughyapp@icloud.com")!)
                .accessibilityIdentifier("sendFeedbackLink")
        }
        header: {
            if showHeader {
                Text("About")
            }
        }
        footer: {
            Text(appVersion)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var compactSettingsForm: some View {
        Form {
            preferencesSection

            Section {
                NavigationLink(String(localized: "conversions.title", defaultValue: "Ingredient Conversions")) {
                    IngredientConversionsView(showTitle: true)
                }
                .accessibilityIdentifier("ingredientConversionsLink")
            }
            librarySection()

            aboutSection()
        }
        .navigationTitle("Settings")
    }

    private var tabletSettings: some View {
        NavigationSplitView(columnVisibility: $settingsColumnVisibility) {
            List(selection: selectedPaneBinding) {
                Section {
                    ForEach(SettingsPane.allCases, id: \.self) { pane in
                        NavigationLink(value: pane) {
                            Label(pane.title, systemImage: pane.systemImage)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", systemImage: "xmark") {
                            dismiss()
                        }
                    }
                }
            }
        } detail: {
            NavigationStack {
                ZStack {
                    tabletDetail(for: selectedPane ?? .preferences)
                        .id(selectedPane ?? .preferences)
                        .transition(paneTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Clip only the sliding pane transition; the background sits outside the
                // clip so it can keep extending under the home indicator.
                .clipped()
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .scrollsUnderHomeIndicator()
                .animation(.easeInOut(duration: 0.2), value: selectedPane)
                .toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar(removing: .sidebarToggle)
            }
        }
        .onChange(of: settingsColumnVisibility) { _, visibility in
            guard visibility != .all else { return }
            settingsColumnVisibility = .all
        }
    }

    @ViewBuilder
    private func tabletDetail(for pane: SettingsPane) -> some View {
        switch pane {
        case .preferences:
            tabletPane(for: pane) {
                tabletPreferencesContent
            }
        case .conversions:
            tabletPane(for: pane) {
                IngredientConversionsView(showTitle: false)
            }
        case .library:
            tabletPane(for: pane) {
                Form {
                    librarySection(showHeader: false)
                }
            }
        case .about:
            tabletPane(for: pane) {
                Form {
                    aboutSection(showHeader: false)
                }
            }
        }
    }

    private func tabletPane<Content: View>(
        for pane: SettingsPane,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(pane.title)
                .font(.largeTitle.bold())
            .padding(.horizontal, 32)
            .padding(.top, 18)
            .padding(.bottom, 12)

            content()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                tabletSettings
            } else {
                compactSettingsForm
            }
        }
        .alert("Error", isPresented: Binding(
            get: { tempUpdateError != nil },
            set: { if !$0 { tempUpdateError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tempUpdateError ?? "")
        }
        .fileImporter(
            isPresented: $showingRestoreImporter,
            allowedContentTypes: [UTType(filenameExtension: RecipeLibraryBackupFile.fileExtension) ?? .json],
            allowsMultipleSelection: false
        ) { result in
            handleRestoreImport(result)
        }
        .alert("Restore Recipe Library?", isPresented: Binding(
            get: { pendingRestoreBackup != nil },
            set: { if !$0 { pendingRestoreBackup = nil } }
        )) {
            Button("Restore", role: .destructive) {
                restorePendingBackup()
            }
            Button("Cancel", role: .cancel) {
                pendingRestoreBackup = nil
            }
        } message: {
            let count = pendingRestoreBackup?.recipes.count ?? 0
            Text("This will replace your current recipe library with \(count) recipes from the backup.")
        }
        .alert("Backup and Restore", isPresented: Binding(
            get: { backupRestoreMessage != nil },
            set: { if !$0 { backupRestoreMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupRestoreMessage ?? "")
        }
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please close and reopen Doughy to apply the language change.")
        }
    }

    private func backupLibrary() {
        do {
            let url = try store.exportLibraryBackup(appearances: appearanceStore.allAppearances())
            presentShareSheet(url: url)
        } catch {
            backupRestoreMessage = "Could not prepare the backup file."
        }
    }

    private func handleRestoreImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else {
            backupRestoreMessage = "Could not open the selected backup."
            return
        }
        guard let backup = RecipeLibraryBackupFile.load(from: url) else {
            backupRestoreMessage = "This file is not a valid Doughy library backup."
            return
        }
        pendingRestoreBackup = backup
    }

    private func restorePendingBackup() {
        guard let backup = pendingRestoreBackup else { return }
        pendingRestoreBackup = nil
        do {
            try store.restoreLibraryBackup(backup)
            for (name, appearance) in backup.collections ?? [:] {
                appearanceStore.set(appearance, for: name)
            }
            Settings.shared.restore(backup.userState?.settings)
            IngredientDensityStore.shared.restore(backup.userState?.ingredientDensities)
            IngredientConversionStore.shared.restore(backup.userState?.ingredientConversions)
            backupRestoreMessage = "Recipe library restored."
        } catch {
            backupRestoreMessage = error.localizedDescription
        }
    }

    private func presentShareSheet(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = scene.keyWindow?.rootViewController else { return }
        var top = rootVC
        while let presented = top.presentedViewController { top = presented }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(activityVC, animated: true)
    }
}

private struct RecentlyDeletedRecipesView: View {
    @Environment(RecipeStore.self) private var store
    @State private var pendingPermanentDelete: DeletedRecipe?
    @State private var showingDeleteAllConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if store.deletedRecipes.isEmpty {
                ContentUnavailableView(
                    String(localized: "settings.recently_deleted.empty.title", defaultValue: "No Recently Deleted Recipes"),
                    systemImage: "trash",
                    description: Text(String(localized: "settings.recently_deleted.empty.description", defaultValue: "Deleted recipes will appear here for 30 days."))
                )
            } else {
                Section {
                    ForEach(store.deletedRecipes) { deletedRecipe in
                        deletedRecipeRow(deletedRecipe)
                            .swipeActions(edge: .leading) {
                                Button(String(localized: "settings.recently_deleted.restore", defaultValue: "Restore")) {
                                    restore(deletedRecipe)
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(String(localized: "settings.recently_deleted.delete_permanently", defaultValue: "Delete Permanently"), role: .destructive) {
                                    pendingPermanentDelete = deletedRecipe
                                }
                            }
                            .contextMenu {
                                Button {
                                    restore(deletedRecipe)
                                } label: {
                                    Label(String(localized: "settings.recently_deleted.restore", defaultValue: "Restore"), systemImage: "arrow.uturn.backward")
                                }
                                Button(role: .destructive) {
                                    pendingPermanentDelete = deletedRecipe
                                } label: {
                                    Label(String(localized: "settings.recently_deleted.delete_permanently", defaultValue: "Delete Permanently"), systemImage: "trash")
                                }
                            }
                    }
                } footer: {
                    Text(String(localized: "settings.recently_deleted.footer", defaultValue: "Recipes are permanently deleted after 30 days."))
                }
            }
        }
        .navigationTitle(String(localized: "settings.recently_deleted.nav_title", defaultValue: "Recently Deleted"))
        .toolbar {
            if !store.deletedRecipes.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.recently_deleted.delete_all", defaultValue: "Delete All"), role: .destructive) {
                        showingDeleteAllConfirmation = true
                    }
                }
            }
        }
        .onAppear {
            store.refresh()
        }
        .alert(
            String(localized: "settings.recently_deleted.delete_permanently_title", defaultValue: "Delete Permanently?"),
            isPresented: Binding(
                get: { pendingPermanentDelete != nil },
                set: { if !$0 { pendingPermanentDelete = nil } }
            )
        ) {
            Button(String(localized: "settings.recently_deleted.delete_permanently", defaultValue: "Delete Permanently"), role: .destructive) {
                if let pendingPermanentDelete {
                    store.permanentlyDelete(pendingPermanentDelete)
                }
                pendingPermanentDelete = nil
            }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {
                pendingPermanentDelete = nil
            }
        } message: {
            Text(String(localized: "settings.recently_deleted.delete_permanently_message", defaultValue: "This recipe will be deleted immediately. This can't be undone."))
        }
        .alert(
            String(localized: "settings.recently_deleted.delete_all_permanently_title", defaultValue: "Delete All Permanently?"),
            isPresented: $showingDeleteAllConfirmation
        ) {
            Button(String(localized: "settings.recently_deleted.delete_all", defaultValue: "Delete All"), role: .destructive) {
                store.permanentlyDeleteAllRecentlyDeleted()
            }
            Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.recently_deleted.delete_all_permanently_message", defaultValue: "All recently deleted recipes will be deleted immediately. This can't be undone."))
        }
        .alert("Could Not Restore Recipe", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func deletedRecipeRow(_ deletedRecipe: DeletedRecipe) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deletedRecipe.name)
                .font(.headline)
            Text(DefaultLocalization.collectionName(deletedRecipe.collection))
                .foregroundStyle(.secondary)
            Text(deletesInText(for: deletedRecipe))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func restore(_ deletedRecipe: DeletedRecipe) {
        do {
            try store.restoreDeletedRecipe(deletedRecipe)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletesInText(for deletedRecipe: DeletedRecipe) -> String {
        let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: deletedRecipe.deletedAt)
            ?? deletedRecipe.deletedAt
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        let displayedDays = max(days, 0)
        if displayedDays == 1 {
            return String(localized: "settings.recently_deleted.expires_in_one", defaultValue: "Deletes in 1 day")
        }
        return String(format: String(localized: "settings.recently_deleted.expires_in_other", defaultValue: "Deletes in %d days"), displayedDays)
    }
}
