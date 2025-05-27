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
    
    // SetupModel 내
    func save(budgetModel: BudgetConfigModel) {
        let context = self.context

        let config = NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig", into: context)
        config.setValue(NSDecimalNumber(value: budgetModel.salary), forKey: "salary")
        config.setValue(budgetModel.payday, forKey: "payday")

        for fixed in budgetModel.fixedCosts {
            let fixedCost = NSEntityDescription.insertNewObject(forEntityName: "FixedCost", into: context)
            fixedCost.setValue(fixed.title, forKey: "title")
            fixedCost.setValue(NSDecimalNumber(value: fixed.amount), forKey: "amount")
            fixedCost.setValue(config, forKey: "config")
        }

        saveContext()
    }

    func fetchBudgetModel() -> BudgetConfigModel? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "BudgetConfig")
        request.fetchLimit = 1

        guard let config = try? context.fetch(request).first else { return nil }

        let salary = (config.value(forKey: "salary") as? NSDecimalNumber)?.intValue ?? 0
        let payday = config.value(forKey: "payday") as? Date ?? Date()

        let fixedSet = config.value(forKey: "fixedCosts") as? Set<NSManagedObject> ?? []
        let fixedModels: [FixedCostModel] = fixedSet.compactMap {
            let title = $0.value(forKey: "title") as? String ?? ""
            let amount = ($0.value(forKey: "amount") as? NSDecimalNumber)?.intValue ?? 0
            return FixedCostModel(title: title, amount: amount)
        }

        return BudgetConfigModel(salary: salary, payday: payday, fixedCosts: fixedModels)
    }
    
    // MARK: Spend
    func saveSpending(title: String, amount: Int, date: Date) {
        let context = self.context
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        
        print("day : \(day)")
        print("date : \(date)")

        // 1. DailyBudget 가져오기 or 생성
        let request: NSFetchRequest<DailyBudget> = DailyBudget.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", day as NSDate) // 해당 날짜의 예산 데이터 가져오기

        let dailyBudget = (try? context.fetch(request).first) ?? DailyBudget(context: context)
        dailyBudget.date = day

        // 2. SpendingRecord 생성
        let record = SpendingRecord(context: context)
        record.title = title
        record.amount = NSDecimalNumber(value: amount)
        record.date = date
        record.dailyBudget = dailyBudget
        dailyBudget.addToSpendingRecords(record)

        // 3. spentAmount 갱신 - 사용한 금액 갱신
        let records = dailyBudget.spendingRecords as? Set<SpendingRecord> ?? []
        let total = records
            .compactMap { $0.amount?.intValue }
            .reduce(0, +)
        
        dailyBudget.spentAmount = NSDecimalNumber(value: total)

        saveContext()
    }
    
    func fetchSpending(on date: Date) -> [SpendingRecord] {
        let context = self.context
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<SpendingRecord> = SpendingRecord.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            print("❌ 지출 내역 가져오기 실패:", error)
            return []
        }
    }
}

