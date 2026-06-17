//
//  ScanRecipeIntent.swift
//  Doughy

import AppIntents
import UIKit

// MARK: - Intent

struct ScanRecipeIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Recipe"
    static var description = IntentDescription(
        "Scan a recipe photo and import it into Doughy. Apple Intelligence will read the text and extract ingredients automatically.",
        categoryName: "Recipe"
    )
    static let openAppWhenRun = true

    @Parameter(title: "Recipe Photo",
               description: "A photo of the recipe to import into Doughy")
    var photo: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let image = UIImage(data: photo.data) else {
            throw ScanIntentError.invalidImage
        }
        NotificationCenter.default.post(name: .doughyScanFromIntent, object: image)
        return .result()
    }
}

// MARK: - Error

enum ScanIntentError: Error, CustomLocalizedStringResourceConvertible {
    case invalidImage

    var localizedStringResource: LocalizedStringResource {
        "Could not read the photo. Please try again with a clearer image."
    }
}

// MARK: - App Shortcuts (Siri phrase discovery)

struct DoughyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanRecipeIntent(),
            phrases: [
                "Scan recipe in \(.applicationName)",
                "Add recipe photo to \(.applicationName)",
                "Send this recipe to \(.applicationName)",
                "Import recipe into \(.applicationName)",
            ],
            shortTitle: "Scan Recipe",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: ShareRecipeIntent(),
            phrases: [
                "Share a recipe in \(.applicationName)",
                "Share \(\.$recipe) in \(.applicationName)",
                "Export \(\.$recipe) from \(.applicationName)",
            ],
            shortTitle: "Share Recipe",
            systemImageName: "square.and.arrow.up"
        )
        AppShortcut(
            intent: OpenRecipeIntent(),
            phrases: [
                "Open a recipe in \(.applicationName)",
                "Open \(\.$recipe) in \(.applicationName)",
            ],
            shortTitle: "Open Recipe",
            systemImageName: "book"
        )
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let doughyScanFromIntent = Notification.Name("DoughyScanFromIntent")
}
