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
        let config = BudgetConfig(context: context) // NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig", into: context)
        config.setValue(NSDecimalNumber(value: salary), forKey: "salary")
        config.setValue(payday, forKey: "payday")
        saveContext()
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

        let config = BudgetConfig(context: context) // NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig", into: context) as! BudgetConfig
        config.setValue(NSDecimalNumber(value: budgetModel.salary), forKey: "salary")
        config.setValue(NSDecimalNumber(value: budgetModel.payday), forKey: "payday")

        for fixed in budgetModel.fixedCosts {
            let fixedCost = FixedCost(context: context)// NSEntityDescription.insertNewObject(forEntityName: "FixedCost", into: context) as! FixedCost
            fixedCost.setValue(fixed.title, forKey: "title")
            fixedCost.setValue(NSDecimalNumber(value: fixed.amount), forKey: "amount")
            
            // 관계 연결
            fixedCost.budgetConfig = config // ← FixedCost → BudgetConfig (To-One)
            config.addToFixedCosts(fixedCost) // ← BudgetConfig → FixedCost (To-Many)
        }

        saveContext()
    }

    func fetchBudgetModel() -> BudgetConfigModel? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "BudgetConfig")
        request.fetchLimit = 1

        guard let config = try? context.fetch(request).first else { return nil }

        let salary = (config.value(forKey: "salary") as? NSDecimalNumber)?.intValue ?? 0
        let payday = (config.value(forKey: "payday") as? NSDecimalNumber)?.intValue ?? 0

        let fixedSet = config.value(forKey: "fixedCosts") as? Set<NSManagedObject> ?? []
        let fixedModels: [FixedCostModel] = fixedSet.compactMap {
            let title = $0.value(forKey: "title") as? String ?? ""
            let amount = ($0.value(forKey: "amount") as? NSDecimalNumber)?.intValue ?? 0
            return FixedCostModel(title: title, amount: amount)
        }

        return BudgetConfigModel(salary: salary, payday: payday, fixedCosts: fixedModels)
    }
    
    // MARK: Home
    // 오늘 날짜에 데이터가 있는지 확인
    func ensureTodayDailyBudgetExists() -> DailyBudget {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let existing = fetchDailyBudget(on: today) {
            return existing
        }

        guard let config = fetchBudgetModel() else {
            // fallback
            return DailyBudget(context: context)
        }

        let baseAmount = calculateDailyBudget(from: config, for: today)

        let dailyBudget = DailyBudget(context: context)
        dailyBudget.date = today
        dailyBudget.availableAmount = NSDecimalNumber(value: baseAmount)
        dailyBudget.spentAmount = 0

        saveContext()
        return dailyBudget
    }
    
    func calculateDailyBudget(from config: BudgetConfigModel, for date: Date) -> Int {
        let fixedTotal = config.fixedCosts.map { $0.amount }.reduce(0, +)
        let usableSalary = config.salary - fixedTotal
        
        print("fixedTotal : \(fixedTotal)")
        print("usableSalary : \(usableSalary)")

        let periodStart = calculateCurrentPayPeriodStart(payday: config.payday, today: date)
        let periodEnd = Calendar.current.date(byAdding: .month, value: 1, to: periodStart)!
        let totalDays = Calendar.current.dateComponents([.day], from: periodStart, to: periodEnd).day!
        
        DebugLogger.printDate("date : ", date)
        DebugLogger.printDate("periodStart : ", periodStart)
        DebugLogger.printDate("periodEnd : ", periodEnd)

        return usableSalary / totalDays
    }
    
    func calculateCurrentPayPeriodStart(payday: Int, today: Date) -> Date {
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)

        guard let year = todayComponents.year, let month = todayComponents.month else {
            return today // fallback
        }

        // 이번 달의 월급일 날짜 구성
        let paydayThisMonth = calendar.date(from: DateComponents(year: year, month: month, day: payday))!

        if today >= paydayThisMonth {
            // 오늘이 이번 달 급여일 이후라면 → 이번 달 급여 시작
            return paydayThisMonth
        } else {
            // 오늘이 이번 달 급여일 이전이라면 → 지난 달 급여 시작
            let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: paydayThisMonth)!
            return previousMonthDate
        }
    }

    func fetchDailyBudget(on date: Date) -> DailyBudget? {
        let request: NSFetchRequest<DailyBudget> = DailyBudget.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: date)
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)

        return try? context.fetch(request).first
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
    
    // MARK: Setting View
    func resetAllData() {
        let entityNames = ["BudgetConfig", "FixedCost", "DailyBudget", "SpendingRecord", "CarryOverSource"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                }
            } catch {
                print("❌ Failed to reset \(entityName): \(error)")
            }
        }

        saveContext()
        print("✅ CoreData reset completed")
    }
    
    // MARK: - BudgetConfig Fetch
    func fetchBudgetConfig() -> BudgetConfigModel {
        let request: NSFetchRequest<BudgetConfig> = BudgetConfig.fetchRequest()

        do {
            if let config = try context.fetch(request).first {
                // 💡 FixedCost -> FixedCostModel로 변환
                let fixedCostEntities = config.fixedCosts?.allObjects as? [FixedCost] ?? []
                let fixedCostModels: [FixedCostModel] = fixedCostEntities.map {
                    FixedCostModel(title: $0.title ?? "", amount: Int($0.amount ?? 0))
                }

                return BudgetConfigModel(
                    salary: Int(config.salary ?? 0),
                    payday: Int(config.payday ?? 0),
                    fixedCosts: fixedCostModels
                )
            } else {
                // 초기값 없으면 새로 생성
                let newConfig = BudgetConfig(context: context)
                newConfig.salary = 3000000
                newConfig.payday = 25
                try context.save()

                return BudgetConfigModel(salary: 3000000, payday: 25, fixedCosts: [])
            }
        } catch {
            print("❌ BudgetConfig fetch 실패: \(error)")
            return BudgetConfigModel(salary: 0, payday: 1, fixedCosts: [])
        }
    }


    // MARK: - BudgetConfig Update
    func updateBudgetConfig(salary: Int, payday: Int) {
        let request: NSFetchRequest<BudgetConfig> = BudgetConfig.fetchRequest()

        do {
            if let config = try context.fetch(request).first {
                config.salary = NSDecimalNumber(value: salary)
                config.payday = NSDecimalNumber(value: payday)
                try context.save()
            }
        } catch {
            print("❌ BudgetConfig 저장 실패: \(error)")
        }
    }
}
