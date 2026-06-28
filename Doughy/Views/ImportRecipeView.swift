//
//  ImportRecipeView.swift
//  Doughy

import SwiftUI

struct ImportRecipeView: View {
    let payload: RecipeFilePayload
    @Environment(RecipeStore.self) private var store
    @Environment(CollectionAppearanceStore.self) private var appearanceStore
    @State private var collectionName: String
    @State private var errorMessage: String?

    /// The avatar the imported recipe's collection will end up with: the local appearance
    /// if the collection already has one, otherwise the imported appearance.
    private var previewAppearance: CollectionAppearance {
        let local = appearanceStore.appearance(for: collectionName.trimmingCharacters(in: .whitespaces))
        if !local.isEmpty { return local }
        return payload.collectionAppearance ?? .none
    }

    init(payload: RecipeFilePayload) {
        self.payload = payload
        _collectionName = State(initialValue: payload.recipe.collection)
    }

    private var collectionPickerOptions: [String] {
        store.collectionNames
    }

    var body: some View {
        NavigationStack {
            Form {
                if payload.author != nil || payload.note != nil {
                    Section {
                        if let author = payload.author {
                            HStack(spacing: 8) {
                                Image(systemName: "person.circle")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text("Shared by \(author)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let note = payload.note {
                            Text(note)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Recipe") {
                    LabeledContent("Name", value: payload.recipe.name)
                    LabeledContent("Default Weight") {
                        Text(WeightFormatter.shared.format(weight: payload.recipe.defaultWeight))
                    }
                    LabeledContent("Ingredients", value: "\(payload.recipe.ingredients.count)")
                    if let pref = payload.recipe.preferment {
                        LabeledContent("Preferment", value: pref.name)
                    }
                    if !payload.recipe.instructions.isEmpty {
                        LabeledContent("Steps", value: "\(payload.recipe.instructions.count)")
                    }
                }

                Section {
                    HStack(spacing: 10) {
                        CollectionAvatar(collection: collectionName,
                                         appearanceOverride: previewAppearance,
                                         size: 32)
                        TextField("Collection name", text: $collectionName)
                            .autocorrectionDisabled()
                    }
                    if !collectionPickerOptions.isEmpty {
                        Menu("Choose existing…") {
                            ForEach(collectionPickerOptions, id: \.self) { name in
                                Button(name) { collectionName = name }
                            }
                        }
                    }
                } header: {
                    Text("Save to Collection")
                } footer: {
                    Text("Enter a name or pick an existing collection.")
                }
            }
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { store.pendingImport = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add to Library") { importRecipe() }
                        .disabled(collectionName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityHint("Enter a collection name to enable")
                }
            }
            .alert("Import Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func importRecipe() {
        let collection = collectionName.trimmingCharacters(in: .whitespaces)
        let recipe = RecipeFile.toRecipe(payload.recipe, collection: collection)
        do {
            try store.save(recipe: recipe)
            // Seed the collection's appearance from the import only when it has none locally,
            // so importing never overwrites an existing collection's look.
            if appearanceStore.appearance(for: collection).isEmpty,
               let imported = payload.collectionAppearance, !imported.isEmpty {
                appearanceStore.set(imported, for: collection)
            }
            if let author = payload.author {
                try? store.addNote("Shared by \(author)", to: recipe)
            }
            if let note = payload.note {
                try? store.addNote("Share note: \(note)", to: recipe)
            }
            store.pendingImport = nil
        } catch {
            errorMessage = String(
                format: String(localized: "import.error.duplicate_recipe", defaultValue: "A recipe named \"%@\" already exists. Rename it before importing, or ask the sender to rename theirs."),
                recipe.name
            )
        }
    }
}
