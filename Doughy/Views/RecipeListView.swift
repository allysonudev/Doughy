//
//  RecipeListView.swift
//  Doughy

import SwiftUI

struct RecipeListView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(RecipeStore.self) private var store
    @State private var showingCreate = false
    @State private var editingRecipe: RecipeWrapper?
    @State private var copyingRecipe: RecipeWrapper?
    @State private var sharingRecipe: RecipeWrapper?
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

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                tabletContent
            } else {
                phoneContent
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
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
            .environment(store)
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
            restoreTabletSelectionIfNeeded()
        }
        .onChange(of: store.collections.map(\.name)) { _, _ in
            restoreTabletSelectionIfNeeded()
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
            if showingTabletLibrary {
                tabletRecipeList
                    .frame(width: 320)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            Divider()
            Group {
                if let wrapper = selectedRecipe ?? firstRecipeWrapper {
                    TabletBakeSessionView(recipe: wrapper.recipe)
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

    private var tabletRail: some View {
        VStack(spacing: 18) {
            Button {
                withAnimation(.snappy) {
                    showingTabletLibrary.toggle()
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Recipe library")

            Button {
                showingCreate = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("addRecipeButton")
            .accessibilityLabel("Add recipe")

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Settings")
        }
        .padding(.vertical, 18)
        .frame(width: 78)
        .background(.bar)
    }

    private var tabletRecipeList: some View {
        List {
            ForEach(store.collections, id: \.name) { collection in
                Section(collection.name) {
                    ForEach(collection.recipes, id: \.name) { recipe in
                        Button {
                            select(recipe: recipe)
                            showingTabletLibrary = false
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
                }
            }
        }
        .listStyle(.sidebar)
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

    @Environment(RecipeStore.self) private var store
    @State private var mode: TabletBakeSessionMode = .recipe
    @State private var quantity = 1
    @State private var singleBatchSize: Double
    @State private var calculatedRecipe: (any CalculatedRecipeProtocol)?
    @State private var calculationError: String?
    @State private var noteText = ""

    private let calculator = Calculator.shared
    private let weightFormatter = WeightFormatter.shared

    init(recipe: any RecipeProtocol) {
        self.recipe = recipe
        let defaults = UserDefaults.standard
        let savedQuantity = defaults.integer(forKey: TabletBakeSessionKeys.quantity(for: recipe))
        let savedSize = defaults.double(forKey: TabletBakeSessionKeys.singleBatchSize(for: recipe))
        _quantity = State(initialValue: savedQuantity > 0 ? savedQuantity : 1)
        _singleBatchSize = State(initialValue: savedSize > 0 ? savedSize : recipe.defaultWeight)
    }

    private var totalBatchSize: Double {
        singleBatchSize * Double(max(quantity, 1))
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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch mode {
            case .recipe:
                recipeFocus
            case .adjust:
                adjustFocus
            }
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
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Last active recipe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(recipe.name)
                    .font(.largeTitle.bold())
            }
            Spacer()
            Picker("Mode", selection: $mode) {
                ForEach(TabletBakeSessionMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func ingredientRow(name: String, amount: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .lineLimit(2)
            Spacer(minLength: 12)
            Text(amount)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 7)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Note")
                .font(.headline)
            TextField("Add a note about this batch...", text: $noteText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button("Save Bake Note") {
                saveNote()
            }
            .buttonStyle(.borderedProminent)
            .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var adjustFocus: some View {
        Form {
            Section("Batch") {
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                HStack {
                    Text("Single Batch Size")
                    Spacer()
                    TextField("\(Int(recipe.defaultWeight))",
                              value: $singleBatchSize,
                              format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 120)
                    Text("g")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Total Batch Size")
                    Spacer()
                    Text(weightFormatter.format(weight: totalBatchSize))
                        .fontWeight(.semibold)
                }
            }
            Section {
                Button("Done") {
                    mode = .recipe
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
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
        recipe.ingredients.map {
            MeasuredIngredient(
                ingredient: $0,
                percent: $0.defaultPercentage,
                temperature: $0.temperature,
                weight: $0.defaultWeight,
                extraAmountOverride: nil
            )
        }
    }

    private func measuredPreferment() -> MeasuredPreferment? {
        guard let preferment = (recipe as? PrefermentRecipe)?.preferment else { return nil }
        return MeasuredPreferment(
            ingredients: preferment.ingredients.map {
                MeasuredIngredient(
                    ingredient: $0,
                    percent: $0.defaultPercentage,
                    temperature: $0.temperature,
                    weight: $0.defaultWeight
                )
            },
            name: preferment.name,
            flourPercentage: preferment.flourPercentage
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
