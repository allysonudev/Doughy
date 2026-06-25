//
//  ScreenshotUITests.swift
//  Doughy UI Tests
//
//  Drives the app through its key screens to produce localized App Store
//  screenshots via `fastlane snapshot`. Runs against the same clean in-memory
//  store as the rest of the UI tests (`-UITesting`), which re-seeds the four
//  default recipes on every launch (see Settings.initializeDefaultRecipes) — so
//  there's curated, already-localized demo data to capture without building a
//  recipe by hand. The recipe list is opened by accessibility identifier; the
//  Neapolitan recipe is opened by its localized name for the current snapshot
//  language (the seeded names are localized via `default_recipe_neopolitan_pizza`).
//
//  fastlane's `setupSnapshot`/`snapshot` are @MainActor-isolated; UI tests run on
//  the main thread, so we call them via MainActor.assumeIsolated to satisfy the
//  Swift 6 concurrency checker without changing the XCTestCase method isolation.
//

import XCTest

final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    /// Localized display name of the seeded "Neapolitan Pizza", keyed by snapshot
    /// language (`Snapshot.deviceLanguage`). Source of truth is Localizable.strings
    /// (key `default_recipe_neopolitan_pizza`) — keep in sync if a translation changes.
    /// A miss here isn't fatal: `openNeapolitanPizza()` falls back to the first recipe.
    private static let neapolitanPizzaByLanguage: [String: String] = [
        "ar-SA": "نابولي بيتزا",
        "da": "Napolitansk pizza",
        "de-DE": "Neapolitanische Pizza",
        "en-CA": "Neapolitan Pizza",
        "en-GB": "Neapolitan Pizza",
        "en-US": "Neapolitan Pizza",
        "es-ES": "Pizza Napolitana",
        "fr-FR": "Pizza Napolitaine",
        "hi": "नेपोलिटन पिज़्ज़ा",
        "is": "Napólísk pizza",
        "it": "Pizza Napoletana",
        "ja": "ナポリ風ピザ",
        "ko": "나폴리 피자",
        "nb": "Napolitansk pizza",
        "pt-BR": "Pizza Napolitana",
        "sv": "Napolitansk pizza",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Append, don't assign: setupSnapshot() also appends the per-run locale
        // launch arguments, and reassigning launchArguments would wipe them.
        app.launchArguments += ["-UITesting"]
        MainActor.assumeIsolated { setupSnapshot(app) }
        app.launch()
        // iPad simulators can be slow to go idle after a cold launch; tapping before
        // then throws "kAXErrorIPCTimeout / Failed to get list of active applications"
        // on the first interaction. Wait for the recipe list, then let SwiftUI settle
        // before any test taps. (testCreateRecipe runs first and gets the coldest launch.)
        XCTAssertTrue(app.buttons["addRecipeButton"].waitForExistence(timeout: 60),
                      "App did not reach the recipe list after launch")
        app.waitForUITransition(timeout: 1.5)
    }

    private func capture(_ name: String) {
        MainActor.assumeIsolated { snapshot(name) }
    }

    /// Opens "Neapolitan Pizza" by its localized name for the current snapshot
    /// language. Recipe names are localized, so we look up the expected string for
    /// `Snapshot.deviceLanguage` (set by setupSnapshot). Falls back to the first
    /// recipe row if the language isn't mapped or the row never appears, so the run
    /// degrades gracefully instead of hanging.
    private func openNeapolitanPizza() {
        let language = MainActor.assumeIsolated { Snapshot.deviceLanguage }
        if let localizedName = Self.neapolitanPizzaByLanguage[language] {
            let row = app.staticTexts[localizedName]
            if row.waitForExistence(timeout: 15) {
                row.tap()
                return
            }
        }
        // Fallback: first recipe row. Rows are List cells; section headers are
        // buttons, so the first cell is a recipe.
        let firstRecipe = app.cells.firstMatch
        XCTAssertTrue(firstRecipe.waitForExistence(timeout: 15),
                      "No recipe rows found (language=\(language))")
        firstRecipe.tap()
    }

    /// Recipe list → calculator input → calculated results (the hero shot).
    func testListCalculatorAndResults() throws {
        // The list is up once its toolbar add-button exists (stable accessibility ID).
        XCTAssertTrue(app.buttons["addRecipeButton"].waitForExistence(timeout: 15),
                      "Recipe list did not appear")
        capture("01_RecipeList")

        openNeapolitanPizza()
        XCTAssertTrue(app.buttons["calculateButton"].waitForExistence(timeout: 15),
                      "Calculator screen did not appear")
        capture("02_Calculator")

        app.tapCalculate()
        XCTAssertTrue(app.staticTexts["doughTotalWeight"].waitForExistence(timeout: 15),
                      "Results screen did not appear")
        capture("03_Result")
    }

    /// The "create a recipe" entry point (mode selection).
    func testCreateRecipe() throws {
        app.startCreateRecipe()
        XCTAssertTrue(app.buttons["byPercentModeCard"].waitForExistence(timeout: 15),
                      "Create-recipe mode selection did not appear")
        capture("04_CreateRecipe")
    }
}
