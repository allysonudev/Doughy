//
//  CoreDataGateway.swift
//  Doughy

import UIKit
import CoreData

class CoreDataGateway: NSObject {

    static let shared = CoreDataGateway()

    private(set) var persistentContainer: NSPersistentContainer
    var managedObjectConext: NSManagedObjectContext

    private override init() {
        persistentContainer = CoreDataGateway.makeContainer()
        managedObjectConext = persistentContainer.viewContext
        super.init()
    }

    // Tries CloudKit first; falls back to a plain local store if CloudKit isn't
    // configured (no entitlements, simulator, etc.).
    private static func makeContainer() -> NSPersistentContainer {
        let cloudContainer = NSPersistentCloudKitContainer(name: "Doughy")
        if let desc = cloudContainer.persistentStoreDescriptions.first {
            desc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.org.georgie.Doughy"
            )
            desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            desc.setOption(true as NSNumber,
                           forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        var cloudError: Error?
        cloudContainer.loadPersistentStores { _, error in
            cloudError = error
            if error == nil {
                cloudContainer.viewContext.automaticallyMergesChangesFromParent = true
                cloudContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            }
        }

        if cloudError == nil {
            return cloudContainer
        }

        // CloudKit unavailable — use a local-only store so the app still works.
        print("CloudKit unavailable (\(cloudError!.localizedDescription)), falling back to local store")
        let localContainer = NSPersistentContainer(name: "Doughy")
        localContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load local CoreData store: \(error)")
            }
            localContainer.viewContext.automaticallyMergesChangesFromParent = true
            localContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
        return localContainer
    }
}
