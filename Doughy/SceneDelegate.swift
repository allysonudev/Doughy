//
//  SceneDelegate.swift
//  Doughy

import UIKit
import SwiftUI

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

        let store = RecipeStore()
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

        if let shortcutItem = connectionOptions.shortcutItem {
            _ = handleShortcutItem(shortcutItem)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncomingFile(url: url)
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
