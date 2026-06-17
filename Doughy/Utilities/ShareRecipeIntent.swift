//
//  ShareRecipeIntent.swift
//  Doughy

import AppIntents
import UIKit

// MARK: - Entity

struct RecipeAppEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Recipe")
    static var defaultQuery = RecipeAppEntityQuery()

    var id: String  // "Collection/Name"
    let recipeName: String
    let collection: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: recipeName),
            subtitle: LocalizedStringResource(stringLiteral: collection)
        )
    }

    init(recipe: any RecipeProtocol) {
        self.recipeName = recipe.name
        self.collection = recipe.collection
        self.id = "\(recipe.collection)/\(recipe.name)"
    }
}

// MARK: - Query

struct RecipeAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [RecipeAppEntity] {
        let all = await MainActor.run { Settings.shared.refreshRecipes().flatMap(\.recipes) }
        return identifiers.compactMap { id in
            all.first { "\($0.collection)/\($0.name)" == id }.map { RecipeAppEntity(recipe: $0) }
        }
    }

    func suggestedEntities() async throws -> [RecipeAppEntity] {
        await MainActor.run { Settings.shared.refreshRecipes().flatMap(\.recipes).map { RecipeAppEntity(recipe: $0) } }
    }

    func entities(matching string: String) async throws -> [RecipeAppEntity] {
        let all = await MainActor.run { Settings.shared.refreshRecipes().flatMap(\.recipes) }
        return all
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map { RecipeAppEntity(recipe: $0) }
    }
}

// MARK: - Pending share request (bridged through NotificationCenter)

struct PendingShareRequest: Equatable {
    let recipeName: String
    let collection: String
    let recipientName: String?
}

struct PendingOpenRecipeRequest: Equatable {
    let recipeName: String
    let collection: String
}

// MARK: - Intent

struct ShareRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "Share Recipe"
    static var description = IntentDescription(
        "Export a recipe from Doughy as a file you can send to anyone.",
        categoryName: "Recipe"
    )
    static let openAppWhenRun = true

    @Parameter(
        title: "Recipe",
        description: "The recipe to share",
        requestValueDialog: IntentDialog("Which recipe would you like to share?")
    )
    var recipe: RecipeAppEntity

    @Parameter(
        title: "Recipient",
        description: "Their name will appear on the recipe when opened"
    )
    var recipient: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .doughyShareFromIntent,
            object: PendingShareRequest(
                recipeName: recipe.recipeName,
                collection: recipe.collection,
                recipientName: recipient
            )
        )
        return .result()
    }
}

struct OpenRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Recipe"
    static var description = IntentDescription(
        "Open a saved recipe in Doughy.",
        categoryName: "Recipe"
    )
    static let openAppWhenRun = true

    @Parameter(
        title: "Recipe",
        description: "The recipe to open",
        requestValueDialog: IntentDialog("Which recipe would you like to open?")
    )
    var recipe: RecipeAppEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .doughyOpenRecipeFromIntent,
            object: PendingOpenRecipeRequest(
                recipeName: recipe.recipeName,
                collection: recipe.collection
            )
        )
        return .result()
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let doughyShareFromIntent = Notification.Name("DoughyShareFromIntent")
    static let doughyOpenRecipeFromIntent = Notification.Name("DoughyOpenRecipeFromIntent")
}
