//
//  WelcomeUITests.swift
//  Doughy UI Tests
//

import XCTest

/// Exercises the onboarding flow shown on a fresh install (`OnboardingView`) and
/// the "what's new" flow shown after an app update (`WhatsNewView`).
///
/// `RecipeListView.checkOnboarding()` normally decides between these two screens
/// by comparing the app's current version against `Settings.lastOnboardingVersionKey`
/// in `UserDefaults.standard` - real, persistent, on-device storage that isn't reset
/// between UI test runs. Rather than fight that persisted state (or uninstall the
/// app between tests), these tests use the `-ForceNewUserOnboarding` and
/// `-ForceWhatsNew` launch arguments, which `checkOnboarding()` now honors even when
/// `-UITesting` is also present (see `Doughy/Views/RecipeListView.swift`), so each
/// scenario is deterministic while still running against a fresh in-memory store.
final class WelcomeUITests: XCTestCase {

    private func launchApp(extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"] + extraArguments
        app.launch()
        return app
    }

    // MARK: - Fresh install

    func testFreshInstallShowsWelcomeScreenAndCanBeDismissed() throws {
        let app = launchApp(extraArguments: ["-ForceNewUserOnboarding"])

        // First onboarding slide.
        XCTAssertTrue(app.images["fork.knife"].waitForExistence(timeout: 5), "Onboarding welcome slide should be shown")

        let nextButton = app.buttons["onboardingNextButton"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5), "Onboarding next/get-started button not found")

        // Advance through every slide; the button's label changes to "Get Started"
        // on the last one and dismisses the flow.
        for _ in 0..<5 {
            nextButton.tap()
        }
        nextButton.tap()

        XCTAssertFalse(app.buttons["onboardingNextButton"].waitForExistence(timeout: 3), "Onboarding should be dismissed after Get Started")
        XCTAssertTrue(app.navigationBars.buttons["Settings"].waitForExistence(timeout: 5) || app.buttons["addRecipeButton"].waitForExistence(timeout: 5), "Recipe list should be visible after onboarding is dismissed")
    }

    func testFreshInstallWelcomeScreenCanBeDismissedViaCloseButton() throws {
        let app = launchApp(extraArguments: ["-ForceNewUserOnboarding"])

        let closeButton = app.buttons["onboardingCloseButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Onboarding close button not found")
        closeButton.tap()

        XCTAssertFalse(app.buttons["onboardingCloseButton"].waitForExistence(timeout: 3), "Onboarding should be dismissed after tapping close")
        XCTAssertTrue(app.buttons["addRecipeButton"].waitForExistence(timeout: 5), "Recipe list should be visible after onboarding is dismissed")
    }

    // MARK: - Update (What's New)

    func testSeededOldVersionShowsWhatsNewScreen() throws {
        let app = launchApp(extraArguments: ["-ForceWhatsNew"])

        XCTAssertTrue(app.buttons["whatsNewGotItButton"].waitForExistence(timeout: 5), "What's New screen should be shown")

        app.buttons["whatsNewGotItButton"].tap()

        XCTAssertFalse(app.buttons["whatsNewGotItButton"].waitForExistence(timeout: 3), "What's New should be dismissed after tapping Got It")
        XCTAssertTrue(app.buttons["addRecipeButton"].waitForExistence(timeout: 5), "Recipe list should be visible after What's New is dismissed")
    }
}
