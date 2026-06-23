//
//  Settings.swift
//  Doughy
//
//  Created by urickg on 3/20/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

enum VolumeSystem: String {
    case metric
    case imperial
}

fileprivate let hasInitializedDefaultsKey = "hasInitializedDefaultsKey"
fileprivate let preferredTempKey = "preferredTempKey"

class Settings: NSObject {

    static let preferredLanguageKey = "doughy.preferredLanguage"
    static let preferredVolumeSystemKey = "doughy.preferredVolumeSystem"

    private let recipeConverter = RecipeConverter.shared
    private let recipeReader = RecipeReader.shared
    private let recipeWriter = RecipeWriter.shared
    private let defaultRecipeFactory = DefaultRecipeFactory.shared
    private let userDefaults = UserDefaults.standard
    private let coreDataGateway = CoreDataGateway.shared
    
    lazy var recipes = self.refreshRecipes()
    
    static let shared = Settings()
    
    private override init() {
        super.init()
        
        self.initializeDefaultRecipes()
    }
    
    func refreshRecipes() -> [RecipeCollection] {
        let recipes = recipeReader.getRecipes().map {
            recipeConverter.convertToExternal(recipe: $0)
        }
        var collectionsMap = [String : RecipeCollection]()
        for recipe in recipes {
            if let collection = collectionsMap[recipe.collection] {
                collection.recipes.append(recipe)
            }
            else {
                let newCollection = RecipeCollection(name: recipe.collection)
                newCollection.recipes.append(recipe)
                collectionsMap[recipe.collection] = newCollection
            }
        }
        let collections = collectionsMap.values.sorted { (a, b) -> Bool in
            return a.name < b.name
        }
        return collections
    }
}

extension Settings {
    
    func initializeDefaultRecipes() {
        // UI tests run against a fresh in-memory store every launch, so always
        // re-seed the default recipes without touching the persisted flag below.
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")

        if isUITesting || !userDefaults.bool(forKey: hasInitializedDefaultsKey) {
            let isUS = Locale.current.region?.identifier == "US"
            setPreferredTemp(measurement: isUS ? .fahrenheit : .celsius)

            defaultRecipeFactory.createWithKeys().forEach { item in
                do {
                    try recipeWriter.writeDefaultRecipe(recipe: item.recipe, key: item.key)
                } catch {
                    print("Failed to write default recipe: \(error)")
                }
            }
            if !isUITesting {
                userDefaults.set(true, forKey: hasInitializedDefaultsKey)
            }
        } else {
            backfillDefaultRecipeKeys()
            fixNeapolitanSpelling()
        }
    }

    private func fixNeapolitanSpelling() {
        let migrationKey = "hasFixedNeapolitanSpelling"
        guard !userDefaults.bool(forKey: migrationKey) else { return }
        for recipe in recipeReader.getRecipes() {
            guard recipe.name == "Neopolitan Pizza",
                  recipe.value(forKey: "defaultKey") as? String == DefaultRecipeFactory.Key.neopolitanPizza
            else { continue }
            recipe.name = "Neapolitan Pizza"
        }
        try? coreDataGateway.managedObjectConext.save()
        userDefaults.set(true, forKey: migrationKey)
    }

    private func backfillDefaultRecipeKeys() {
        let backfillKey = "hasBackfilledDefaultRecipeKeys"
        guard !userDefaults.bool(forKey: backfillKey) else { return }

        let keysByName = DefaultRecipeFactory.Key.byStoredName
        for recipe in recipeReader.getRecipes() {
            guard let name = recipe.name,
                  let key = keysByName[name],
                  recipe.value(forKey: "defaultKey") == nil,
                  recipe.historyEntries?.count == 0 else { continue }
            recipe.setValue(key, forKey: "defaultKey")
        }
        try? coreDataGateway.managedObjectConext.save()
        userDefaults.set(true, forKey: backfillKey)
    }
    
}

extension Settings {
    /// Returns the BCP 47 language code the user has pinned in-app (e.g. "is", "de"),
    /// or nil if the app should follow the system language.
    func preferredLanguageCode() -> String? {
        userDefaults.string(forKey: Settings.preferredLanguageKey)
    }

    /// Persists `code` as the in-app language override and updates AppleLanguages so
    /// the change takes effect on the next launch. Pass nil to revert to system default.
    func setPreferredLanguageCode(_ code: String?) {
        if let code = code {
            userDefaults.set(code, forKey: Settings.preferredLanguageKey)
            userDefaults.set([code, "en"], forKey: "AppleLanguages")
        } else {
            userDefaults.removeObject(forKey: Settings.preferredLanguageKey)
            userDefaults.removeObject(forKey: "AppleLanguages")
        }
    }
}

extension Settings {
    /// Returns the user's preferred volume measurement system, defaulting to metric
    /// outside the US and imperial inside the US if no explicit preference is saved.
    func preferredVolumeSystem() -> VolumeSystem {
        if let raw = userDefaults.string(forKey: Settings.preferredVolumeSystemKey),
           let system = VolumeSystem(rawValue: raw) {
            return system
        }
        return Locale.current.region?.identifier == "US" ? .imperial : .metric
    }

    func setPreferredVolumeSystem(_ system: VolumeSystem) {
        userDefaults.set(system.rawValue, forKey: Settings.preferredVolumeSystemKey)
    }
}

extension Settings {
    func preferredTemp() -> Temperature.Measurement {
        let prefersCelsius = userDefaults.bool(forKey: preferredTempKey)
        return prefersCelsius ? .celsius : .fahrenheit
    }
    
    func setPreferredTemp(measurement: Temperature.Measurement) {
        userDefaults.set(measurement == .celsius, forKey: preferredTempKey)
    }
    
    func updateRecipeTemps(original: Temperature.Measurement,
                           target: Temperature.Measurement) throws {
        let recipes = recipeReader.getRecipes()
        recipes
            .flatMap { $0.sortedIngredients }
            .forEach {
                if let currentTemp = $0.temperature {
                    let newTemp = TemperatureConverter.shared.convert(temperature: currentTemp.doubleValue, source: original, target: target)
                    $0.temperature = NSNumber(floatLiteral: newTemp)
                }
                
        }
        recipes
            .compactMap { $0.preferment?.sortedIngredients }
            .flatMap { $0 }
            .forEach {
                if let currentTemp = $0.temperature {
                    let newTemp = TemperatureConverter.shared.convert(temperature: currentTemp.doubleValue, source: original, target: target)
                    $0.temperature = NSNumber(floatLiteral: newTemp)
                }
        }
        try self.coreDataGateway.managedObjectConext.save()
    }
}

extension Settings {
    static let lastOnboardingVersionKey = "doughy.lastOnboardingVersion"

    /// Call this BEFORE `Settings.shared` is first accessed (i.e., before
    /// `RecipeStore()` in SceneDelegate) to detect a genuine first install.
    static func isFirstInstall() -> Bool {
        !UserDefaults.standard.bool(forKey: hasInitializedDefaultsKey)
    }
}
