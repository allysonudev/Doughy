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
    private let cloudStore: DoughyKeyValueStore? = NSUbiquitousKeyValueStore.default
    private let coreDataGateway = CoreDataGateway.shared

    struct BackupData: Codable, Equatable {
        let preferredLanguageCode: String?
        let preferredVolumeSystem: String?
        let prefersCelsius: Bool?

        var isEmpty: Bool {
            preferredLanguageCode == nil && preferredVolumeSystem == nil && prefersCelsius == nil
        }
    }
    
    lazy var recipes = self.refreshRecipes()
    
    static let shared = Settings()
    
    private override init() {
        super.init()

        self.hydrateUserPreferencesFromCloud()
        self.initializeDefaultRecipes()
    }
    
    func refreshRecipes() -> [RecipeCollection] {
        repairDefaultRecipes()

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
            if userDefaults.object(forKey: preferredTempKey) == nil {
                setPreferredTemp(measurement: isUS ? .fahrenheit : .celsius)
            }

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
        }
        repairDefaultRecipes()
    }

    private func repairDefaultRecipes() {
        backfillDefaultRecipeKeys()
        fixNeapolitanSpelling()
        fixBagelMaltSpelling()
        do {
            _ = try recipeWriter.removeDuplicateDefaultRecipes()
        } catch {
            print("Failed to remove duplicate default recipes: \(error)")
        }
    }

    private func fixBagelMaltSpelling() {
        let migrationKey = "hasFixedBagelMaltSpelling"
        guard !userDefaults.bool(forKey: migrationKey) else { return }
        let oldName = "Non-diastic Malt"
        let newName = "Non-Diastatic Malt"
        let bagelKeys: Set<String> = [
            DefaultRecipeFactory.Key.bagels,
            DefaultRecipeFactory.Key.bagelsWithPoolish,
        ]
        for recipe in recipeReader.getRecipes() {
            guard let key = recipe.value(forKey: "defaultKey") as? String,
                  bagelKeys.contains(key) else { continue }
            for ingredient in recipe.sortedIngredients where ingredient.name == oldName {
                ingredient.name = newName
            }
            for ingredient in recipe.preferment?.sortedIngredients ?? [] where ingredient.name == oldName {
                ingredient.name = newName
            }
        }
        try? coreDataGateway.managedObjectConext.save()
        userDefaults.set(true, forKey: migrationKey)
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

        let keysByName = DefaultRecipeFactory.Key.byStoredName
        var changed = false
        for recipe in recipeReader.getRecipes() {
            guard let name = recipe.name,
                  let key = keysByName[name],
                  recipe.value(forKey: "defaultKey") == nil,
                  recipe.historyEntries?.count == 0 else { continue }
            recipe.setValue(key, forKey: "defaultKey")
            changed = true
        }
        if changed {
            try? coreDataGateway.managedObjectConext.save()
        }
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
            cloudStore?.set(code, forKey: Settings.preferredLanguageKey)
            userDefaults.set([code, "en"], forKey: "AppleLanguages")
        } else {
            userDefaults.removeObject(forKey: Settings.preferredLanguageKey)
            cloudStore?.removeObject(forKey: Settings.preferredLanguageKey)
            userDefaults.removeObject(forKey: "AppleLanguages")
        }
        _ = cloudStore?.synchronize()
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
        cloudStore?.set(system.rawValue, forKey: Settings.preferredVolumeSystemKey)
        _ = cloudStore?.synchronize()
    }
}

extension Settings {
    func preferredTemp() -> Temperature.Measurement {
        let prefersCelsius = userDefaults.bool(forKey: preferredTempKey)
        return prefersCelsius ? .celsius : .fahrenheit
    }
    
