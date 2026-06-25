//
//  RecipeReader.swift
//  Doughy
//
//  Created by urickg on 3/21/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit
import CoreData

class RecipeReader: NSObject {
    
    private let coreDataGateway = CoreDataGateway.shared
    
    static let shared = RecipeReader()
    
    private override init() { }
    
    func getRecipes() -> [XCRecipe] {
        let fetchRequest = NSFetchRequest<XCRecipe>(entityName: "XCRecipe")
        
        do {
            return try self.coreDataGateway.managedObjectConext.fetch(fetchRequest)
        }
        catch {
            print("No recipe collections")
        }
        return []
    }
    
    func getRecipe(collection: String, name: String) -> XCRecipe? {
        return RecipeReader.match(name: name, in: getRecipes(collection: collection))
    }

    /// Finds the stored recipe matching `name` among `candidates`. Callers pass a
    /// recipe's *display* name, which for a built-in recipe is localized while the
    /// stored name stays canonical — so an exact stored-name match is tried first
    /// (user recipes, English, unmodified defaults), then a fallback that resolves
    /// each default's localized display name the same way it's presented.
    static func match(name: String, in candidates: [XCRecipe]) -> XCRecipe? {
        if let exact = candidates.first(where: { $0.name == name }) {
            return exact
        }
        return candidates.first { xc in
            guard let key = xc.value(forKey: "defaultKey") as? String else { return false }
            return DefaultLocalization.recipeDisplayName(storedName: xc.name ?? "", defaultKey: key) == name
        }
    }
    
    func getRecipes(collection: String) -> [XCRecipe] {
        let fetchRequest = NSFetchRequest<XCRecipe>(entityName: "XCRecipe")
        fetchRequest.predicate = NSPredicate(format: "collection == %@", collection)

        do {
            return try self.coreDataGateway.managedObjectConext.fetch(fetchRequest)
        }
        catch {
            print("No recipe collection with name \(collection)")
        }
        return []
    }

    func getHistoryEntries(for recipe: XCRecipe) -> [XCHistoryEntry] {
        let entries = recipe.historyEntries?.allObjects as? [XCHistoryEntry] ?? []
        return entries.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

}
