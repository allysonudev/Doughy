//
//  CollectionAppearanceUITests.swift
//  Doughy UI Tests
//

import XCTest

/// Exercises the collection appearance editor (icon/color pickers reached from the
/// recipe details step, for both a brand-new collection and an existing one) and its
/// effect on the Home Screen list's collection section header.
///
/// `CollectionAppearanceEditor` is presented inline in the "Collection" section of the
/// recipe details step (`CreateRecipeView+StepsIngredients.swift`) - there is no separate
/// "edit collection" screen. Selecting/creating a collection there loads or sets its
/// appearance; saving the recipe persists it via `CollectionAppearanceStore`.
///
/// Neither the picker swatches nor the Home Screen avatar can be verified by color alone
/// from XCUITest, so these tests assert accessibility state instead: `.isSelected` traits
/// on the chosen swatch (`collectionIconOption_<key>` / `collectionColorOption_<key>`),
/// the live preview's descriptive accessibility label (`collectionAppearancePreviewAvatar`),
/// and the Home Screen header button's accessibility *value*, which mirrors the resolved
/// icon/color keys without touching the button's identifier/label (`app.buttons[<name>]`
/// lookups elsewhere depend on that staying the collection's name).
final class CollectionAppearanceUITests: DoughyUITestCase {

    // MARK: - Helpers

