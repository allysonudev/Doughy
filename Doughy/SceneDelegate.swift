//
//  SceneDelegate.swift
//  Doughy

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var store: RecipeStore?
    private var intentScanObserver: NSObjectProtocol?
    private var intentShareObserver: NSObjectProtocol?

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

    func sceneDidDisconnect(_ scene: UIScene) { }
    func sceneDidBecomeActive(_ scene: UIScene) { }
    func sceneWillResignActive(_ scene: UIScene) { }
    func sceneWillEnterForeground(_ scene: UIScene) { }
    func sceneDidEnterBackground(_ scene: UIScene) { }
}
