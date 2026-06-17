//
//  RecipeListView.swift
//  Doughy

import SwiftUI

struct RecipeListView: View {
    @Environment(RecipeStore.self) private var store
    @State private var showingCreate = false
    @State private var editingRecipe: RecipeWrapper?
    @State private var copyingRecipe: RecipeWrapper?
    @State private var sharingRecipe: RecipeWrapper?
    @State private var pendingShareAuthor: String = ""
    @State private var deletionError: String?
    @State private var intentScanImage: UIImage? = nil
    @State private var openScanOptionsOnCreate = false
    @State private var path: [RecipeWrapper] = []
    @State private var collapsedCollections: Set<String> = {
        Set(UserDefaults.standard.array(forKey: "collapsedCollections") as? [String] ?? [])
    }()

    var body: some View {
        NavigationStack(path: $path) {
            mainContent
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
                        .accessibilityIdentifier("addRecipeButton")
                    }
                }
                .navigationDestination(for: RecipeWrapper.self) { wrapper in
                    CalculatorView(recipe: wrapper.recipe)
                }
        }
        .sheet(isPresented: $showingCreate, onDismiss: {
            store.refresh()
            intentScanImage = nil
            openScanOptionsOnCreate = false
        }) {
            CreateRecipeView(initialScanImage: intentScanImage,
                             openScanOptionsOnAppear: openScanOptionsOnCreate)
                .environment(store)
        }
        .sheet(item: $editingRecipe, onDismiss: { store.refresh() }) { wrapper in
            CreateRecipeView(editingRecipe: wrapper.recipe)
                .environment(store)
        }
        .sheet(item: $copyingRecipe, onDismiss: { store.refresh() }) { wrapper in
            CreateRecipeView(copyingRecipe: wrapper.recipe)
                .environment(store)
        }
        .sheet(item: $sharingRecipe, onDismiss: { pendingShareAuthor = "" }) { wrapper in
            RecipeShareView(recipe: wrapper.recipe, initialAuthorName: pendingShareAuthor)
        }
        .sheet(item: Binding(get: { store.pendingImport }, set: { store.pendingImport = $0 })) { payload in
            ImportRecipeView(payload: payload)
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
        .onAppear {
            openPendingScanShortcutIfNeeded()
        }
        .onChange(of: store.pendingIntentImage) { _, image in
            guard let image else { return }
            intentScanImage = image
            openScanOptionsOnCreate = false
            store.pendingIntentImage = nil
            showingCreate = true
        }
        .onChange(of: store.pendingScanShortcut) { _, pending in
            guard pending else { return }
            openPendingScanShortcutIfNeeded()
        }
        .onChange(of: store.pendingShareIntent) { (_: PendingShareRequest?, pending: PendingShareRequest?) in
            guard let pending else { return }
            store.pendingShareIntent = nil
            guard let col = store.collections.first(where: { $0.name == pending.collection }),
                  let recipe = col.recipes.first(where: { $0.name == pending.recipeName }) else { return }
            pendingShareAuthor = pending.recipientName ?? ""
            sharingRecipe = RecipeWrapper(recipe: recipe)
        }
        .onChange(of: store.pendingOpenIntent) { (_: PendingOpenRecipeRequest?, pending: PendingOpenRecipeRequest?) in
            guard let pending else { return }
            store.pendingOpenIntent = nil
            store.refresh()
            guard let col = store.collections.first(where: { $0.name == pending.collection }),
                  let recipe = col.recipes.first(where: { $0.name == pending.recipeName }) else { return }
            path = [RecipeWrapper(recipe: recipe)]
        }
    }

    private func openPendingScanShortcutIfNeeded() {
        guard store.pendingScanShortcut else { return }
        store.pendingScanShortcut = false
        intentScanImage = nil
        openScanOptionsOnCreate = true
        showingCreate = true
    }

    private var mainContent: some View {
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
    }

    private var recipeList: some View {
        List {
            ForEach(store.collections, id: \.name) { collection in
                let isCollapsed = collapsedCollections.contains(collection.name)
                Section {
                    if !isCollapsed {
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
                            .swipeActions(edge: .leading) {
                                Button("Share") {
                                    sharingRecipe = RecipeWrapper(recipe: recipe)
                                }
                                .tint(.green)
                            }
                            .contextMenu {
                                Button {
                                    sharingRecipe = RecipeWrapper(recipe: recipe)
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                Button {
                                    copyingRecipe = RecipeWrapper(recipe: recipe)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                Button {
                                    editingRecipe = RecipeWrapper(recipe: recipe)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    do {
                                        try store.delete(recipe: recipe)
                                    } catch {
                                        deletionError = "Could not delete \"\(recipe.name)\"."
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Button {
                        withAnimation {
                            if isCollapsed {
                                collapsedCollections.remove(collection.name)
                            } else {
                                collapsedCollections.insert(collection.name)
                            }
                            UserDefaults.standard.set(Array(collapsedCollections), forKey: "collapsedCollections")
                        }
                    } label: {
                        HStack {
                            Text(collection.name)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
