//
//  ScreenshotUITests.swift
//  Doughy UI Tests
//
//  Drives the app through its key screens to produce localized App Store
//  screenshots via `fastlane snapshot`. Runs against the same clean in-memory
//  store as the rest of the UI tests (`-UITesting`), which re-seeds the four
//  default recipes on every launch (see Settings.initializeDefaultRecipes) — so
//  there's curated, already-localized demo data to capture without building a
//  recipe by hand. Navigation goes through accessibility identifiers, so it's
//  locale-independent; only the seeded recipe name (stored in English) is matched
//  literally.
//
//  fastlane's `setupSnapshot`/`snapshot` are @MainActor-isolated; UI tests run on
//  the main thread, so we call them via MainActor.assumeIsolated to satisfy the
//  Swift 6 concurrency checker without changing the XCTestCase method isolation.
//

import XCTest

final class ScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Append, don't assign: setupSnapshot() also appends the per-run locale
        // launch arguments, and reassigning launchArguments would wipe them.
        app.launchArguments += ["-UITesting"]
        MainActor.assumeIsolated { setupSnapshot(app) }
        app.launch()
    }

    private func capture(_ name: String) {
        MainActor.assumeIsolated { snapshot(name) }
    }

    /// Recipe list → calculator input → calculated results (the hero shot).
    func testListCalculatorAndResults() throws {
        XCTAssertTrue(app.staticTexts["Neopolitan Pizza"].waitForExistence(timeout: 15),
                      "Seeded recipe list did not appear")
        capture("01_RecipeList")

        app.openCalculator(for: "Neopolitan Pizza")
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
