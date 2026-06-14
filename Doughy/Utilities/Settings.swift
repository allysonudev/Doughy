//
//  Settings.swift
//  Doughy
//
//  Created by urickg on 3/20/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit

fileprivate let hasInitializedDefaultsKey = "hasInitializedDefaultsKey"
fileprivate let preferredTempKey = "preferredTempKey"

class Settings: NSObject {
    
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
            setPreferredTemp(measurement: .fahrenheit)

            defaultRecipeFactory.create().forEach {
                do {
                    try recipeWriter.writeRecipe(recipe: $0)
                } catch {
                    print("Failed to write default recipe: \(error)")
                }
            }
            if !isUITesting {
                userDefaults.set(true, forKey: hasInitializedDefaultsKey)
            }
        }
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
            .flatMap { $0.ingredients!.array as! [XCIngredient] }
            .forEach {
                if let currentTemp = $0.temperature {
                    let newTemp = TemperatureConverter.shared.convert(temperature: currentTemp.doubleValue, source: original, target: target)
                    $0.temperature = NSNumber(floatLiteral: newTemp)
                }
                
        }
        recipes
            .compactMap { $0.preferment?.ingredients?.array as? [XCIngredient] }
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