    func setPreferredTemp(measurement: Temperature.Measurement) {
        userDefaults.set(measurement == .celsius, forKey: preferredTempKey)
        cloudStore?.set(measurement == .celsius, forKey: preferredTempKey)
        _ = cloudStore?.synchronize()
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
    func backupData() -> BackupData? {
        let data = BackupData(
            preferredLanguageCode: preferredLanguageCode(),
            preferredVolumeSystem: userDefaults.string(forKey: Settings.preferredVolumeSystemKey),
            prefersCelsius: userDefaults.object(forKey: preferredTempKey) as? Bool
        )
        return data.isEmpty ? nil : data
    }

    func restore(_ data: BackupData?) {
        guard let data else { return }
        setPreferredLanguageCode(data.preferredLanguageCode)
        if let raw = data.preferredVolumeSystem, let system = VolumeSystem(rawValue: raw) {
            setPreferredVolumeSystem(system)
        } else {
            userDefaults.removeObject(forKey: Settings.preferredVolumeSystemKey)
            cloudStore?.removeObject(forKey: Settings.preferredVolumeSystemKey)
        }
        if let prefersCelsius = data.prefersCelsius {
            setPreferredTemp(measurement: prefersCelsius ? .celsius : .fahrenheit)
        } else {
            userDefaults.removeObject(forKey: preferredTempKey)
            cloudStore?.removeObject(forKey: preferredTempKey)
        }
        _ = cloudStore?.synchronize()
    }

    private func hydrateUserPreferencesFromCloud() {
        _ = cloudStore?.synchronize()

        if userDefaults.object(forKey: Settings.preferredLanguageKey) == nil,
           let code = cloudStore?.string(forKey: Settings.preferredLanguageKey) {
            userDefaults.set(code, forKey: Settings.preferredLanguageKey)
            userDefaults.set([code, "en"], forKey: "AppleLanguages")
        }
        if userDefaults.object(forKey: Settings.preferredVolumeSystemKey) == nil,
           let raw = cloudStore?.string(forKey: Settings.preferredVolumeSystemKey) {
            userDefaults.set(raw, forKey: Settings.preferredVolumeSystemKey)
        }
        if userDefaults.object(forKey: preferredTempKey) == nil,
           let prefersCelsius = cloudStore?.object(forKey: preferredTempKey) as? Bool {
            userDefaults.set(prefersCelsius, forKey: preferredTempKey)
        }
        // Unlike the prefs above, a missing local value here doesn't mean "use a default" -
        // it's the difference between "never onboarded" and "onboarded before, but this
        // install's local storage was wiped" (e.g. an uninstall/reinstall). Recovering it
        // from iCloud lets a reinstall on the same account skip onboarding instead of
        // re-showing the full welcome flow to a returning user.
        if userDefaults.string(forKey: Settings.lastOnboardingVersionKey) == nil,
           let version = cloudStore?.string(forKey: Settings.lastOnboardingVersionKey) {
            userDefaults.set(version, forKey: Settings.lastOnboardingVersionKey)
        }

        if let code = userDefaults.string(forKey: Settings.preferredLanguageKey) {
            cloudStore?.set(code, forKey: Settings.preferredLanguageKey)
        }
        if let raw = userDefaults.string(forKey: Settings.preferredVolumeSystemKey) {
            cloudStore?.set(raw, forKey: Settings.preferredVolumeSystemKey)
        }
        if let prefersCelsius = userDefaults.object(forKey: preferredTempKey) as? Bool {
            cloudStore?.set(prefersCelsius, forKey: preferredTempKey)
        }
        if let version = userDefaults.string(forKey: Settings.lastOnboardingVersionKey) {
            cloudStore?.set(version, forKey: Settings.lastOnboardingVersionKey)
        }
        _ = cloudStore?.synchronize()
    }
}

extension Settings {
    static let lastOnboardingVersionKey = "doughy.lastOnboardingVersion"

    /// Call this BEFORE `Settings.shared` is first accessed (i.e., before
    /// `RecipeStore()` in SceneDelegate) to detect a genuine first install.
    static func isFirstInstall() -> Bool {
        !UserDefaults.standard.bool(forKey: hasInitializedDefaultsKey)
    }

    /// The app version the user last saw onboarding/what's-new for - hydrated from iCloud
    /// at init (see `hydrateUserPreferencesFromCloud`) so a reinstall on the same iCloud
    /// account is recognized as "seen before" rather than a brand new install.
    func setLastOnboardingVersion(_ version: String) {
        userDefaults.set(version, forKey: Settings.lastOnboardingVersionKey)
        cloudStore?.set(version, forKey: Settings.lastOnboardingVersionKey)
        _ = cloudStore?.synchronize()
    }
}
