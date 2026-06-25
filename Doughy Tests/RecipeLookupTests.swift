//
//  RecipeLookupTests.swift
//  Doughy Tests
//

import XCTest
import CoreData
@testable import Doughy

/// Regression coverage for looking a stored recipe back up from its *display*
/// name. Built-in recipes show a localized name while their stored name stays
/// canonical, so `RecipeReader.match` must resolve a default's localized display
/// name back to its stored row — otherwise notes/history/edits fail to find the
/// recipe in any non-English language (it worked in English only because there
/// the localized and stored names are identical).
final class RecipeLookupTests: XCTestCase {

    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        let container = NSPersistentContainer(name: "Doughy")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError, "Failed to load in-memory store: \(String(describing: loadError))")
        context = container.viewContext
    }

    private func makeRecipe(name: String, collection: String, defaultKey: String? = nil) -> XCRecipe {
        let recipe = NSEntityDescription.insertNewObject(forEntityName: "XCRecipe", into: context) as! XCRecipe
        recipe.name = name
        recipe.collection = collection
        if let defaultKey { recipe.setValue(defaultKey, forKey: "defaultKey") }
        return recipe
    }

    func testMatchesUserRecipeByStoredName() {
        let mine = makeRecipe(name: "My Sourdough", collection: "Breads")
        XCTAssertEqual(RecipeReader.match(name: "My Sourdough", in: [mine]), mine)
        XCTAssertNil(RecipeReader.match(name: "Something Else", in: [mine]))
    }

    /// The core fix: a default recipe whose stored name differs from the name the
    /// user sees (as happens once the display name is localized) is still found.
    func testMatchesDefaultByLocalizedDisplayName() {
        let key = DefaultRecipeFactory.Key.bagelsWithPoolish
        let displayName = NSLocalizedString(key, comment: "")
        XCTAssertNotEqual(displayName, key, "Test needs a key that resolves to a real string")

        // Simulate the non-English case: stored name is the canonical value, which
        // differs from the (localized) display name the caller passes.
        let stored = "__canonical_stored_name__"
        let recipe = makeRecipe(name: stored, collection: "Bagels", defaultKey: key)

        XCTAssertEqual(RecipeReader.match(name: displayName, in: [recipe]), recipe,
                       "A default recipe should be found by its localized display name")
        XCTAssertEqual(RecipeReader.match(name: stored, in: [recipe]), recipe,
                       "It should also still be found by its canonical stored name")
        XCTAssertNil(RecipeReader.match(name: "unrelated", in: [recipe]))
    }

    /// Exact stored-name matches win over the localized fallback.
    func testExactStoredNameTakesPrecedence() {
        let key = DefaultRecipeFactory.Key.bagelsWithPoolish
        let displayName = NSLocalizedString(key, comment: "")
        let defaultRecipe = makeRecipe(name: "__canonical__", collection: "Bagels", defaultKey: key)
        let userRecipe = makeRecipe(name: displayName, collection: "Bagels")

        // Both could satisfy `displayName`, but the exact stored-name match must win.
        XCTAssertEqual(RecipeReader.match(name: displayName, in: [defaultRecipe, userRecipe]), userRecipe)
    }
}
