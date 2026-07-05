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
    @State var pendingTabletLibraryCollectionReveal: String?
    @State var tabletCollectionVisibleSections: [String: TabletCollectionVisibleSection] = [:]
    @State var appliedRecipeSearchText = ""
    @State var isRecipeSearchFocused = false

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
                .recipeListSearch(
                    appliedSearchText: $appliedRecipeSearchText
                )
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
            PaneDivider()
            // GeometryReader accepts whatever width is left over, so the session pane can
            // never force the HStack wider than the screen. Without it, opening the 320pt
            // library on narrower layouts (portrait, Stage Manager) makes the HStack
            // overflow and re-center, shoving the rail off the left edge.
            GeometryReader { proxy in
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
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresKeyboardSafeArea(isRecipeSearchFocused)
        }
        // Explicit: iPadOS 26 doesn't reliably auto-extend `.background(_:)` colors
        // into the safe areas, which left a hairline of window background on screen edges.
        .background { Color(.systemGroupedBackground).ignoresSafeArea() }
    }

    func checkOnboarding() {
        let args = ProcessInfo.processInfo.arguments

        // Checked before the general "-UITesting" bypass below so UI tests can opt into
        // exercising the onboarding/what's-new screens explicitly, while every other
        // -UITesting launch keeps skipping onboarding entirely (fresh in-memory store,
        // no unrelated fullScreenCover/sheet in the way of other UI tests).
        if args.contains("-ForceNewUserOnboarding") {
            showingNewUserOnboarding = true
            return
        }
        if args.contains("-ForceWhatsNew") {
            showingWhatsNew = true
            return
        }

        guard !args.contains("-UITesting") else { return }

        guard let current = UIApplication.appVersion else { return }
        // Hydrated from iCloud at Settings.shared init when local storage is missing (e.g.
        // after an uninstall/reinstall), so a returning user on the same iCloud account
        // isn't shown the full onboarding flow again.
        let seen = UserDefaults.standard.string(forKey: Settings.lastOnboardingVersionKey)

        defer { Settings.shared.setLastOnboardingVersion(current) }

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
            pendingTabletLibraryCollectionReveal = collectionName
        }
        withAnimation(.snappy) {
            showingTabletLibrary = true
        }
    }

    func handleTabletCollectionTap(_ collection: RecipeCollection) {
        if showingTabletLibrary {
            if activeTabletCollectionName != collection.name, let recipe = collection.recipes.first {
                select(recipe: recipe)
            }
            withAnimation(.snappy) {
                showingTabletLibrary = false
            }
        } else {
            showTabletLibrary(for: collection.name)
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
            } else if isFilteringRecipes && filteredRecipeSections.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No recipes match \"\(trimmedRecipeSearchText)\".")
                )
            } else {
                recipeList(filteredRecipeSections)
            }
        }
    }

    var trimmedRecipeSearchText: String {
        appliedRecipeSearchText
    }

    var isFilteringRecipes: Bool {
        !trimmedRecipeSearchText.isEmpty
    }

    var filteredRecipeSections: [RecipeListSection] {
        let searchText = trimmedRecipeSearchText
        return store.collections.compactMap { collection -> RecipeListSection? in
            let recipes: [any RecipeProtocol]
            if !searchText.isEmpty {
                recipes = collection.recipes.filter { recipe in
                    recipe.name.localizedCaseInsensitiveContains(searchText)
                }
            } else {
                recipes = collection.recipes
            }

            guard !recipes.isEmpty else { return nil }
            return RecipeListSection(collection: collection, recipes: recipes)
        }
    }

    func recipeList(_ sections: [RecipeListSection]) -> some View {
        List {
            ForEach(sections) { section in
                let collection = section.collection
                let isCollapsed = collapsedCollections.contains(collection.name)
                Section {
                    if !isCollapsed || isFilteringRecipes {
                        ForEach(section.recipes, id: \.name) { recipe in
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
                        .onMove { offsets, target in
                            store.moveRecipes(in: collection.name, fromOffsets: offsets, toOffset: target)
                        }
                        .moveDisabled(isFilteringRecipes)
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
            searchOverlayListSpacer
        }
    }

    var searchOverlayListSpacer: some View {
        Color.clear
            .frame(height: recipeSearchOverlayReservedHeight)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityHidden(true)
    }

    var recipeSearchOverlayReservedHeight: CGFloat {
        72
    }

    var tabletRailCollectionIconSize: CGFloat {
        54
    }

    var tabletRail: some View {
        VStack(spacing: 18) {
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
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(maxHeight: .infinity)
            } else {
                Spacer()
            }

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
        .paneBackground {
            Color.clear
                .railGlassSurface()
        }
    }

    func tabletCollectionButton(for collection: RecipeCollection) -> some View {
        let isActive = activeTabletCollectionName == collection.name
        let label = DefaultLocalization.collectionName(collection.name)

        return Button {
            handleTabletCollectionTap(collection)
        } label: {
            CollectionAvatar(collection: collection.name, size: tabletRailCollectionIconSize)
                .frame(width: tabletRailCollectionIconSize, height: tabletRailCollectionIconSize)
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
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                List {
                    if isFilteringRecipes && filteredRecipeSections.isEmpty {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("No recipes match \"\(trimmedRecipeSearchText)\".")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredRecipeSections) { section in
                            let collection = section.collection
                            Section {
                                ForEach(section.recipes, id: \.name) { recipe in
                                    let isSelected = isSelected(recipe)
                                    Button {
                                        select(recipe: recipe)
                                        withAnimation(.snappy) {
                                            showingTabletLibrary = false
                                        }
                                    } label: {
                                        tabletRecipeRow(recipe, isSelected: isSelected)
                                    }
                                    .background {
                                        GeometryReader { rowGeometry in
                                            Color.clear.preference(
                                                key: TabletCollectionVisibleSectionPreferenceKey.self,
                                                value: [
                                                    collection.name: .init(
                                                        header: nil,
                                                        rows: [
                                                            recipe.name: rowGeometry.frame(
                                                                in: .named(TabletRecipeListCoordinateSpace.name)
                                                            ),
                                                        ],
                                                        expectedRowCount: section.recipes.count
                                                    ),
                                                ]
                                            )
                                        }
                                    }
                                    .selectedRecipeListRow(isSelected)
                                    .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                                .onMove { offsets, target in
                                    store.moveRecipes(in: collection.name, fromOffsets: offsets, toOffset: target)
                                }
                                .moveDisabled(isFilteringRecipes)
                            } header: {
                                HStack(spacing: 8) {
                                    CollectionAvatar(collection: collection.name, size: 22)
                                    Text(DefaultLocalization.collectionName(collection.name))
                                }
                                .id(collection.name)
                                .background {
                                    GeometryReader { headerGeometry in
                                        Color.clear.preference(
                                            key: TabletCollectionVisibleSectionPreferenceKey.self,
                                            value: [
                                                collection.name: .init(
                                                    header: headerGeometry.frame(
                                                        in: .named(TabletRecipeListCoordinateSpace.name)
                                                    ),
                                                    rows: [:],
                                                    expectedRowCount: section.recipes.count
                                                ),
                                            ]
                                        )
                                    }
                                }
                            }
                        }
                    }
                    searchOverlayListSpacer
                }
                .listStyle(.sidebar)
                .contentMargins(.top, 10, for: .scrollContent)
                .scrollContentBackground(.hidden)
                .coordinateSpace(name: TabletRecipeListCoordinateSpace.name)
                .paneBackground {
                    Color.clear
                        .tabletSidebarGlassSurface()
                }
                .statusBarCover(height: geometry.safeAreaInsets.top)
                .onPreferenceChange(TabletCollectionVisibleSectionPreferenceKey.self) { sections in
                    tabletCollectionVisibleSections = sections
                    revealPendingTabletLibraryCollectionIfNeeded(
                        using: proxy,
                        in: geometry,
                        visibleSections: sections
                    )
                }
            }
        }
        .tabletRecipeListSearch(
            appliedSearchText: $appliedRecipeSearchText,
            isSearchFocused: $isRecipeSearchFocused
        )
    }

    func isSelected(_ recipe: any RecipeProtocol) -> Bool {
        selectedRecipe?.recipe.name == recipe.name &&
        selectedRecipe?.recipe.collection == recipe.collection
    }

    func revealPendingTabletLibraryCollectionIfNeeded(
        using proxy: ScrollViewProxy,
        in geometry: GeometryProxy,
        visibleSections: [String: TabletCollectionVisibleSection]
    ) {
        guard let collectionName = pendingTabletLibraryCollectionReveal else { return }
        guard !isTabletCollectionFullyVisible(collectionName, in: geometry, visibleSections: visibleSections) else {
            pendingTabletLibraryCollectionReveal = nil
            return
        }

        pendingTabletLibraryCollectionReveal = nil
        withAnimation(.snappy) {
            proxy.scrollTo(collectionName, anchor: UnitPoint(x: 0.5, y: 0.12))
        }
    }

    func isTabletCollectionFullyVisible(
        _ collectionName: String,
        in geometry: GeometryProxy,
        visibleSections: [String: TabletCollectionVisibleSection]
    ) -> Bool {
        guard let section = visibleSections[collectionName],
              section.isComplete,
              let frame = section.frame else { return false }
        let topVisibleY = geometry.safeAreaInsets.top
        let bottomVisibleY = geometry.size.height - recipeSearchOverlayReservedHeight
        return frame.minY >= topVisibleY - 0.5 && frame.maxY <= bottomVisibleY + 0.5
    }

    func tabletRecipeRow(_ recipe: any RecipeProtocol, isSelected: Bool) -> some View {
        HStack {
            Text(recipe.name)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
            Spacer()
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

    func recipeListSearch(appliedSearchText: Binding<String>) -> some View {
        modifier(RecipeListSearchModifier(
            appliedSearchText: appliedSearchText,
            isSearchFocused: .constant(false)
        ))
    }

    func tabletRecipeListSearch(
        appliedSearchText: Binding<String>,
        isSearchFocused: Binding<Bool>
    ) -> some View {
        modifier(RecipeListSearchModifier(
            appliedSearchText: appliedSearchText,
            isSearchFocused: isSearchFocused
        ))
    }

    @ViewBuilder
    func ignoresKeyboardSafeArea(_ isIgnored: Bool) -> some View {
        if isIgnored {
            ignoresSafeArea(.keyboard, edges: .bottom)
        } else {
            self
        }
    }

    func statusBarCover(height: CGFloat) -> some View {
        overlay(alignment: .top) {
            Color(.systemGroupedBackground)
                .frame(height: height)
                .ignoresSafeArea(.container, edges: .top)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    func selectedRecipeListRow(_ isSelected: Bool) -> some View {
        if isSelected {
            listRowBackground(Color.accentColor)
        } else {
            self
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

struct RecipeListSection: Identifiable {
    let collection: RecipeCollection
    let recipes: [any RecipeProtocol]

    var id: String { collection.name }
}

private enum TabletRecipeListCoordinateSpace {
    static let name = "tabletRecipeList"
}

struct TabletCollectionVisibleSection: Equatable {
    var header: CGRect?
    var rows: [String: CGRect]
    var expectedRowCount: Int

    var isComplete: Bool {
        header != nil && rows.count == expectedRowCount
    }

    var frame: CGRect? {
        ([header].compactMap(\.self) + rows.values).reduce(nil) { result, frame in
            result?.union(frame) ?? frame
        }
    }

    func merged(with section: TabletCollectionVisibleSection) -> TabletCollectionVisibleSection {
        var mergedRows = rows
        mergedRows.merge(section.rows, uniquingKeysWith: { _, new in new })
        return TabletCollectionVisibleSection(
            header: section.header ?? header,
            rows: mergedRows,
            expectedRowCount: max(expectedRowCount, section.expectedRowCount)
        )
    }
}

struct TabletCollectionVisibleSectionPreferenceKey: PreferenceKey {
    static var defaultValue: [String: TabletCollectionVisibleSection] = [:]

    static func reduce(
        value: inout [String: TabletCollectionVisibleSection],
        nextValue: () -> [String: TabletCollectionVisibleSection]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { current, new in
            current.merged(with: new)
        })
    }
}

private struct RecipeListSearchModifier: ViewModifier {
    @Binding var appliedSearchText: String
    @Binding var isSearchFocused: Bool
    @FocusState private var searchFieldFocused: Bool
    @State private var searchText = ""

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                bottomSearchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
            .task(id: searchText) {
                await applySearchTextAfterTypingPause(searchText)
            }
            .onChange(of: searchFieldFocused) { _, isFocused in
                isSearchFocused = isFocused
            }
            .onDisappear {
                isSearchFocused = false
            }
    }

    private var bottomSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Search recipes", text: $searchText)
                .focused($searchFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("recipeSearchField")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background {
            Color.clear.liquidGlassSurface(
                in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                tint: Color(.systemBackground).opacity(0.18),
                interactive: true
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 8)
    }

    @MainActor
    private func applySearchTextAfterTypingPause(_ rawSearchText: String) async {
        let trimmedSearchText = rawSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearchText.isEmpty {
            appliedSearchText = ""
            return
        }

        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        appliedSearchText = trimmedSearchText
    }
}
