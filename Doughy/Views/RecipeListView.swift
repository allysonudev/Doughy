//
//  RecipeListView.swift
//  Doughy

import SwiftUI

struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var showingCreate = false
    @State private var editingRecipe: RecipeWrapper?
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            Group {
                if store.collections.isEmpty {
                    ContentUnavailableView(
                        "No Recipes",
                        systemImage: "fork.knife",
                        description: Text("Tap + to create your first recipe.")
                    )
                } else {
                    recipeList
                }
            }
            .navigationTitle("Doughy")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: RecipeWrapper.self) { wrapper in
                CalculatorView(recipe: wrapper.recipe)
            }
            .sheet(isPresented: $showingCreate, onDismiss: { store.refresh() }) {
                CreateRecipeView()
                    .environment(store)
            }
            .sheet(item: $editingRecipe, onDismiss: { store.refresh() }) { wrapper in
                CreateRecipeView(editingRecipe: wrapper.recipe)
                    .environment(store)
            }
            .alert("Error", isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionError ?? "")
            }
        }
    }

    private var recipeList: some View {
        List {
            ForEach(store.collections, id: \.name) { collection in
                Section(collection.name) {
                    ForEach(collection.recipes, id: \.name) { recipe in
                        NavigationLink(value: RecipeWrapper(recipe: recipe)) {
                            Text(recipe.name)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                do {
                                    try store.delete(recipe: recipe)
                                } catch {
                                    deletionError = "Could not delete \"\(recipe.name)\"."
                                }
                            }
                            Button("Edit") {
                                editingRecipe = RecipeWrapper(recipe: recipe)
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
    }
}

// Wraps any RecipeProtocol so it can be used with NavigationLink(value:) and sheet(item:).
struct RecipeWrapper: Identifiable, Hashable {
    let id: ObjectIdentifier
    let recipe: any RecipeProtocol

    init(recipe: any RecipeProtocol) {
        self.recipe = recipe
        self.id = ObjectIdentifier(recipe as AnyObject)
    }

    static func == (lhs: RecipeWrapper, rhs: RecipeWrapper) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
