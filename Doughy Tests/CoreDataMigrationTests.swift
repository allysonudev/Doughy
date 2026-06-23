//
//  CoreDataMigrationTests.swift
//  Doughy Tests
//

import XCTest
import CoreData
@testable import Doughy

/// Verifies that a SQLite store created with the data model shipped in Doughy 1.0
/// (git tag "1.0") still loads cleanly under the current model and that all of its
/// recipe data survives the automatic lightweight migration unchanged.
///
/// The 1.0 model is the same set of entities as today, minus the `extraAmount`/
/// `extraUnit` attributes on `XCIngredient`/`XCCalculatedIngredient` and minus the
/// `XCHistoryEntry` entity/`XCRecipe.historyEntries` relationship - both additive,
/// optional changes that Core Data can migrate automatically.
final class CoreDataMigrationTests: XCTestCase {

    func testLightweightMigrationFrom1_0PreservesRecipeData() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Doughy1_0Migration-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
        }

        try seedLegacyStore(at: storeURL)
        try assertMigratedStoreMatchesSeed(at: storeURL)
    }

    // MARK: - Seeding a 1.0-shaped store

    private func seedLegacyStore(at url: URL) throws {
        let container = persistentContainer(named: "LegacyDoughy", model: Self.legacyModel(), url: url)
        let context = container.viewContext

        let recipe = NSEntityDescription.insertNewObject(forEntityName: "XCRecipe", into: context)
        recipe.setValue("Sourdough Boule", forKey: "name")
        recipe.setValue("Breads", forKey: "collection")
        recipe.setValue(900.0, forKey: "defaultWeight")

        let flour = NSEntityDescription.insertNewObject(forEntityName: "XCIngredient", into: context)
        flour.setValue("Bread Flour", forKey: "name")
        flour.setValue(true, forKey: "isFlour")
        flour.setValue(100.0, forKey: "defaultPercentage")
        flour.setValue(recipe, forKey: "recipe")

        let water = NSEntityDescription.insertNewObject(forEntityName: "XCIngredient", into: context)
        water.setValue("Water", forKey: "name")
        water.setValue(false, forKey: "isFlour")
        water.setValue(75.0, forKey: "defaultPercentage")
        water.setValue(78.0, forKey: "temperature")
        water.setValue(recipe, forKey: "recipe")

        recipe.setValue(NSOrderedSet(array: [flour, water]), forKey: "ingredients")

        let step = NSEntityDescription.insertNewObject(forEntityName: "XCInstruction", into: context)
        step.setValue("Mix and autolyse for 30 minutes.", forKey: "step")
        step.setValue(recipe, forKey: "recipe")
        recipe.setValue(NSOrderedSet(array: [step]), forKey: "instructions")

        let preferment = NSEntityDescription.insertNewObject(forEntityName: "XCPreferment", into: context)
        preferment.setValue("Levain", forKey: "name")
        preferment.setValue(20.0, forKey: "flourPercentage")
        preferment.setValue(recipe, forKey: "recipe")

        let prefFlour = NSEntityDescription.insertNewObject(forEntityName: "XCIngredient", into: context)
        prefFlour.setValue("Bread Flour", forKey: "name")
        prefFlour.setValue(true, forKey: "isFlour")
        prefFlour.setValue(100.0, forKey: "defaultPercentage")
        prefFlour.setValue(preferment, forKey: "preferment")
        preferment.setValue(NSOrderedSet(array: [prefFlour]), forKey: "ingredients")

        recipe.setValue(preferment, forKey: "preferment")

        // A previously-calculated recipe, as written by "Set as Default" in 1.0.
        let calcRecipe = NSEntityDescription.insertNewObject(forEntityName: "XCCalculatedRecipe", into: context)
        calcRecipe.setValue("Sourdough Boule", forKey: "name")
        calcRecipe.setValue("Breads", forKey: "collection")
        calcRecipe.setValue(900.0, forKey: "weight")

        let calcFlour = NSEntityDescription.insertNewObject(forEntityName: "XCCalculatedIngredient", into: context)
        calcFlour.setValue("Bread Flour", forKey: "name")
        calcFlour.setValue(true, forKey: "isFlour")
        calcFlour.setValue(100.0, forKey: "percentage")
        calcFlour.setValue(100.0, forKey: "totalPercentage")
        calcFlour.setValue(514.0, forKey: "weight")
        calcFlour.setValue(calcRecipe, forKey: "recipe")
        calcRecipe.setValue(NSOrderedSet(array: [calcFlour]), forKey: "ingredients")

        try context.save()
    }

    // MARK: - Verifying the migrated store

    private func assertMigratedStoreMatchesSeed(at url: URL) throws {
        let container = NSPersistentContainer(name: "Doughy")
        let description = NSPersistentStoreDescription(url: url)
        container.persistentStoreDescriptions = [description]

        let loadExpectation = expectation(description: "load migrated store")
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5)
        XCTAssertNil(loadError, "Migrating the 1.0 store failed: \(String(describing: loadError))")

        let context = container.viewContext

        let recipes = try context.fetch(NSFetchRequest<XCRecipe>(entityName: "XCRecipe"))
        XCTAssertEqual(recipes.count, 1)
        guard let recipe = recipes.first else { return }

        XCTAssertEqual(recipe.name, "Sourdough Boule")
        XCTAssertEqual(recipe.collection, "Breads")
        XCTAssertEqual(recipe.defaultWeight, 900.0)
        // New, additive attributes/relationships - should be nil/empty, not crash or carry junk.
        XCTAssertNil(recipe.value(forKey: "defaultKey"), "defaultKey should be nil for pre-existing recipes")
        XCTAssertEqual(recipe.historyEntries?.count ?? 0, 0)

        let ingredients = recipe.sortedIngredients
        XCTAssertEqual(ingredients.count, 2)

        let flour = ingredients.first { $0.name == "Bread Flour" }
        XCTAssertEqual(flour?.isFlour, true)
        XCTAssertEqual(flour?.defaultPercentage, 100.0)
        // New, additive attributes - should be nil rather than corrupting old rows.
        XCTAssertNil(flour?.extraAmount)
        XCTAssertNil(flour?.extraUnit)

        let water = ingredients.first { $0.name == "Water" }
        XCTAssertEqual(water?.defaultPercentage, 75.0)
        XCTAssertEqual(water?.temperature, 78.0)

        let steps = recipe.sortedInstructions
        XCTAssertEqual(steps.map { $0.step }, ["Mix and autolyse for 30 minutes."])

        let preferment = recipe.preferment
        XCTAssertEqual(preferment?.name, "Levain")
        XCTAssertEqual(preferment?.flourPercentage, 20.0)
        let prefIngredients = preferment?.sortedIngredients ?? []
        XCTAssertEqual(prefIngredients.map { $0.name }, ["Bread Flour"])

        let calcRecipes = try context.fetch(NSFetchRequest<XCCalculatedRecipe>(entityName: "XCCalculatedRecipe"))
        XCTAssertEqual(calcRecipes.count, 1)
        let calcIngredients = calcRecipes.first?.sortedIngredients ?? []
        XCTAssertEqual(calcIngredients.first?.name, "Bread Flour")
        XCTAssertEqual(calcIngredients.first?.weight, 514.0)
        XCTAssertNil(calcIngredients.first?.extraAmount)
        XCTAssertNil(calcIngredients.first?.extraUnit)
    }

    // MARK: - Helpers

    private func persistentContainer(named name: String, model: NSManagedObjectModel, url: URL) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: name, managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        container.persistentStoreDescriptions = [description]

        let loadExpectation = expectation(description: "load \(name)")
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 5)
        XCTAssertNil(loadError, "Failed to load \(name): \(String(describing: loadError))")
        return container
    }

    // MARK: - The 1.0 model

    /// Builds the persistence model exactly as it shipped in Doughy 1.0 (git tag
    /// "1.0"): the same seven entities as the current model, but `XCIngredient` and
    /// `XCCalculatedIngredient` have no `extraAmount`/`extraUnit` attributes, and
    /// `XCRecipe` has no `historyEntries` relationship (there's no `XCHistoryEntry`
    /// entity at all).
    private static func legacyModel() -> NSManagedObjectModel {
        func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil) -> NSAttributeDescription {
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = optional
            attribute.defaultValue = defaultValue
            return attribute
        }

        func relationship(_ name: String, to destination: NSEntityDescription, toMany: Bool, ordered: Bool = false, optional: Bool = true) -> NSRelationshipDescription {
            let relationship = NSRelationshipDescription()
            relationship.name = name
            relationship.destinationEntity = destination
            relationship.minCount = 0
            relationship.maxCount = toMany ? 0 : 1
            relationship.isOptional = optional
            relationship.isOrdered = ordered
            relationship.deleteRule = .nullifyDeleteRule
            return relationship
        }

        let recipe = NSEntityDescription()
        recipe.name = "XCRecipe"
        recipe.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let ingredient = NSEntityDescription()
        ingredient.name = "XCIngredient"
        ingredient.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let preferment = NSEntityDescription()
        preferment.name = "XCPreferment"
        preferment.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let instruction = NSEntityDescription()
        instruction.name = "XCInstruction"
        instruction.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let calculatedRecipe = NSEntityDescription()
        calculatedRecipe.name = "XCCalculatedRecipe"
        calculatedRecipe.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let calculatedIngredient = NSEntityDescription()
        calculatedIngredient.name = "XCCalculatedIngredient"
        calculatedIngredient.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let calculatedPreferment = NSEntityDescription()
        calculatedPreferment.name = "XCCalculatedPreferment"
        calculatedPreferment.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        // XCRecipe
        let recipeIngredients = relationship("ingredients", to: ingredient, toMany: true, ordered: true, optional: false)
        let recipeInstructions = relationship("instructions", to: instruction, toMany: true, ordered: true)
        let recipePreferment = relationship("preferment", to: preferment, toMany: false)
        recipe.properties = [
            attribute("name", .stringAttributeType),
            attribute("collection", .stringAttributeType, optional: true),
            attribute("defaultWeight", .doubleAttributeType),
            recipeIngredients,
            recipeInstructions,
            recipePreferment,
        ]

        // XCIngredient
        let ingredientPreferment = relationship("preferment", to: preferment, toMany: false)
        let ingredientRecipe = relationship("recipe", to: recipe, toMany: false)
        ingredient.properties = [
            attribute("name", .stringAttributeType),
            attribute("defaultPercentage", .doubleAttributeType),
            attribute("isFlour", .booleanAttributeType, defaultValue: false),
            attribute("temperature", .doubleAttributeType, optional: true),
            ingredientPreferment,
            ingredientRecipe,
        ]

        // XCPreferment
        let prefermentIngredients = relationship("ingredients", to: ingredient, toMany: true, ordered: true, optional: false)
        let prefermentRecipe = relationship("recipe", to: recipe, toMany: false, optional: false)
        preferment.properties = [
            attribute("name", .stringAttributeType),
            attribute("flourPercentage", .doubleAttributeType),
            prefermentIngredients,
            prefermentRecipe,
        ]

        // XCInstruction
        let instructionRecipe = relationship("recipe", to: recipe, toMany: false)
        let instructionCalculatedRecipe = relationship("calculatedRecipe", to: calculatedRecipe, toMany: false)
        instruction.properties = [
            attribute("step", .stringAttributeType),
            instructionRecipe,
            instructionCalculatedRecipe,
        ]

        // XCCalculatedRecipe
        let calculatedRecipeIngredients = relationship("ingredients", to: calculatedIngredient, toMany: true, ordered: true)
        let calculatedRecipeInstructions = relationship("instructions", to: instruction, toMany: true, ordered: true)
        let calculatedRecipePreferment = relationship("preferment", to: calculatedPreferment, toMany: false)
        calculatedRecipe.properties = [
            attribute("name", .stringAttributeType),
            attribute("collection", .stringAttributeType),
            attribute("weight", .doubleAttributeType),
            calculatedRecipeIngredients,
            calculatedRecipeInstructions,
            calculatedRecipePreferment,
        ]

        // XCCalculatedIngredient
        let calculatedIngredientPreferment = relationship("preferment", to: calculatedPreferment, toMany: false)
        let calculatedIngredientRecipe = relationship("recipe", to: calculatedRecipe, toMany: false)
        calculatedIngredient.properties = [
            attribute("name", .stringAttributeType),
            attribute("isFlour", .booleanAttributeType, defaultValue: false),
            attribute("percentage", .doubleAttributeType),
            attribute("totalPercentage", .doubleAttributeType),
            attribute("weight", .doubleAttributeType),
            attribute("temperature", .doubleAttributeType, optional: true),
            calculatedIngredientPreferment,
            calculatedIngredientRecipe,
        ]

        // XCCalculatedPreferment
        let calculatedPrefermentIngredients = relationship("ingredients", to: calculatedIngredient, toMany: true, ordered: true, optional: false)
        let calculatedPrefermentRecipe = relationship("recipe", to: calculatedRecipe, toMany: false)
        calculatedPreferment.properties = [
            attribute("name", .stringAttributeType),
            attribute("flourPercentage", .doubleAttributeType),
            attribute("weight", .doubleAttributeType),
            calculatedPrefermentIngredients,
            calculatedPrefermentRecipe,
        ]

        // Inverses
        recipeIngredients.inverseRelationship = ingredientRecipe
        ingredientRecipe.inverseRelationship = recipeIngredients
        recipeInstructions.inverseRelationship = instructionRecipe
        instructionRecipe.inverseRelationship = recipeInstructions
        recipePreferment.inverseRelationship = prefermentRecipe
        prefermentRecipe.inverseRelationship = recipePreferment
        prefermentIngredients.inverseRelationship = ingredientPreferment
        ingredientPreferment.inverseRelationship = prefermentIngredients

        calculatedRecipeIngredients.inverseRelationship = calculatedIngredientRecipe
        calculatedIngredientRecipe.inverseRelationship = calculatedRecipeIngredients
        calculatedRecipeInstructions.inverseRelationship = instructionCalculatedRecipe
        instructionCalculatedRecipe.inverseRelationship = calculatedRecipeInstructions
        calculatedRecipePreferment.inverseRelationship = calculatedPrefermentRecipe
        calculatedPrefermentRecipe.inverseRelationship = calculatedRecipePreferment
        calculatedPrefermentIngredients.inverseRelationship = calculatedIngredientPreferment
        calculatedIngredientPreferment.inverseRelationship = calculatedPrefermentIngredients

        let model = NSManagedObjectModel()
        model.entities = [
            recipe, ingredient, preferment, instruction,
            calculatedRecipe, calculatedIngredient, calculatedPreferment,
        ]
        return model
    }
}
