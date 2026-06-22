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

struct SettingsView: View {
    @Environment(RecipeStore.self) private var store
    @State private var selectedTemp: Temperature.Measurement = Settings.shared.preferredTemp()
    @State private var selectedVolumeSystem: VolumeSystem = Settings.shared.preferredVolumeSystem()
    @State private var selectedLanguage: String = Settings.shared.preferredLanguageCode() ?? ""
    @State private var tempUpdateError: String?
    @State private var backupRestoreMessage: String?
    @State private var pendingRestoreBackup: RecipeLibraryBackup?
    @State private var showingRestoreImporter = false
    @State private var showRestartAlert = false

    private var isUSRegion: Bool {
        Locale.current.region?.identifier == "US"
    }

    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }()

    // Extracted from `body` so the type-checker isn't inferring the whole Form chain
    // (Pickers + onChange closures + four alerts) as one expression, which times out.
    @ViewBuilder
    private var preferencesSection: some View {
        Section {
            Picker("Temperature Unit", selection: $selectedTemp) {
                Text("Fahrenheit").tag(Temperature.Measurement.fahrenheit)
                Text("Celsius").tag(Temperature.Measurement.celsius)
            }
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

            Picker("Volume Units", selection: $selectedVolumeSystem) {
                Text("Metric").tag(VolumeSystem.metric)
                Text("Imperial").tag(VolumeSystem.imperial)
            }
            .onChange(of: selectedVolumeSystem) { _, new in
                Settings.shared.setPreferredVolumeSystem(new)
            }

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
    }

    @ViewBuilder
    private var librarySection: some View {
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
                Label("Back Up Recipe Library", systemImage: "square.and.arrow.up")
            }
            Button {
                showingRestoreImporter = true
            } label: {
                Label("Restore Recipe Library", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Library")
        } footer: {
            Text("Backups include every recipe. Restoring a backup replaces your current recipe library.")
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            Link("Source Code on GitHub",
                 destination: URL(string: "https://github.com/georgie-codes/Doughy")!)
            if isUSRegion {
                Link(destination: URL(string: "https://www.feedingamerica.org/find-your-local-foodbank")!) {
                    VStack(alignment: .leading) {
                        Text("Donate to your local food bank.")
                        Text("Go to feedingamerica.org")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Link("Send Feedback",
                 destination: URL(string: "mailto:doughyapp@icloud.com")!)
        } header: {
            Text("About")
        } footer: {
            Text(appVersion)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    var body: some View {
        Form {
            preferencesSection

            Section {
                NavigationLink(String(localized: "conversions.title", defaultValue: "Ingredient Conversions")) {
                    IngredientConversionsView()
                }
                .accessibilityIdentifier("ingredientConversionsLink")
            }
            librarySection

            aboutSection
        }
        .navigationTitle("Settings")
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
            let url = try store.exportLibraryBackup()
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
                    "No Recently Deleted Recipes",
                    systemImage: "trash",
                    description: Text("Deleted recipes will appear here for 30 days.")
                )
            } else {
                Section {
                    ForEach(store.deletedRecipes) { deletedRecipe in
                        deletedRecipeRow(deletedRecipe)
                            .swipeActions(edge: .leading) {
                                Button("Restore") {
                                    restore(deletedRecipe)
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    pendingPermanentDelete = deletedRecipe
                                }
                            }
                            .contextMenu {
                                Button {
                                    restore(deletedRecipe)
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                Button(role: .destructive) {
                                    pendingPermanentDelete = deletedRecipe
                                } label: {
                                    Label("Delete Permanently", systemImage: "trash")
                                }
                            }
                    }
                } footer: {
                    Text("Recipes are permanently deleted after 30 days.")
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .toolbar {
            if !store.deletedRecipes.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete All", role: .destructive) {
                        showingDeleteAllConfirmation = true
                    }
                }
            }
        }
        .onAppear {
            store.refresh()
        }
        .alert(
            "Delete Permanently?",
            isPresented: Binding(
                get: { pendingPermanentDelete != nil },
                set: { if !$0 { pendingPermanentDelete = nil } }
            )
        ) {
            Button("Delete Permanently", role: .destructive) {
                if let pendingPermanentDelete {
                    store.permanentlyDelete(pendingPermanentDelete)
                }
                pendingPermanentDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingPermanentDelete = nil
            }
        } message: {
            Text("This recipe will be deleted immediately. This can't be undone.")
        }
        .alert(
            "Delete All Permanently?",
            isPresented: $showingDeleteAllConfirmation
        ) {
            Button("Delete All", role: .destructive) {
                store.permanentlyDeleteAllRecentlyDeleted()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All recently deleted recipes will be deleted immediately. This can't be undone.")
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
            Text(deletedRecipe.collection)
                .foregroundStyle(.secondary)
            Text("Deletes in \(daysRemainingText(for: deletedRecipe))")
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

    private func daysRemainingText(for deletedRecipe: DeletedRecipe) -> String {
        let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: deletedRecipe.deletedAt)
            ?? deletedRecipe.deletedAt
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        let displayedDays = max(days, 0)
        return displayedDays == 1 ? "1 day" : "\(displayedDays) days"
    }
}
