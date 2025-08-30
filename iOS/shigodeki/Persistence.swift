//
//  Persistence.swift
//  shigodeki
//
//  Created by Hiroshi Kodera on 2025-08-27.
//

import CoreData
import os.log

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Graceful error handling for preview context
            let nsError = error as NSError
            let logger = Logger(subsystem: "com.hiroshikodera.shigodeki", category: "CoreData")
            logger.error("Preview context save failed: \(nsError.localizedDescription, privacy: .public)")
            // Preview context failure should not crash the app
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "shigodeki")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Graceful error handling for persistent store loading
                let logger = Logger(subsystem: "com.hiroshikodera.shigodeki", category: "CoreData")
                logger.error("Persistent store loading failed: \(error.localizedDescription, privacy: .public)")
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 
                 Recovery strategies:
                 1. Attempt to recreate the store
                 2. Use in-memory store as fallback
                 3. Notify user and provide options
                 */
                
                // Attempt recovery by switching to in-memory store
                self.switchToInMemoryStore()
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Recovery Methods
    private func switchToInMemoryStore() {
        let logger = Logger(subsystem: "com.hiroshikodera.shigodeki", category: "CoreData")
        logger.info("Switching to in-memory store as recovery mechanism")
        
        // Clear existing persistent store descriptions
        container.persistentStoreDescriptions.removeAll()
        
        // Configure in-memory store
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions.append(description)
        
        // Reload with in-memory configuration
        container.loadPersistentStores { _, error in
            if let error = error {
                logger.error("In-memory store fallback failed: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("Successfully switched to in-memory store")
            }
        }
    }
}
