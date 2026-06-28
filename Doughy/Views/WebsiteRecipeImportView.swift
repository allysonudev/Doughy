//
//  WebsiteRecipeImportView.swift
//  Doughy
//

import SwiftUI

struct WebsiteRecipeImportView: View {
    let initialURL: URL?
    let onCancel: () -> Void
    let onImport: (WebsiteRecipeDraft) -> Void

    @State private var urlText: String
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var didStartInitialImport = false

    init(initialURL: URL? = nil,
         onCancel: @escaping () -> Void,
         onImport: @escaping (WebsiteRecipeDraft) -> Void) {
        self.initialURL = initialURL
        self.onCancel = onCancel
        self.onImport = onImport
        _urlText = State(initialValue: initialURL?.absoluteString ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/recipe", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .accessibilityIdentifier("websiteRecipeURLField")

                    if isImporting {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(String(localized: "website_import.progress", defaultValue: "Importing recipe…"))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(String(localized: "website_import.section.url", defaultValue: "Recipe Link"))
                } footer: {
                    Text(String(localized: "website_import.footer", defaultValue: "Doughy imports recipe data from sites that publish structured recipe details."))
                }
            }
            .navigationTitle(String(localized: "website_import.title", defaultValue: "Import from Link"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "website_import.action.import", defaultValue: "Import")) {
                        Task { await importRecipe() }
                    }
                    .disabled(importButtonDisabled)
                    .accessibilityIdentifier("websiteRecipeImportButton")
                }
            }
            .alert(String(localized: "website_import.error.title", defaultValue: "Import Failed"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                guard initialURL != nil, !didStartInitialImport else { return }
                didStartInitialImport = true
                await importRecipe()
            }
        }
    }

    private var importButtonDisabled: Bool {
        isImporting || RecipeWebsiteImporter.normalizedURL(from: urlText) == nil
    }

    @MainActor
    private func importRecipe() async {
        guard let url = RecipeWebsiteImporter.normalizedURL(from: urlText) else {
            errorMessage = WebsiteRecipeImportError.invalidURL.localizedDescription
            return
        }

        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            let draft = try await RecipeWebsiteImporter.shared.importRecipe(from: url)
            onImport(draft)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
