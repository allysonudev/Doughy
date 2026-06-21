//
//  SceneDelegate.swift
//  Doughy

import UIKit
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

enum DoughyShortcut {
    static let scanRecipe = "org.georgie.Doughy.scanRecipe"
    static let openRecipe = "org.georgie.Doughy.openRecipe"
    static let collectionUserInfoKey = "collection"
    static let nameUserInfoKey = "name"
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var store: RecipeStore?
    private var intentScanObserver: NSObjectProtocol?
    private var intentShareObserver: NSObjectProtocol?
    private var intentOpenObserver: NSObjectProtocol?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Must be checked before RecipeStore() triggers Settings.shared init,
        // which sets hasInitializedDefaultsKey and would mask a true first install.
        let isNewInstall = Settings.isFirstInstall()
        let store = RecipeStore(isNewInstall: isNewInstall)
        self.store = store
        intentScanObserver = NotificationCenter.default.addObserver(
            forName: .doughyScanFromIntent, object: nil, queue: .main
        ) { [weak store] notification in
            store?.pendingIntentImage = notification.object as? UIImage
        }
        intentShareObserver = NotificationCenter.default.addObserver(
            forName: .doughyShareFromIntent, object: nil, queue: .main
        ) { [weak store] notification in
            store?.pendingShareIntent = notification.object as? PendingShareRequest
        }
        intentOpenObserver = NotificationCenter.default.addObserver(
            forName: .doughyOpenRecipeFromIntent, object: nil, queue: .main
        ) { [weak store] notification in
            store?.pendingOpenIntent = notification.object as? PendingOpenRecipeRequest
        }
        let rootView = RecipeListView().environment(store)
        let hostingController = UIHostingController(rootView: rootView)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = hostingController
        self.window = window
        window.makeKeyAndVisible()

        // Handle a .doughy file that launched the app cold.
        if let url = connectionOptions.urlContexts.first?.url {
            handleIncomingFile(url: url)
        }

        registerScanShortcutIfSupported()

        if let shortcutItem = connectionOptions.shortcutItem {
            _ = handleShortcutItem(shortcutItem)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncomingFile(url: url)
    }

    // Registers the "Scan a Recipe" home-screen quick action only on devices where
    // Apple Intelligence can run. Hardware that can never run it (deviceNotEligible)
    // won't see the shortcut at all; devices where AI is simply not yet enabled or
    // still downloading still get it so the feature remains discoverable.
    private func registerScanShortcutIfSupported() {
        #if canImport(FoundationModels)
        guard #available(iOS 26, *) else { return }
        if case .unavailable(let reason) = SystemLanguageModel.default.availability,
           case .deviceNotEligible = reason { return }
        let item = UIApplicationShortcutItem(
            type: DoughyShortcut.scanRecipe,
            localizedTitle: "Scan a Recipe",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(type: .capturePhoto),
            userInfo: nil
        )
        UIApplication.shared.shortcutItems = [item]
        #endif
    }

    private func handleIncomingFile(url: URL) {
        guard url.pathExtension.lowercased() == RecipeFile.fileExtension,
              let payload = RecipeFile.load(from: url) else { return }
        store?.pendingImport = payload
    }

    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handleShortcutItem(shortcutItem))
    }

    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        switch shortcutItem.type {
        case DoughyShortcut.scanRecipe:
            store?.pendingScanShortcut = true
            return true
        case DoughyShortcut.openRecipe:
            guard let collection = shortcutItem.stringUserInfoValue(for: DoughyShortcut.collectionUserInfoKey),
                  let name = shortcutItem.stringUserInfoValue(for: DoughyShortcut.nameUserInfoKey) else {
                return false
            }
            store?.pendingOpenIntent = PendingOpenRecipeRequest(recipeName: name, collection: collection)
            return true
        default:
            return false
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) { }
    func sceneDidBecomeActive(_ scene: UIScene) { }
    func sceneWillResignActive(_ scene: UIScene) { }
    func sceneWillEnterForeground(_ scene: UIScene) { }
    func sceneDidEnterBackground(_ scene: UIScene) { }
}

private extension UIApplicationShortcutItem {
    func stringUserInfoValue(for key: String) -> String? {
        if let value = userInfo?[key] as? String {
            return value
        }
        if let value = userInfo?[key] as? NSString {
            return value as String
        }
        return nil
    }
}
