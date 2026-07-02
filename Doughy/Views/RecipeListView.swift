//
//  RecipeListView.swift
//  Doughy

import SwiftUI

struct RecipeListView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(RecipeStore.self) var store
    @Environment(CollectionAppearanceStore.self) var appearanceStore
    @State var showingCreate = false
    @State var editingRecipe: RecipeWrapper?
    @State var copyingRecipe: RecipeWrapper?
    @State var sharingRecipe: RecipeWrapper?
    @State var historyRecipe: RecipeWrapper?
    @State var showingSettings = false
    @State var pendingShareAuthor: String = ""
    @State var deletionError: String?
    @State var intentScanImage: UIImage? = nil
    @State var initialWebsiteImportURL: URL? = nil
    @State var createDefaultCollectionName: String?
    @State var openScanOptionsOnCreate = false
    @State var path: [RecipeWrapper] = []
    @State var collapsedCollections: Set<String> = {
        Set(UserDefaults.standard.array(forKey: "collapsedCollections") as? [String] ?? [])
    }()
    @State var showingNewUserOnboarding = false
    @State var showingWhatsNew = false
    @State var selectedRecipe: RecipeWrapper?
    @State var showingTabletLibrary = false
    @State var tabletLibraryScrollRequest: TabletLibraryScrollRequest?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                tabletContent
            } else {
                phoneContent
            }
        }
        .fullScreenCover(isPresented: $showingCreate, onDismiss: {
            store.refresh()
            intentScanImage = nil
            initialWebsiteImportURL = nil
            createDefaultCollectionName = nil
            openScanOptionsOnCreate = false
        }) {
            CreateRecipeView(initialScanImage: intentScanImage,
                             openScanOptionsOnAppear: openScanOptionsOnCreate,
                             initialWebsiteImportURL: initialWebsiteImportURL,
                             defaultCollectionName: createDefaultCollectionName,
                             onSave: openSavedRecipe)
                .environment(store)
                .environment(appearanceStore)
        }
        .fullScreenCover(item: $editingRecipe, onDismiss: { store.refresh() }) { wrapper in
            CreateRecipeView(editingRecipe: wrapper.recipe, onSave: openSavedRecipe)
                .environment(store)
                .environment(appearanceStore)
        }
        .fullScreenCover(item: $copyingRecipe, onDismiss: { store.refresh() }) { wrapper in
            CreateRecipeView(copyingRecipe: wrapper.recipe, onSave: openSavedRecipe)
                .environment(store)
                .environment(appearanceStore)
        }
        .sheet(item: $sharingRecipe, onDismiss: { pendingShareAuthor = "" }) { wrapper in
            RecipeShareView(recipe: wrapper.recipe, initialAuthorName: pendingShareAuthor)
                .environment(appearanceStore)
        }
        .sheet(item: $historyRecipe, onDismiss: { store.refresh() }) { wrapper in
            NavigationStack {
                RecipeHistoryView(recipe: wrapper.recipe)
            }
            .environment(store)
        }
        .sheet(isPresented: Binding(
            get: { showingSettings && horizontalSizeClass != .regular },
            set: { if !$0 { showingSettings = false } }
        )) {
            NavigationStack {
                SettingsView(showsCloseButton: true)
            }
            .environment(store)
            .environment(appearanceStore)
        }
        .fullScreenCover(isPresented: Binding(
            get: { showingSettings && horizontalSizeClass == .regular },
            set: { if !$0 { showingSettings = false } }
        )) {
            SettingsView(showsCloseButton: true)
                .environment(store)
                .environment(appearanceStore)
        }
        .sheet(item: Binding(get: { store.pendingImport }, set: { store.pendingImport = $0 })) { payload in
            ImportRecipeView(payload: payload)
                .environment(store)
                .environment(appearanceStore)
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
            restoreTabletSelectionIfNeeded()
        }
        .onChange(of: store.collections.map(\.name)) { _, names in
            restoreTabletSelectionIfNeeded()
            appearanceStore.cleanupOrphans(validNames: Set(names))
        }
        .onChange(of: store.pendingIntentImage) { _, image in
            guard let image else { return }
            intentScanImage = image
            openScanOptionsOnCreate = false
            store.pendingIntentImage = nil
            createDefaultCollectionName = defaultCollectionForCreateSheet()
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
            openRecipe(named: pending.recipeName, collection: pending.collection)
        }
        .fullScreenCover(isPresented: $showingNewUserOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showingWhatsNew) {
            WhatsNewView()
        }
    }

    var phoneContent: some View {
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
                        Button { presentCreateRecipe() } label: {
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
    }

    var tabletContent: some View {
        HStack(spacing: 0) {
            tabletRail
                .zIndex(1)
            if showingTabletLibrary {
                tabletRecipeList
                    .frame(width: 320)
                    .transition(.move(edge: .leading))
                    .zIndex(0)
            }
            Divider()
            Group {
                if let wrapper = selectedRecipe ?? firstRecipeWrapper {
                    TabletBakeSessionView(
                        recipe: wrapper.recipe,
                        onEdit: { editingRecipe = wrapper },
                        onCopy: { copyingRecipe = wrapper },
                        onShare: { sharingRecipe = wrapper },
                        onHistory: { historyRecipe = wrapper }
                    )
                        .id(wrapper.id)
                } else {
                    ContentUnavailableView(
                        "No Recipes",
                        systemImage: "fork.knife",
                        description: Text("Tap + to create your first recipe.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    func checkOnboarding() {
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

    func openPendingScanShortcutIfNeeded() {
        guard store.pendingScanShortcut else { return }
        store.pendingScanShortcut = false
        intentScanImage = nil
        initialWebsiteImportURL = nil
        openScanOptionsOnCreate = true
        createDefaultCollectionName = defaultCollectionForCreateSheet()
        showingCreate = true
    }

    func openPendingWebsiteImportIfNeeded() {
        guard let pending = store.pendingWebsiteImport else { return }
        store.pendingWebsiteImport = nil
        intentScanImage = nil
        openScanOptionsOnCreate = false
        initialWebsiteImportURL = pending.url
        createDefaultCollectionName = defaultCollectionForCreateSheet()
        showingCreate = true
    }

    func restoreTabletSelectionIfNeeded() {
        guard horizontalSizeClass == .regular, selectedRecipe == nil else { return }
        if let saved = savedLastActiveRecipe() {
            selectedRecipe = RecipeWrapper(recipe: saved)
        } else {
            selectedRecipe = firstRecipeWrapper
        }
    }

    func select(recipe: any RecipeProtocol) {
        selectedRecipe = RecipeWrapper(recipe: recipe)
        saveLastActive(recipe: recipe)
    }

    func openSavedRecipe(_ recipe: any RecipeProtocol) {
        openRecipe(named: recipe.name, collection: recipe.collection)
    }

    func openRecipe(named name: String, collection: String) {
        store.refresh()
        guard let recipe = store.collections
            .first(where: { $0.name == collection })?
            .recipes.first(where: { $0.name == name }) else { return }
        let wrapper = RecipeWrapper(recipe: recipe)
        selectedRecipe = wrapper
        saveLastActive(recipe: recipe)
        if horizontalSizeClass == .regular {
            withAnimation(.snappy) {
                showingTabletLibrary = false
            }
        } else {
            path = [wrapper]
        }
    }

    var firstRecipeWrapper: RecipeWrapper? {
        store.collections.first?.recipes.first.map { RecipeWrapper(recipe: $0) }
    }

    func savedLastActiveRecipe() -> (any RecipeProtocol)? {
        guard let collection = UserDefaults.standard.string(forKey: TabletBakeSessionKeys.lastCollection),
              let name = UserDefaults.standard.string(forKey: TabletBakeSessionKeys.lastRecipe) else { return nil }
        return store.collections
            .first { $0.name == collection }?
            .recipes.first { $0.name == name }
    }

    func saveLastActive(recipe: any RecipeProtocol) {
        UserDefaults.standard.set(recipe.collection, forKey: TabletBakeSessionKeys.lastCollection)
        UserDefaults.standard.set(recipe.name, forKey: TabletBakeSessionKeys.lastRecipe)
    }

    var activeTabletCollectionName: String? {
        (selectedRecipe ?? firstRecipeWrapper)?.recipe.collection
    }

    func defaultCollectionForCreateSheet() -> String? {
        if horizontalSizeClass == .regular {
            return activeTabletCollectionName ?? store.defaultCollectionForNewRecipe
        }
        return store.defaultCollectionForNewRecipe
    }

    func presentCreateRecipe() {
        intentScanImage = nil
        initialWebsiteImportURL = nil
        openScanOptionsOnCreate = false
        createDefaultCollectionName = defaultCollectionForCreateSheet()
        showingCreate = true
    }

    func showTabletLibrary(for collectionName: String? = nil) {
        if let collectionName {
            tabletLibraryScrollRequest = TabletLibraryScrollRequest(collectionName: collectionName)
        }
        withAnimation(.snappy) {
            showingTabletLibrary = true
        }
    }

    var mainContent: some View {
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

    var recipeList: some View {
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
                        HStack(spacing: 8) {
                            CollectionAvatar(collection: collection.name, size: 22)
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

    var tabletRail: some View {
        VStack(spacing: 18) {
            Button {
                withAnimation(.snappy) {
                    showingTabletLibrary.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.bordered)
            .tabletIconButtonChrome()
            .accessibilityLabel("Recipe library")

            Button {
                presentCreateRecipe()
            } label: {
                Image(systemName: "plus")
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.bordered)
            .tabletIconButtonChrome()
            .accessibilityIdentifier("addRecipeButton")
            .accessibilityLabel("Add recipe")

            if !store.collections.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(store.collections, id: \.name) { collection in
                            tabletCollectionButton(for: collection)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: .infinity)
            } else {
                Spacer()
            }

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.bordered)
            .tabletIconButtonChrome()
            .accessibilityLabel("Settings")
        }
        .padding(.vertical, 18)
        .frame(width: 78)
        .railGlassSurface()
    }

    func tabletCollectionButton(for collection: RecipeCollection) -> some View {
        let isActive = activeTabletCollectionName == collection.name
        let label = DefaultLocalization.collectionName(collection.name)

        return Button {
            showTabletLibrary(for: collection.name)
        } label: {
            ZStack {
                Color.clear
                    .tabletCircularGlassSurface()
                CollectionAvatar(collection: collection.name, size: 42)
            }
            .frame(width: 54, height: 54)
            .overlay {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .opacity(isActive ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint("Show \(label) recipes")
    }

    var tabletRecipeList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(store.collections, id: \.name) { collection in
                    Section {
                        ForEach(collection.recipes, id: \.name) { recipe in
                            Button {
                                select(recipe: recipe)
                                withAnimation(.snappy) {
                                    showingTabletLibrary = false
                                }
                            } label: {
                                HStack {
                                    Text(recipe.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedRecipe?.recipe.name == recipe.name,
                                       selectedRecipe?.recipe.collection == recipe.collection {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
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
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            CollectionAvatar(collection: collection.name, size: 22)
                            Text(DefaultLocalization.collectionName(collection.name))
                        }
                        .id(collection.name)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background {
                Color.clear
                    .tabletSidebarGlassSurface()
            }
            .onAppear {
                guard let request = tabletLibraryScrollRequest else { return }
                proxy.scrollTo(request.collectionName, anchor: .top)
            }
            .onChange(of: tabletLibraryScrollRequest) { _, request in
                guard let request else { return }
                withAnimation(.snappy) {
                    proxy.scrollTo(request.collectionName, anchor: .top)
                }
            }
        }
    }
}

extension View {
    /// The vertical navigation rail surface. Uses iOS 26 Liquid Glass when available so the
    /// recipe list refracts through the rail as it slides underneath, falling back to the
    /// `.bar` material on iOS 18–25.
    @ViewBuilder
    func railGlassSurface() -> some View {
        self.liquidGlassSurface(
            in: Rectangle(),
            tint: Color(.systemBackground).opacity(0.24)
        )
    }

    @ViewBuilder
    func tabletIconButtonChrome() -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            self.buttonBorderShape(.circle)
        }
    }

    @ViewBuilder
    func tabletProminentIconButtonChrome() -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
        } else {
            self.buttonBorderShape(.circle)
        }
    }

    @ViewBuilder
    func tabletProminentButtonChrome() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self
        }
    }

    @ViewBuilder
    func tabletCircularGlassSurface() -> some View {
        self.liquidGlassSurface(
            in: Circle(),
            tint: Color(.systemBackground).opacity(0.18),
            interactive: true
        )
    }

    @ViewBuilder
    func tabletSidebarGlassSurface() -> some View {
        self.liquidGlassSurface(
            in: Rectangle(),
            tint: Color(.systemBackground).opacity(0.18)
        )
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
