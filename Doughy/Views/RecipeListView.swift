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
    @State private var initialWebsiteImportURL: URL? = nil
    @State private var openScanOptionsOnCreate = false
    @State private var path: [RecipeWrapper] = []
    @State private var collapsedCollections: Set<String> = {
        Set(UserDefaults.standard.array(forKey: "collapsedCollections") as? [String] ?? [])
    }()
    @State private var showingNewUserOnboarding = false
    @State private var showingWhatsNew = false

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
                        .accessibilityLabel("Settings")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingCreate = true } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityIdentifier("addRecipeButton")
                        .accessibilityLabel("Add recipe")
                    }
                }
                .navigationDestination(for: RecipeWrapper.self) { wrapper in
                    CalculatorView(recipe: wrapper.recipe)
                }
        }
        .sheet(isPresented: $showingCreate, onDismiss: {
            store.refresh()
            intentScanImage = nil
            initialWebsiteImportURL = nil
            openScanOptionsOnCreate = false
        }) {
            CreateRecipeView(initialScanImage: intentScanImage,
                             openScanOptionsOnAppear: openScanOptionsOnCreate,
                             initialWebsiteImportURL: initialWebsiteImportURL)
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
            checkOnboarding()
            openPendingWebsiteImportIfNeeded()
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
        .onChange(of: store.pendingWebsiteImport) { _, pending in
            guard pending != nil else { return }
            openPendingWebsiteImportIfNeeded()
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
        .fullScreenCover(isPresented: $showingNewUserOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showingWhatsNew) {
            WhatsNewView()
        }
    }

    private func checkOnboarding() {
        let args = ProcessInfo.processInfo.arguments
        guard !args.contains("-UITesting") else { return }

        if args.contains("-ForceNewUserOnboarding") {
            showingNewUserOnboarding = true
            return
        }
        if args.contains("-ForceWhatsNew") {
            showingWhatsNew = true
            return
        }

        guard let current = UIApplication.appVersion else { return }
        let seen = UserDefaults.standard.string(forKey: Settings.lastOnboardingVersionKey)

        defer { UserDefaults.standard.set(current, forKey: Settings.lastOnboardingVersionKey) }

        if seen == nil {
            if store.isNewInstall {
                showingNewUserOnboarding = true
            } else {
                showingWhatsNew = true
            }
        } else if seen != current {
            showingWhatsNew = true
        }
    }

    private func openPendingScanShortcutIfNeeded() {
        guard store.pendingScanShortcut else { return }
        store.pendingScanShortcut = false
        intentScanImage = nil
        initialWebsiteImportURL = nil
        openScanOptionsOnCreate = true
        showingCreate = true
    }

    private func openPendingWebsiteImportIfNeeded() {
        guard let pending = store.pendingWebsiteImport else { return }
        store.pendingWebsiteImport = nil
        intentScanImage = nil
        openScanOptionsOnCreate = false
        initialWebsiteImportURL = pending.url
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
                                        deletionError = String(
                                            format: String(localized: "recipe_list.delete_failed", defaultValue: "Could not delete \"%@\"."),
                                            recipe.name
                                        )
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
                                        deletionError = String(
                                            format: String(localized: "recipe_list.delete_failed", defaultValue: "Could not delete \"%@\"."),
                                            recipe.name
                                        )
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
                            Text(DefaultLocalization.collectionName(collection.name))
                            Spacer()
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(isCollapsed ? "Expand" : "Collapse")
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
