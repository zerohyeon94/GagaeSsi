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
        persistentContainer.loadPersistentStores { (desc, error) in
            if let error = error {
                fatalError("Core Data store failed: \(error)")
            }
        }
    }

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    // MARK: - Save
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Save failed: \(error)")
            }
        }
    }

    // MARK: - Create BudgetConfig
    func createBudgetConfig(salary: Int, payday: Date) {
        let config = NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig", into: context)
        config.setValue(NSDecimalNumber(value: salary), forKey: "salary")
        config.setValue(payday, forKey: "payday")
        saveContext()
    }

    // MARK: - Fetch BudgetConfig
    func fetchBudgetConfig() -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "BudgetConfig")
        request.fetchLimit = 1
        do {
            return try context.fetch(request).first
        } catch {
            print("❌ Fetch failed: \(error)")
            return nil
        }
    }

    // MARK: - Delete All BudgetConfig (for reset)
    func deleteAllBudgetConfig() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "BudgetConfig")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        do {
            try context.execute(deleteRequest)
            saveContext()
        } catch {
            print("❌ Delete failed: \(error)")
        }
    }
}

