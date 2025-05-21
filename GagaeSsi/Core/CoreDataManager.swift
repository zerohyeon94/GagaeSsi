//
//  CoreDataManager.swift
//  GagaeSsi
//
//  Created by 조영현 on 5/21/25.
//

import CoreData

final class CoreDataManager {
    static let shared = CoreDataManager()

        let persistentContainer: NSPersistentContainer

        private init() {
            persistentContainer = NSPersistentContainer(name: "GagaeSsi")
            persistentContainer.loadPersistentStores { (description, error) in
                if let error = error {
                    fatalError("CoreData load error: \(error)")
                }
            }
        }

        var context: NSManagedObjectContext {
            return persistentContainer.viewContext
        }

        func saveContext() {
            let context = persistentContainer.viewContext
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("CoreData save error: \(error.localizedDescription)")
                }
            }
        }
}