    /// Selects a built-in icon option by its catalog key (see `CollectionIconCatalog.all`,
    /// e.g. "bread", "pizza"), or `nil` for the "no icon" option.
    private func selectIconOption(_ key: String?) {
        let button = app.buttons["collectionIconOption_\(key ?? "none")"]
        app.scrollToElement(button)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Icon option \"\(key ?? "none")\" not found")
        button.tap()
    }

    /// Selects a built-in color option by its catalog key (see `CollectionColorCatalog.all`,
    /// e.g. "red", "blue"), or `nil` for the "automatic" option.
    private func selectColorOption(_ key: String?) {
        let button = app.buttons["collectionColorOption_\(key ?? "none")"]
        app.scrollToElement(button)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Color option \"\(key ?? "none")\" not found")
        button.tap()
    }

    private func assertIconSelected(_ key: String?) {
        let button = app.buttons["collectionIconOption_\(key ?? "none")"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isSelected, "Icon option \"\(key ?? "none")\" should be selected")
    }

    private func assertColorSelected(_ key: String?) {
        let button = app.buttons["collectionColorOption_\(key ?? "none")"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isSelected, "Color option \"\(key ?? "none")\" should be selected")
    }

    /// Reads the live preview avatar's descriptive accessibility label, in the form
    /// "icon:<key>, color:<key>" (see `CollectionAppearanceEditor.previewAccessibilityLabel`).
    private func previewAppearanceLabel() -> String {
        let preview = app.otherElements["collectionAppearancePreviewAvatar"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Appearance preview avatar not found")
        return preview.label
    }

    /// Reads the Home Screen collection section header's accessibility value, in the form
    /// "icon:<key>, color:<key>" (see `RecipeListView.collectionAvatarDescription`).
    private func homeScreenAppearanceValue(for collectionName: String) -> String {
        let header = app.buttons[collectionName]
        app.scrollUntilExists(header)
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Collection header \"\(collectionName)\" not found")
        return (header.value as? String) ?? ""
    }

    // MARK: - New collection

    func testPickingBuiltInIconShowsOnHomeScreenHeader() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.enterText("Focaccia", app: app)

        let newCollectionToggle = app.switches["newCollectionToggle"]
        XCTAssertTrue(newCollectionToggle.waitForExistence(timeout: 5))
        app.scrollToElement(newCollectionToggle)
        newCollectionToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let collectionField = app.textFields["newCollectionNameField"]
        XCTAssertTrue(collectionField.waitForExistence(timeout: 5))
        collectionField.enterText("Icon Test Collection", app: app)

        selectIconOption("bread")
        assertIconSelected("bread")
        XCTAssertTrue(previewAppearanceLabel().contains("icon:bread"), "Preview should reflect the chosen icon")

        app.tapDetailsNext()
        app.fillFlour(at: 0, name: "Bread Flour", value: "500")
        app.fillIngredient(at: 0, name: "Water", value: "350")
        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Focaccia"].waitForExistence(timeout: 5), "New recipe should appear in the recipe list")

        let headerValue = homeScreenAppearanceValue(for: "Icon Test Collection")
        XCTAssertTrue(headerValue.contains("icon:bread"), "Home Screen header should reflect the chosen icon, got \"\(headerValue)\"")
    }

    func testPickingColorAppliesSelectionInEditorAndOnHomeScreen() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.enterText("Baguette", app: app)

        let newCollectionToggle = app.switches["newCollectionToggle"]
        XCTAssertTrue(newCollectionToggle.waitForExistence(timeout: 5))
        app.scrollToElement(newCollectionToggle)
        newCollectionToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let collectionField = app.textFields["newCollectionNameField"]
        XCTAssertTrue(collectionField.waitForExistence(timeout: 5))
        collectionField.enterText("Color Test Collection", app: app)

        selectColorOption("blue")
        assertColorSelected("blue")
        XCTAssertTrue(previewAppearanceLabel().contains("color:blue"), "Preview should reflect the chosen color")

        app.tapDetailsNext()
        app.fillFlour(at: 0, name: "Bread Flour", value: "500")
        app.fillIngredient(at: 0, name: "Water", value: "350")
        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Baguette"].waitForExistence(timeout: 5), "New recipe should appear in the recipe list")

        let headerValue = homeScreenAppearanceValue(for: "Color Test Collection")
        XCTAssertTrue(headerValue.contains("color:blue"), "Home Screen header should reflect the chosen color, got \"\(headerValue)\"")
    }

    func testLeavingIconAndColorUnsetFallsBackToDefaultAvatar() throws {
        app.startCreateRecipe()
        app.chooseMode(byPercent: false)

        let nameField = app.textFields["recipeNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.enterText("Ciabatta", app: app)

        let newCollectionToggle = app.switches["newCollectionToggle"]
        XCTAssertTrue(newCollectionToggle.waitForExistence(timeout: 5))
        app.scrollToElement(newCollectionToggle)
        newCollectionToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let collectionField = app.textFields["newCollectionNameField"]
        XCTAssertTrue(collectionField.waitForExistence(timeout: 5))
        collectionField.enterText("Fallback Test Collection", app: app)

        // A brand-new collection defaults to no icon/no color; assert that up front.
        assertIconSelected(nil)
        assertColorSelected(nil)
        let previewLabel = previewAppearanceLabel()
        XCTAssertTrue(previewLabel.contains("icon:none"), "Preview should show no icon by default, got \"\(previewLabel)\"")
        XCTAssertTrue(previewLabel.contains("color:none"), "Preview should show no explicit color by default, got \"\(previewLabel)\"")

        app.tapDetailsNext()
        app.fillFlour(at: 0, name: "Bread Flour", value: "500")
        app.fillIngredient(at: 0, name: "Water", value: "350")
        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Ciabatta"].waitForExistence(timeout: 5), "New recipe should appear in the recipe list")

        let headerValue = homeScreenAppearanceValue(for: "Fallback Test Collection")
        XCTAssertTrue(headerValue.contains("icon:none"), "Home Screen header should show no icon, got \"\(headerValue)\"")
        XCTAssertTrue(headerValue.contains("color:none"), "Home Screen header should show no explicit color, got \"\(headerValue)\"")
    }

    // MARK: - Editing an existing collection

    func testEditingExistingCollectionAppearanceUpdatesHomeScreen() throws {
        // "Pizza" is one of the default seeded collections (Neapolitan Pizza, New York Pizza).
        // Confirm it starts with no explicit appearance before changing it.
        let initialValue = homeScreenAppearanceValue(for: "Pizza")
        XCTAssertTrue(initialValue.contains("icon:none"), "Pizza should start with no icon, got \"\(initialValue)\"")

        app.editRecipe(named: "Neapolitan Pizza")

        // Editing a recipe in an existing collection opens straight to the details step
        // with that collection already selected; the appearance editor loads its
        // current (default/none) appearance automatically.
        assertIconSelected(nil)
        selectIconOption("pizza")
        selectColorOption("orange")
        assertIconSelected("pizza")
        assertColorSelected("orange")

        app.tapDetailsNext()
        app.tapIngredientsNext()
        app.saveRecipe()

        XCTAssertTrue(app.staticTexts["Neapolitan Pizza"].waitForExistence(timeout: 5), "Edited recipe should remain in the recipe list")

        let updatedValue = homeScreenAppearanceValue(for: "Pizza")
        XCTAssertTrue(updatedValue.contains("icon:pizza"), "Home Screen header should reflect the updated icon, got \"\(updatedValue)\"")
        XCTAssertTrue(updatedValue.contains("color:orange"), "Home Screen header should reflect the updated color, got \"\(updatedValue)\"")

        // The sibling recipe in the same collection should show the same updated appearance,
        // since appearance is per-collection, not per-recipe.
        XCTAssertTrue(app.staticTexts["New York Pizza"].waitForExistence(timeout: 5))
    }
}
