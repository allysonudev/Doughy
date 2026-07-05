//
//  HomeScreenUITests.swift
//  Doughy UI Tests
//

import XCTest

/// Exercises the recipe list's delete (swipe + context menu) and share flows.
///
/// Every `-UITesting` launch starts from a fresh in-memory store seeded with four
/// default recipes across two collections: "Pizza" (Neapolitan Pizza, New York
/// Pizza) and "Bagels" (Bagels, Bagels With Poolish). See
/// `Doughy/Utilities/DefaultRecipeFactory.swift` / `Settings.initializeDefaultRecipes()`.
final class HomeScreenUITests: DoughyUITestCase {

    // MARK: - Helpers

    /// Swipes a recipe row left and taps "Delete".
    private func swipeDeleteRecipe(named name: String) {
        let cell = app.staticTexts[name]
        app.scrollUntilExists(cell)
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Recipe \"\(name)\" not found in list")
        app.scrollToElement(cell)
        cell.swipeLeft()
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete button not found after swiping \"\(name)\"")
        deleteButton.tap()
    }

    /// Long-presses a recipe row to reveal its context menu.
    private func openContextMenu(for name: String) -> XCUIElement {
        let cell = app.staticTexts[name]
        app.scrollUntilExists(cell)
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Recipe \"\(name)\" not found in list")
        app.scrollToElement(cell)
        cell.press(forDuration: 1.0)
        return cell
    }

    // MARK: - Swipe delete

    func testSwipeDeleteRemovesRecipeFromList() throws {
        swipeDeleteRecipe(named: "New York Pizza")
        app.waitForUITransition()
        XCTAssertFalse(app.staticTexts["New York Pizza"].exists, "Deleted recipe should no longer appear in the list")
        // Sibling recipe in the same collection should be untouched.
        XCTAssertTrue(app.staticTexts["Neapolitan Pizza"].waitForExistence(timeout: 5))
    }

    func testDeletingLastRecipeInCollectionRemovesCollectionSection() throws {
        // "Bagels" collection has two recipes; deleting both should make the
        // "Bagels" section header disappear entirely (collections are derived
        // dynamically from existing recipes, not persisted separately).
        swipeDeleteRecipe(named: "Bagels")
        app.waitForUITransition()
        swipeDeleteRecipe(named: "Bagels With Poolish")
        app.waitForUITransition()

        XCTAssertFalse(app.staticTexts["Bagels"].exists, "Bagels recipe should be gone")
        XCTAssertFalse(app.staticTexts["Bagels With Poolish"].exists, "Bagels With Poolish recipe should be gone")
        XCTAssertFalse(app.buttons["Bagels"].exists, "Bagels collection header should no longer be shown")

        // The other collection is untouched.
        XCTAssertTrue(app.staticTexts["Neapolitan Pizza"].waitForExistence(timeout: 5))
    }

    func testDeletingLastRecipeInLibraryShowsEmptyState() throws {
        swipeDeleteRecipe(named: "Neapolitan Pizza")
        app.waitForUITransition()
        swipeDeleteRecipe(named: "New York Pizza")
        app.waitForUITransition()
        swipeDeleteRecipe(named: "Bagels")
        app.waitForUITransition()
        swipeDeleteRecipe(named: "Bagels With Poolish")
        app.waitForUITransition()

        XCTAssertTrue(app.staticTexts["No Recipes"].waitForExistence(timeout: 5), "Expected the empty-library state")
    }

    // MARK: - Context (hold) menu

    func testContextMenuEditOpensEditor() throws {
        let cell = openContextMenu(for: "Neapolitan Pizza")
        let editButton = app.buttons["Edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit action not found in context menu")
        editButton.tap()

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Editor should open on the details step")
        XCTAssertEqual(nameField.value as? String, "Neapolitan Pizza")
        _ = cell // silence unused-variable warning if the row isn't referenced further
    }

    func testContextMenuDeleteRemovesRecipe() throws {
        _ = openContextMenu(for: "New York Pizza")
        let deleteButton = app.buttons["Delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Delete action not found in context menu")
        deleteButton.tap()
        app.waitForUITransition()

        XCTAssertFalse(app.staticTexts["New York Pizza"].exists, "Recipe deleted from the context menu should be gone")
    }

    func testContextMenuSharePresentsAndDismissesShareSheet() throws {
        _ = openContextMenu(for: "Bagels")
        let shareMenuAction = app.buttons["Share"]
        XCTAssertTrue(shareMenuAction.waitForExistence(timeout: 5), "Share action not found in context menu")
        shareMenuAction.tap()

        // Sharing a recipe opens Doughy's own RecipeShareView (a Form with author/note
        // fields and a toolbar "Cancel"/"Share" pair). Tapping its "Share" button drives
        // the real system UIActivityViewController immediately with no intermediate step,
        // so only assert it's present/hittable here and back out via "Cancel" - actually
        // invoking it can't be dismissed deterministically from XCUITest.
        let shareNavBarShareButton = app.navigationBars.buttons["Share"]
        XCTAssertTrue(shareNavBarShareButton.waitForExistence(timeout: 5), "Recipe share sheet's Share button should appear")
        XCTAssertTrue(shareNavBarShareButton.isHittable, "Share button should be hittable")

        let cancelButton = app.navigationBars.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "Recipe share sheet's Cancel button should appear")
        cancelButton.tap()
        app.waitForUITransition()

        // Back on the recipe list, the recipe itself should be untouched.
        XCTAssertTrue(app.staticTexts["Bagels"].waitForExistence(timeout: 5), "Sharing shouldn't delete or rename the recipe")
    }
}
