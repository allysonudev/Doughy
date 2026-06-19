//
//  AppDelegate.swift
//  Doughy
//
//  Created by urickg on 3/20/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    override init() {
        super.init()
        // Apply any in-app language override before the first bundle lookup.
        // AppleLanguages is read once at launch; changes take effect on next start.
        if let code = UserDefaults.standard.string(forKey: Settings.preferredLanguageKey) {
            UserDefaults.standard.set([code, "en"], forKey: "AppleLanguages")
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
