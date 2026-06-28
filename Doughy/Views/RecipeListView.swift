//
//  RecipeListView.swift
//  Doughy

import SwiftUI

struct RecipeListView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(RecipeStore.self) private var store
    @Environment(CollectionAppearanceStore.self) private var appearanceStore
    @State private var showingCreate = false
    @State private var editingRecipe: RecipeWrapper?
    @State private var copyingRecipe: RecipeWrapper?
    @State private var sharingRecipe: RecipeWrapper?
    @State private var historyRecipe: RecipeWrapper?
    @State private var showingSettings = false
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
    @State private var selectedRecipe: RecipeWrapper?
    @State private var showingTabletLibrary = false
    @State private var tabletLibraryScrollRequest: TabletLibraryScrollRequest?

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
            openScanOptionsOnCreate = false
        }) {
            CreateRecipeView(initialScanImage: intentScanImage,
                             openScanOptionsOnAppear: openScanOptionsOnCreate,
                             initialWebsiteImportURL: initialWebsiteImportURL)
                .environment(store)
                .environment(appearanceStore)
        }
        .fullScreenCover(item: $editingRecipe, onDismiss: { store.refresh() }) { wrapper in
            CreateRecipeView(editingRecipe: wrapper.recipe)
                .environment(store)
                .environment(appearanceStore)
        }
        .fullScreenCover(item: $copyingRecipe, onDismiss: { store.refresh() }) { wrapper in
            CreateRecipeView(copyingRecipe: wrapper.recipe)
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
            select(recipe: recipe)
            if horizontalSizeClass != .regular {
                path = [RecipeWrapper(recipe: recipe)]
            }
        }
        .fullScreenCover(isPresented: $showingNewUserOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showingWhatsNew) {
            WhatsNewView()
        }
    }

    private var phoneContent: some View {
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
    }

    private var tabletContent: some View {
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

    private func restoreTabletSelectionIfNeeded() {
        guard horizontalSizeClass == .regular, selectedRecipe == nil else { return }
        if let saved = savedLastActiveRecipe() {
            selectedRecipe = RecipeWrapper(recipe: saved)
        } else {
            selectedRecipe = firstRecipeWrapper
        }
    }

    private func select(recipe: any RecipeProtocol) {
        selectedRecipe = RecipeWrapper(recipe: recipe)
        saveLastActive(recipe: recipe)
    }

    private var firstRecipeWrapper: RecipeWrapper? {
        store.collections.first?.recipes.first.map { RecipeWrapper(recipe: $0) }
    }

    private func savedLastActiveRecipe() -> (any RecipeProtocol)? {
        guard let collection = UserDefaults.standard.string(forKey: TabletBakeSessionKeys.lastCollection),
              let name = UserDefaults.standard.string(forKey: TabletBakeSessionKeys.lastRecipe) else { return nil }
        return store.collections
            .first { $0.name == collection }?
            .recipes.first { $0.name == name }
    }

    private func saveLastActive(recipe: any RecipeProtocol) {
        UserDefaults.standard.set(recipe.collection, forKey: TabletBakeSessionKeys.lastCollection)
        UserDefaults.standard.set(recipe.name, forKey: TabletBakeSessionKeys.lastRecipe)
    }

    private var activeTabletCollectionName: String? {
        (selectedRecipe ?? firstRecipeWrapper)?.recipe.collection
    }

    private func showTabletLibrary(for collectionName: String? = nil) {
        if let collectionName {
            tabletLibraryScrollRequest = TabletLibraryScrollRequest(collectionName: collectionName)
        }
        withAnimation(.snappy) {
            showingTabletLibrary = true
        }
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

    private var tabletRail: some View {
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
                showingCreate = true
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

    private func tabletCollectionButton(for collection: RecipeCollection) -> some View {
        let isActive = activeTabletCollectionName == collection.name
        let label = DefaultLocalization.collectionName(collection.name)

        return Button {
            showTabletLibrary(for: collection.name)
        } label: {
            CollectionAvatar(collection: collection.name, size: 46)
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

    private var tabletRecipeList: some View {
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

private extension View {
    /// The vertical navigation rail surface. Uses iOS 26 Liquid Glass when available so the
    /// recipe list refracts through the rail as it slides underneath, falling back to the
    /// `.bar` material on iOS 18–25.
    @ViewBuilder
    func railGlassSurface() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect)
        } else {
            self.background(.bar)
        }
    }

    func tabletIconButtonChrome() -> some View {
        self.buttonBorderShape(.circle)
    }
}

private struct TabletLibraryScrollRequest: Equatable {
    let collectionName: String
    private let id = UUID()
}

private struct TabletRepeatButton: View {
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    @State private var repeatTask: Task<Void, Never>?

    var body: some View {
        styledButton
            .onLongPressGesture(minimumDuration: 0.35, maximumDistance: 44) {
            } onPressingChanged: { isPressing in
                if isPressing {
                    startRepeating()
                } else {
                    stopRepeating()
                }
            }
            .onDisappear {
                stopRepeating()
            }
    }

    @ViewBuilder
    private var styledButton: some View {
        if isProminent {
            button
                .buttonStyle(.borderedProminent)
        } else {
            button
                .buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 44, height: 44)
        }
        .tabletIconButtonChrome()
    }

    private func startRepeating() {
        guard repeatTask == nil else { return }
        repeatTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            while !Task.isCancelled {
                await MainActor.run {
                    action()
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
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

private enum TabletBakeSessionMode: String, CaseIterable {
    case recipe = "Recipe"
    case adjust = "Adjust"

    var sortIndex: Int {
        TabletBakeSessionMode.allCases.firstIndex(of: self) ?? 0
    }
}

private enum TabletBakeSessionKeys {
    static let lastCollection = "tabletBakeSession.lastCollection"
    static let lastRecipe = "tabletBakeSession.lastRecipe"

    static func quantity(for recipe: any RecipeProtocol) -> String {
        "tabletBakeSession.quantity.\(recipe.collection).\(recipe.name)"
    }

    static func singleBatchSize(for recipe: any RecipeProtocol) -> String {
        "tabletBakeSession.singleBatchSize.\(recipe.collection).\(recipe.name)"
    }
}

private struct TabletBakeSessionView: View {
    let recipe: any RecipeProtocol
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    let onHistory: () -> Void

    @Environment(RecipeStore.self) private var store
    @State private var mode: TabletBakeSessionMode = .recipe
    @State private var modeTransitionEdge: Edge = .bottom
    @State private var quantity = 1
    @State private var singleBatchSize: Double
    @State private var ingredientPercents: [Int: Double] = [:]
    @State private var extraIngredientAmounts: [Int: Double] = [:]
    @State private var ingredientTemps: [Int: Double] = [:]
    @State private var prefermentIngredientPercents: [Int: Double] = [:]
    @State private var ingredientWeights: [Int: Double] = [:]
    @State private var prefermentIngredientWeights: [Int: Double] = [:]
    @State private var prefermentTotalPercent: Double?
    @State private var calculatedRecipe: (any CalculatedRecipeProtocol)?
    @State private var calculationError: String?
    @State private var noteText = ""

    private let calculator = Calculator.shared
    private let settings = Settings.shared
    private let weightFormatter = WeightFormatter.shared
    private let percentFormatter = PercentFormatter.shared

    init(
        recipe: any RecipeProtocol,
        onEdit: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onHistory: @escaping () -> Void
    ) {
        self.recipe = recipe
        self.onEdit = onEdit
        self.onCopy = onCopy
        self.onShare = onShare
        self.onHistory = onHistory
        let defaults = UserDefaults.standard
        let savedQuantity = defaults.integer(forKey: TabletBakeSessionKeys.quantity(for: recipe))
        let savedSize = defaults.double(forKey: TabletBakeSessionKeys.singleBatchSize(for: recipe))
        _quantity = State(initialValue: savedQuantity > 0 ? savedQuantity : 1)
        _singleBatchSize = State(initialValue: savedSize > 0 ? savedSize : recipe.defaultWeight)
    }

    private var totalBatchSize: Double {
        singleBatchSize * Double(max(quantity, 1))
    }

    private var modeBinding: Binding<TabletBakeSessionMode> {
        Binding {
            mode
        } set: { newMode in
            if newMode != mode {
                modeTransitionEdge = newMode.sortIndex > mode.sortIndex ? .bottom : .top
            }
            mode = newMode
        }
    }

    private var modeTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: modeTransitionEdge == .bottom ? 28 : -28)),
            removal: .opacity
        )
    }

    private var prefermentRecipe: CalculatedPrefermentRecipe? {
        calculatedRecipe as? CalculatedPrefermentRecipe
    }

    private var finalDoughIngredients: [CalculatedIngredient] {
        calculatedRecipe?.ingredients.filter { $0.extraAmount == nil } ?? []
    }

    private var extraIngredients: [CalculatedIngredient] {
        calculatedRecipe?.ingredients.filter { $0.extraAmount != nil } ?? []
    }

    private var preferment: Preferment? {
        (recipe as? PrefermentRecipe)?.preferment
    }

    private var hasTemperatures: Bool {
        recipe.containsVariableTemps()
    }

    private var isWeightRecipe: Bool {
        recipe.measurementMode == .weight
    }

    private var hasAdditionalIngredients: Bool {
        recipe.ingredients.contains { $0.extraAmount != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ZStack {
                Group {
                    switch mode {
                    case .recipe:
                        recipeFocus
                    case .adjust:
                        adjustFocus
                    }
                }
                .id(mode)
                .transition(modeTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .clipped()
            .animation(.easeInOut(duration: 0.2), value: mode)
        }
        .background(Color(.systemBackground))
        .onAppear {
            store.recordOpened(recipe: recipe)
            calculate()
        }
        .onChange(of: quantity) { _, _ in
            saveBatchSettings()
            calculate()
        }
        .onChange(of: singleBatchSize) { _, _ in
            saveBatchSettings()
            calculate()
        }
        .onChange(of: ingredientPercents) { _, _ in calculate() }
        .onChange(of: extraIngredientAmounts) { _, _ in calculate() }
        .onChange(of: ingredientTemps) { _, _ in calculate() }
        .onChange(of: prefermentIngredientPercents) { _, _ in calculate() }
        .onChange(of: ingredientWeights) { _, _ in calculate() }
        .onChange(of: prefermentIngredientWeights) { _, _ in calculate() }
        .onChange(of: prefermentTotalPercent) { _, _ in calculate() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                CollectionAvatar(collection: recipe.collection, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(DefaultLocalization.collectionName(recipe.collection))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                tabletToolbarButtons
            }
            modePicker
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private var modePicker: some View {
        Picker("Mode", selection: modeBinding) {
            ForEach(TabletBakeSessionMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 240)
    }

    private var tabletToolbarButtons: some View {
        HStack(spacing: 8) {
            toolbarButton(systemImage: "pencil", label: "Edit", action: onEdit)
            toolbarButton(systemImage: "plus.square.on.square", label: "Copy", action: onCopy)
            toolbarButton(systemImage: "square.and.arrow.up", label: "Share", action: onShare)
            toolbarButton(systemImage: "clock.arrow.circlepath", label: "History", action: onHistory)
        }
    }

    private func toolbarButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .tabletIconButtonChrome()
        .accessibilityLabel(label)
    }

    private var recipeFocus: some View {
        VStack(spacing: 18) {
            batchSummary
            HStack(alignment: .top, spacing: 18) {
                ingredientsColumn
                    .frame(width: 310)
                instructionsColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            sessionNote
        }
        .padding(24)
    }

    private var batchSummary: some View {
        HStack(spacing: 12) {
            metricCard(title: "Quantity", value: "\(quantity)")
            metricCard(title: "Single Batch Size", value: weightFormatter.format(weight: singleBatchSize))
            metricCard(title: "Total Batch Size", value: weightFormatter.format(weight: totalBatchSize))
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var ingredientsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let prefermentRecipe {
                    ingredientSection(
                        title: prefermentRecipe.preferment.name,
                        trailing: weightFormatter.format(weight: prefermentRecipe.preferment.weight),
                        ingredients: prefermentRecipe.preferment.ingredients
                    )
                    finalDoughSection(preferment: prefermentRecipe.preferment)
                } else {
                    ingredientSection(title: "Ingredients", ingredients: finalDoughIngredients)
                }

                if !extraIngredients.isEmpty {
                    extraIngredientSection
                }

                if let error = calculationError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ingredientSection(title: String, trailing: String? = nil, ingredients: [CalculatedIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)

            ForEach(ingredients, id: \.name) { ingredient in
                ingredientRow(name: ingredient.name, amount: weightFormatter.format(weight: ingredient.weight))
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 1)
        }
    }

    private func finalDoughSection(preferment: CalculatedPreferment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Final Dough")
                .font(.headline)
                .padding(.bottom, 8)
            ForEach(finalDoughIngredients, id: \.name) { ingredient in
                let prefermentWeight = preferment.ingredients.first { $0.name == ingredient.name }?.weight ?? 0
                ingredientRow(name: ingredient.name, amount: weightFormatter.format(weight: ingredient.weight - prefermentWeight))
            }
            ingredientRow(name: preferment.name, amount: weightFormatter.format(weight: preferment.weight))
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.7)
        }
    }

    private var extraIngredientSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Additional Ingredients")
                .font(.headline)
                .padding(.bottom, 8)
            ForEach(extraIngredients, id: \.name) { ingredient in
                if let amount = ingredient.extraAmount, let unit = ingredient.extraUnit {
                    ingredientRow(name: ingredient.name, amount: VolumeUnitFormatter.format(amount: amount, unit: unit))
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.7)
        }
    }

    private func ingredientRow(name: String, amount: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .lineLimit(2)
                Spacer(minLength: 12)
                Text(amount)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 7)
            Divider()
        }
    }

    private var instructionsColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Instructions")
                .font(.headline)
            if recipe.instructions.isEmpty {
                ContentUnavailableView("No Instructions", systemImage: "list.number")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(.tint, in: Circle())
                                Text(instruction.step)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    private var sessionNote: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Note")
                        .font(.headline)
                    Text("Save observations about this bake to the recipe history.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Save Note") {
                    saveNote()
                }
                .buttonStyle(.borderedProminent)
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            TextField("Crumb, timing, temperature, substitutions...", text: $noteText, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.plain)
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 0.5)
                }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var adjustFocus: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Adjust Batch")
                    .font(.title.bold())

                HStack(alignment: .top, spacing: 18) {
                    quantityCard
                    singleBatchSizeCard
                    totalBatchSizeCard
                }

                HStack(alignment: .top, spacing: 18) {
                    if preferment != nil {
                        prefermentAdjustPanel
                    }
                    mainDoughAdjustPanel
                    temperatureAdjustPanel
                }

                if let error = calculationError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(28)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var quantityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quantity")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            TextField("1", value: quantityBinding, format: .number)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separator), lineWidth: 0.5)
                }
            Spacer()
            HStack(spacing: 10) {
                Button {
                    quantity = max(1, quantity - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .tabletIconButtonChrome()
                .disabled(quantity <= 1)

                Button {
                    quantity = min(99, quantity + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tabletIconButtonChrome()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.7)
        }
    }

    private var quantityBinding: Binding<Int> {
        Binding(
            get: { quantity },
            set: { quantity = min(99, max(1, $0)) }
        )
    }

    private var totalBatchSizeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Total Batch Size")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(weightFormatter.format(weight: totalBatchSize))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.7)
        }
    }

    private var prefermentAdjustPanel: some View {
        adjustPanel(title: "Preferment") {
            if let preferment {
                adjustInputRow(
                    title: "Flour of Total",
                    placeholder: preferment.flourPercentage,
                    value: $prefermentTotalPercent,
                    unit: percentFormatter.percentSymbol
                )
                ForEach(Array(preferment.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    if isWeightRecipe {
                        adjustInputRow(
                            title: ingredient.name,
                            placeholder: ingredient.defaultWeight ?? 0,
                            value: Binding(
                                get: { prefermentIngredientWeights[index] },
                                set: { prefermentIngredientWeights[index] = $0 }
                            ),
                            unit: String(localized: "unit.grams.short", defaultValue: "g")
                        )
                    } else if ingredient.isFlour {
                        adjustReadOnlyRow(
                            title: ingredient.name,
                            value: percentFormatter.format(percent: ingredient.defaultPercentage)
                        )
                    } else {
                        adjustInputRow(
                            title: ingredient.name,
                            placeholder: ingredient.defaultPercentage,
                            value: Binding(
                                get: { prefermentIngredientPercents[index] },
                                set: { prefermentIngredientPercents[index] = $0 }
                            ),
                            unit: percentFormatter.percentSymbol
                        )
                    }
                }
            } else {
                ContentUnavailableView("No Preferment", systemImage: "timer")
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
    }

    private var mainDoughAdjustPanel: some View {
        adjustPanel(title: isWeightRecipe ? "Main Dough Weights" : "Main Dough") {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                if ingredient.extraAmount != nil {
                    EmptyView()
                } else if isWeightRecipe {
                    adjustInputRow(
                        title: ingredient.name,
                        placeholder: ingredient.defaultWeight ?? 0,
                        value: Binding(
                            get: { ingredientWeights[index] },
                            set: { ingredientWeights[index] = $0 }
                        ),
                        unit: String(localized: "unit.grams.short", defaultValue: "g")
                    )
                } else if ingredient.isFlour {
                    adjustReadOnlyRow(
                        title: ingredient.name,
                        value: percentFormatter.format(percent: ingredient.defaultPercentage)
                    )
                } else {
                    adjustInputRow(
                        title: ingredient.name,
                        placeholder: ingredient.defaultPercentage,
                        value: Binding(
                            get: { ingredientPercents[index] },
                            set: { ingredientPercents[index] = $0 }
                        ),
                        unit: percentFormatter.percentSymbol
                    )
                }
            }

            if hasAdditionalIngredients {
                Divider()
                Text("Additional Ingredients")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    if let amount = ingredient.extraAmount, let unit = ingredient.extraUnit {
                        adjustInputRow(
                            title: ingredient.name,
                            placeholder: amount,
                            value: Binding(
                                get: { extraIngredientAmounts[index] },
                                set: { extraIngredientAmounts[index] = $0 }
                            ),
                            unit: VolumeUnitFormatter.label(unit: unit, amount: extraIngredientAmounts[index] ?? amount)
                        )
                    }
                }
            }
        }
    }

    private var temperatureAdjustPanel: some View {
        adjustPanel(title: "Temperature") {
            if hasTemperatures {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    if let temperature = ingredient.temperature {
                        adjustInputRow(
                            title: ingredient.name,
                            placeholder: temperature.value,
                            value: Binding(
                                get: { ingredientTemps[index] },
                                set: { ingredientTemps[index] = $0 }
                            ),
                            unit: settings.preferredTemp().localizedSymbol
                        )
                    }
                }
                if let preferment {
                    ForEach(Array(preferment.ingredients.enumerated()), id: \.offset) { index, ingredient in
                        if let temperature = ingredient.temperature {
                            adjustInputRow(
                                title: "\(preferment.name) – \(ingredient.name)",
                                placeholder: temperature.value,
                                value: Binding(
                                    get: { ingredientTemps[1000 + index] },
                                    set: { ingredientTemps[1000 + index] = $0 }
                                ),
                                unit: settings.preferredTemp().localizedSymbol
                            )
                        }
                    }
                }
            } else {
                ContentUnavailableView("No Temperatures", systemImage: "thermometer.medium")
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
    }

    private func adjustPanel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.7)
        }
    }

    private func adjustInputRow(title: String, placeholder: Double, value: Binding<Double?>, unit: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    TextField(
                        String(format: "%.4g", placeholder),
                        value: value,
                        format: .number
                    )
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .frame(width: 70)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 7)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    }
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 18, alignment: .leading)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.vertical, 10)
            Divider()
        }
    }

    private func adjustReadOnlyRow(title: String, value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .lineLimit(2)
                Spacer(minLength: 10)
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            Divider()
        }
    }

    private var singleBatchSizeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Single Batch Size")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("\(Int(recipe.defaultWeight))",
                          value: $singleBatchSize,
                          format: .number)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .frame(minWidth: 80)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.separator), lineWidth: 0.5)
                }
                Text(String(localized: "unit.grams.short", defaultValue: "g"))
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }
            .environment(\.layoutDirection, .leftToRight)
            Spacer()
            HStack(spacing: 10) {
                TabletRepeatButton(systemImage: "minus", isProminent: false) {
                    decrementSingleBatchSize()
                }

                TabletRepeatButton(systemImage: "plus", isProminent: true) {
                    incrementSingleBatchSize()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.7)
        }
    }

    private var singleBatchSizeStep: Double {
        switch abs(singleBatchSize) {
        case ..<10:
            1
        case ..<100:
            5
        case ..<500:
            10
        case ..<1_000:
            25
        default:
            50
        }
    }

    private func incrementSingleBatchSize() {
        singleBatchSize += singleBatchSizeStep
    }

    private func decrementSingleBatchSize() {
        singleBatchSize = max(1, singleBatchSize - singleBatchSizeStep)
    }

    private func calculate() {
        do {
            calculatedRecipe = try calculator.calculate(
                ingredients: measuredIngredients(),
                preferment: measuredPreferment(),
                recipe: recipe,
                totalWeight: totalBatchSize
            )
            calculationError = nil
        } catch CalculationError.finalDoughNegativeValue(let name, let value) {
            calculationError = String(
                format: String(localized: "calculator.error.final_dough_negative", defaultValue: "Calculated final dough %@ weight is %@. Please adjust input."),
                name,
                weightFormatter.format(weight: value)
            )
        } catch CalculationError.prefermentNegativeValue(let name, let value) {
            calculationError = String(
                format: String(localized: "calculator.error.preferment_negative", defaultValue: "Calculated preferment %@ weight is %@. Please adjust input."),
                name,
                weightFormatter.format(weight: value)
            )
        } catch {
            calculationError = String(localized: "calculator.error.unexpected", defaultValue: "An unexpected calculation error occurred.")
        }
    }

    private func measuredIngredients() -> [MeasuredIngredient] {
        recipe.ingredients.enumerated().map { index, ingredient in
            var temperature = ingredient.temperature
            if let rawTemp = ingredientTemps[index] {
                temperature = Temperature(value: rawTemp, measurement: settings.preferredTemp())
            }
            return MeasuredIngredient(
                ingredient: ingredient,
                percent: ingredientPercents[index] ?? ingredient.defaultPercentage,
                temperature: temperature,
                weight: ingredientWeights[index] ?? ingredient.defaultWeight,
                extraAmountOverride: extraIngredientAmounts[index]
            )
        }
    }

    private func measuredPreferment() -> MeasuredPreferment? {
        guard let preferment else { return nil }
        return MeasuredPreferment(
            ingredients: preferment.ingredients.enumerated().map { index, ingredient in
                var temperature = ingredient.temperature
                if let rawTemp = ingredientTemps[1000 + index] {
                    temperature = Temperature(value: rawTemp, measurement: settings.preferredTemp())
                }
                return MeasuredIngredient(
                    ingredient: ingredient,
                    percent: prefermentIngredientPercents[index] ?? ingredient.defaultPercentage,
                    temperature: temperature,
                    weight: prefermentIngredientWeights[index] ?? ingredient.defaultWeight
                )
            },
            name: preferment.name,
            flourPercentage: prefermentTotalPercent ?? preferment.flourPercentage
        )
    }

    private func saveBatchSettings() {
        UserDefaults.standard.set(max(quantity, 1), forKey: TabletBakeSessionKeys.quantity(for: recipe))
        UserDefaults.standard.set(singleBatchSize, forKey: TabletBakeSessionKeys.singleBatchSize(for: recipe))
    }

    private func saveNote() {
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try store.addNote(text, to: recipe)
            noteText = ""
        } catch {
            calculationError = String(localized: "calculated.error.save_note", defaultValue: "Could not save this note.")
        }
    }
}
