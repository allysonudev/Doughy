//
//  ObjectFactory.swift
//  Doughy
//
//  Created by urickg on 3/21/20.
//  Copyright © 2020 George Urick. All rights reserved.
//

import UIKit
import CoreData

class ObjectFactory: NSObject {
    
    private let coreDataGateway = CoreDataGateway.shared
    
    static let shared = ObjectFactory()
    
    private override init() { }
    
    func createRecipe() -> XCRecipe {
        let entity = NSEntityDescription.entity(forEntityName: "XCRecipe", in: self.coreDataGateway.managedObjectConext)
        return NSManagedObject(entity: entity!, insertInto: self.coreDataGateway.managedObjectConext) as! XCRecipe
    }
    
    func createPreferment() -> XCPreferment {
        let entity = NSEntityDescription.entity(forEntityName: "XCPreferment", in: self.coreDataGateway.managedObjectConext)
        return NSManagedObject(entity: entity!, insertInto: self.coreDataGateway.managedObjectConext) as! XCPreferment
    }
    
    func createIngredient() -> XCIngredient {
        let entity = NSEntityDescription.entity(forEntityName: "XCIngredient", in: self.coreDataGateway.managedObjectConext)
        return NSManagedObject(entity: entity!, insertInto: self.coreDataGateway.managedObjectConext) as! XCIngredient
    }
    
    func createCalculatedRecipe() -> XCCalculatedRecipe {
        let entity = NSEntityDescription.entity(forEntityName: "XCCalculatedRecipe", in: self.coreDataGateway.managedObjectConext)
        return NSManagedObject(entity: entity!, insertInto: self.coreDataGateway.managedObjectConext) as! XCCalculatedRecipe
    }
    
    func createCalculatedPreferment() -> XCCalculatedPreferment {
        let entity = NSEntityDescription.entity(forEntityName: "XCCalculatedPreferment", in: self.coreDataGateway.managedObjectConext)
        return NSManagedObject(entity: entity!, insertInto: self.coreDataGateway.managedObjectConext) as! XCCalculatedPreferment
    }
    
    func createCalculatedIngredient() -> XCCalculatedIngredient {
        let entity = NSEntityDescription.entity(forEntityName: "XCCalculatedIngredient", in: self.coreDataGateway.managedObjectConext)
        return NSManagedObject(entity: entity!, insertInto: self.coreDataGateway.managedObjectConext) as! XCCalculatedIngredient
    }
    
    func createInstruction() -> XCInstruction {
        let entity = NSEntityDescription.entity(forEntityName: "XCInstruction", in: self.coreDataGateway.managedObjectConext)
        return NSManagedObject(entity: entity!, insertInto: self.coreDataGateway.managedObjectConext) as! XCInstruction
    }

    func createHistoryEntry() -> XCHistoryEntry {
        let entity = NSEntityDescription.entity(forEntityName: "XCHistoryEntry", in: self.coreDataGateway.managedObjectConext)
        return NSManagedObject(entity: entity!, insertInto: self.coreDataGateway.managedObjectConext) as! XCHistoryEntry
    }

}
