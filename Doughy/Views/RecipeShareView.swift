//
//  RecipeShareView.swift
//  Doughy

import SwiftUI
import UIKit

struct RecipeShareView: View {
    let recipe: any RecipeProtocol
    @Environment(\.dismiss) private var dismiss
    @State private var authorName: String
    @State private var shareNote: String = ""
    @State private var errorMessage: String?

    init(recipe: any RecipeProtocol, initialAuthorName: String = "") {
        self.recipe = recipe
        self._authorName = State(initialValue: initialAuthorName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name (optional)", text: $authorName)
                        .autocorrectionDisabled()
                } header: {
                    Text("From")
                } footer: {
                    Text("The recipient will see this when they open the shared recipe. Doughy does not know or store anything about you.")
                }

                Section {
                    TextField(String(localized: "share.note.placeholder", defaultValue: "Add a note (optional)"), text: $shareNote, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text(String(localized: "share.note.header", defaultValue: "Note"))
                } footer: {
                    Text(String(localized: "share.note.footer", defaultValue: "A personal note the recipient can read from the recipe."))
                }

                Section("Recipe") {
                    LabeledContent("Name", value: recipe.name)
                    LabeledContent("Collection", value: DefaultLocalization.collectionName(recipe.collection))
                    LabeledContent("Ingredients", value: "\(recipe.ingredients.count)")
                    if let pr = recipe as? PrefermentRecipe {
                        LabeledContent("Preferment", value: pr.preferment.name)
                    }
                    if !recipe.instructions.isEmpty {
                        LabeledContent("Steps", value: "\(recipe.instructions.count)")
                    }
                }
            }
            .navigationTitle("Share Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Share") { share() }
                }
            }
            .alert("Export Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func share() {
        let trimmed = authorName.trimmingCharacters(in: .whitespaces)
        let trimmedNote = shareNote.trimmingCharacters(in: .whitespaces)
        let payload = RecipeFile.payload(
            from: recipe,
            author: trimmed.isEmpty ? nil : trimmed,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        guard let url = try? RecipeFile.write(payload) else {
            errorMessage = String(localized: "share.error.prepare_file", defaultValue: "Could not prepare the recipe file.")
            return
        }
        // Present UIActivityViewController on top of this sheet — no dismiss first.
        // completionWithItemsHandler dismisses RecipeShareView after a successful share.
        presentShareSheet(url: url)
    }

    private func presentShareSheet(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = scene.keyWindow?.rootViewController else { return }
        var top = rootVC
        while let presented = top.presentedViewController { top = presented }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            if completed { dismiss() }
        }
        // iPad needs a source rect for the popover anchor.
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(activityVC, animated: true)
    }
}
