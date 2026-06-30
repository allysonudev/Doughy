//
//  RecipeListView+TabletSession.swift
//  Doughy
//

import SwiftUI

struct TabletLibraryScrollRequest: Equatable {
    let collectionName: String
    let id = UUID()
}

struct TabletRepeatButton: View {
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    @State var repeatTask: Task<Void, Never>?

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
    var styledButton: some View {
        if isProminent {
            button
                .buttonStyle(.borderedProminent)
        } else {
            button
                .buttonStyle(.bordered)
        }
    }

    var button: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 44, height: 44)
        }
        .tabletIconButtonChrome()
    }

    func startRepeating() {
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

    func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
enum TabletBakeSessionMode: String, CaseIterable {
    case recipe = "Recipe"
    case adjust = "Adjust"

    var sortIndex: Int {
        TabletBakeSessionMode.allCases.firstIndex(of: self) ?? 0
    }
}

enum TabletBakeSessionKeys {
    static let lastCollection = "tabletBakeSession.lastCollection"
    static let lastRecipe = "tabletBakeSession.lastRecipe"

    static func quantity(for recipe: any RecipeProtocol) -> String {
        "tabletBakeSession.quantity.\(recipe.collection).\(recipe.name)"
    }

    static func singleBatchSize(for recipe: any RecipeProtocol) -> String {
        "tabletBakeSession.singleBatchSize.\(recipe.collection).\(recipe.name)"
    }
}

struct TabletBakeSessionView: View {
    let recipe: any RecipeProtocol
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    let onHistory: () -> Void

    @Environment(RecipeStore.self) var store
    @State var mode: TabletBakeSessionMode = .recipe
    @State var modeTransitionEdge: Edge = .bottom
    @State var quantity = 1
    @State var singleBatchSize: Double
    @State var ingredientPercents: [Int: Double] = [:]
    @State var extraIngredientAmounts: [Int: Double] = [:]
    @State var ingredientTemps: [Int: Double] = [:]
    @State var prefermentIngredientPercents: [Int: Double] = [:]
    @State var ingredientWeights: [Int: Double] = [:]
    @State var prefermentIngredientWeights: [Int: Double] = [:]
    @State var prefermentTotalPercent: Double?
    @State var calculatedRecipe: (any CalculatedRecipeProtocol)?
    @State var calculationError: String?
    @State var noteText = ""

    let calculator = Calculator.shared
    let settings = Settings.shared
    let weightFormatter = WeightFormatter.shared
    let percentFormatter = PercentFormatter.shared

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

    var totalBatchSize: Double {
        singleBatchSize * Double(max(quantity, 1))
    }

    var modeBinding: Binding<TabletBakeSessionMode> {
        Binding {
            mode
        } set: { newMode in
            if newMode != mode {
                modeTransitionEdge = newMode.sortIndex > mode.sortIndex ? .bottom : .top
            }
            mode = newMode
        }
    }

    var modeTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: modeTransitionEdge == .bottom ? 28 : -28)),
            removal: .opacity
        )
    }

    var prefermentRecipe: CalculatedPrefermentRecipe? {
        calculatedRecipe as? CalculatedPrefermentRecipe
    }

    var finalDoughIngredients: [CalculatedIngredient] {
        calculatedRecipe?.ingredients.filter { $0.extraAmount == nil } ?? []
    }

    var extraIngredients: [CalculatedIngredient] {
        calculatedRecipe?.ingredients.filter { $0.extraAmount != nil } ?? []
    }

    var preferment: Preferment? {
        (recipe as? PrefermentRecipe)?.preferment
    }

    var hasTemperatures: Bool {
        recipe.containsVariableTemps()
    }

    var isWeightRecipe: Bool {
        recipe.measurementMode == .weight
    }

    var hasAdditionalIngredients: Bool {
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

    var header: some View {
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

    var modePicker: some View {
        Picker("Mode", selection: modeBinding) {
            ForEach(TabletBakeSessionMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 240)
    }

    var tabletToolbarButtons: some View {
        HStack(spacing: 8) {
            toolbarButton(systemImage: "pencil", label: "Edit", action: onEdit)
            toolbarButton(systemImage: "plus.square.on.square", label: "Copy", action: onCopy)
            toolbarButton(systemImage: "square.and.arrow.up", label: "Share", action: onShare)
            toolbarButton(systemImage: "clock.arrow.circlepath", label: "History", action: onHistory)
        }
    }

    func toolbarButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .tabletIconButtonChrome()
        .accessibilityLabel(label)
    }

    var recipeFocus: some View {
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

    var batchSummary: some View {
        HStack(spacing: 12) {
            metricCard(title: "Quantity", value: "\(quantity)")
            metricCard(title: "Single Batch Size", value: weightFormatter.format(weight: singleBatchSize))
            metricCard(title: "Total Batch Size", value: weightFormatter.format(weight: totalBatchSize))
        }
    }

    func metricCard(title: String, value: String) -> some View {
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

    var ingredientsColumn: some View {
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

    func ingredientSection(title: String, trailing: String? = nil, ingredients: [CalculatedIngredient]) -> some View {
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

    func finalDoughSection(preferment: CalculatedPreferment) -> some View {
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

    var extraIngredientSection: some View {
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

    func ingredientRow(name: String, amount: String) -> some View {
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

    var instructionsColumn: some View {
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

    var sessionNote: some View {
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

    var adjustFocus: some View {
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

    var quantityCard: some View {
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

    var quantityBinding: Binding<Int> {
        Binding(
            get: { quantity },
            set: { quantity = min(99, max(1, $0)) }
        )
    }

    var totalBatchSizeCard: some View {
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

    var prefermentAdjustPanel: some View {
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

    var mainDoughAdjustPanel: some View {
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

    var temperatureAdjustPanel: some View {
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

    func adjustPanel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
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

    func adjustInputRow(title: String, placeholder: Double, value: Binding<Double?>, unit: String) -> some View {
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

    func adjustReadOnlyRow(title: String, value: String) -> some View {
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

    var singleBatchSizeCard: some View {
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

    var singleBatchSizeStep: Double {
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

    func incrementSingleBatchSize() {
        singleBatchSize += singleBatchSizeStep
    }

    func decrementSingleBatchSize() {
        singleBatchSize = max(1, singleBatchSize - singleBatchSizeStep)
    }

    func calculate() {
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

    func measuredIngredients() -> [MeasuredIngredient] {
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

    func measuredPreferment() -> MeasuredPreferment? {
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

    func saveBatchSettings() {
        UserDefaults.standard.set(max(quantity, 1), forKey: TabletBakeSessionKeys.quantity(for: recipe))
        UserDefaults.standard.set(singleBatchSize, forKey: TabletBakeSessionKeys.singleBatchSize(for: recipe))
    }

    func saveNote() {
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
