//
//  CoreDataManager.swift
//  GagaeSsi
//
//  CoreData 관리자 (SwiftUI 버전)
//  기존 UIKit 버전과 동일하게 동작
//

import CoreData

final class CoreDataManager {
    // MARK: - Singleton & Persistent Container
    static let shared = CoreDataManager()
    let persistentContainer: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        persistentContainer = NSPersistentContainer(name: "GagaeSsi")
        if inMemory {
            persistentContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        // lightweight migration 활성화
        if let desc = persistentContainer.persistentStoreDescriptions.first {
            desc.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            desc.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        persistentContainer.loadPersistentStores { (desc, error) in
            if let error = error {
                fatalError("Core Data store failed: \(error)")
            }
        }
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    // MARK: - Save
    @discardableResult
    func saveContext() -> Bool {
        if context.hasChanges {
            do {
                try context.save()
                return true
            } catch {
                DebugLogger.log("❌ Save failed: \(error)")
                return false
            }
        }
        return true
    }
    
    // MARK: - BudgetConfig CRUD
    func createBudgetConfig(from model: BudgetConfigModel) -> Bool {
        let config = BudgetConfig(context: context)
        config.salary = NSDecimalNumber(value: model.salary)
        config.payday = NSDecimalNumber(value: model.payday)
        config.carryOverMode = model.carryOverMode.rawValue
        config.debtPlanEnabled = model.debtPlanEnabled
        config.spendReminderEnabled = model.spendReminderEnabled
        config.spendReminderHour = Int16(model.spendReminderHour)
        config.spendReminderMinute = Int16(model.spendReminderMinute)

        for fixed in model.fixedCosts {
            let fixedCost = FixedCost(context: context)
            fixedCost.title = fixed.title
            fixedCost.amount = NSDecimalNumber(value: fixed.amount)
            fixedCost.budgetConfig = config
            config.addToFixedCosts(fixedCost)
        }

        return saveContext()
    }
    
    func fetchBudgetConfigEntity() -> BudgetConfig? {
        let request: NSFetchRequest<BudgetConfig> = BudgetConfig.fetchRequest()
        return try? context.fetch(request).first
    }

    func fetchBudgetConfig() -> BudgetConfigModel? {
        let request: NSFetchRequest<BudgetConfig> = BudgetConfig.fetchRequest()

        do {
            if let config = try context.fetch(request).first {
                return BudgetConfigModel(entity: config)
            } else {
                return nil
            }
        } catch {
            DebugLogger.log("❌ BudgetConfig fetch 실패: \(error)")
            return nil
        }
    }
    
    func updateBudgetConfig(_ model: BudgetConfigModel) -> Bool {
        guard let config = fetchBudgetConfigEntity() else {
            return false
        }
        
        config.salary = NSDecimalNumber(value: model.salary)
        config.payday = NSDecimalNumber(value: model.payday)
        config.carryOverMode = model.carryOverMode.rawValue
        config.debtPlanEnabled = model.debtPlanEnabled
        config.spendReminderEnabled = model.spendReminderEnabled
        config.spendReminderHour = Int16(model.spendReminderHour)
        config.spendReminderMinute = Int16(model.spendReminderMinute)

        return saveContext()
    }

    /// 이월 방식만 변경 (오늘부터 적용, 과거 일자·풀 잔액 보존)
    func updateCarryOverMode(_ mode: CarryOverMode) -> Bool {
        guard let config = fetchBudgetConfigEntity() else { return false }
        let previous = CarryOverMode.from(config.carryOverMode)
        config.carryOverMode = mode.rawValue

        // 전액 → 분리 전환은 오늘부터 반영: 오늘 넘어온 '양수 일자 이월'을 즉시 풀로 옮긴다.
        // (오늘 발생한 크레딧[이월금 인출·환급, date==today]과 음수 이월[페널티]은 제외)
        if mode == .separate && previous != .separate {
            sweepTodayPositiveCarryToPool()
        }
        return saveContext()
    }

    /// 오늘 DailyBudget에서 전날 넘어온 양수 이월을 '모아둔 이월금' 풀로 이동한다.
    private func sweepTodayPositiveCarryToPool() {
        let today = Calendar.current.startOfDay(for: Date())
        guard let budget = fetchDailyBudgetEntity(date: today) else { return }
        let sources = budget.carryOverSources?.allObjects as? [CarryOverSource] ?? []

        var swept = 0
        for s in sources {
            let srcDate = Calendar.current.startOfDay(for: s.date ?? today)
            let amount = Int(truncating: s.amount ?? 0)
            if srcDate < today && amount > 0 {   // 전날 이월(양수)만
                swept += amount
                budget.removeFromCarryOverSources(s)
                context.delete(s)
            }
        }
        if swept > 0 {
            let entry = CarryOverPoolEntry(context: context)
            entry.id = UUID()
            entry.date = today
            entry.amount = NSDecimalNumber(value: swept)
        }
    }

    // MARK: - FixedCost CRUD
    func createFixedCost(_ model: FixedCostModel) -> Bool {
        guard let budgetConfig = fetchBudgetConfigEntity() else { return false }

        let new = FixedCost(context: context)
        new.id = UUID()
        new.title = model.title
        new.amount = NSDecimalNumber(value: model.amount)
        new.isVariable = model.isVariable
        new.dueDay = Int16(model.dueDay)
        new.kind = model.kind.rawValue
        new.budgetConfig = budgetConfig
        budgetConfig.addToFixedCosts(new)

        return saveContext()
    }
    
    func fetchFixedCostEntity(id: UUID) -> FixedCost? {
        let request: NSFetchRequest<FixedCost> = FixedCost.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }
    
    func fetchFixedCosts() -> [FixedCostModel] {
        let request: NSFetchRequest<FixedCost> = FixedCost.fetchRequest()
        
        do {
            let results = try context.fetch(request)
            return results.map(FixedCostModel.init)
        } catch {
            DebugLogger.log("❌ 고정비 fetch 실패: \(error)")
            return []
        }
    }
    
    func updateFixedCost(_ model: FixedCostModel) -> Bool {
        guard let fixedCost = fetchFixedCostEntity(id: model.id) else {
            return false
        }

        fixedCost.title = model.title
        fixedCost.amount = NSDecimalNumber(value: model.amount)
        fixedCost.isVariable = model.isVariable
        fixedCost.dueDay = Int16(model.dueDay)
        fixedCost.kind = model.kind.rawValue

        return saveContext()
    }

    func deleteFixedCost(id: UUID) -> Bool {
        guard let fixedCost = fetchFixedCostEntity(id: id) else {
            return false
        }

        context.delete(fixedCost)   // monthlyEntries는 Cascade 규칙으로 함께 삭제
        return saveContext()
    }

    // MARK: - 변동 고정비 조회/알림

    /// 변동 고정비 목록
    func fetchVariableCosts() -> [FixedCostModel] {
        fetchFixedCosts().filter { $0.isVariable && $0.dueDay >= 1 }
    }

    /// 이번 달 기준 지출일이 지났는데 아직 확정 안 한 변동 고정비 (홈 프롬프트용)
    func unconfirmedVariableCosts(asOf date: Date = Date()) -> [FixedCostModel] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let today = comps.day else { return [] }
        let daysInMonth = calendar.range(of: .day, in: .month,
                                         for: calendar.date(from: DateComponents(year: year, month: month, day: 1))!)?.count ?? 30
        return fetchVariableCosts().filter { cost in
            let due = min(cost.dueDay, daysInMonth)
            return due <= today && fetchMonthlyEntry(fixedCostId: cost.id, year: year, month: month) == nil
        }
    }

    /// 변동 고정비 지출일 알림을 현재 상태로 재설정한다.
    func refreshVariableCostReminders(now: Date = Date()) {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: now)
        let year = comps.year ?? 0, month = comps.month ?? 0
        let costs = fetchVariableCosts()
        NotificationService.shared.refreshVariableCostReminders(
            costs: costs,
            isConfirmed: { [weak self] id in
                self?.fetchMonthlyEntry(fixedCostId: id, year: year, month: month) != nil
            },
            now: now)
    }

    // MARK: - 소비 기록 리마인더 알림

    /// 소비 기록 리마인더를 현재 설정 기준으로 재예약한다.
    /// 예약 대상 날짜는 CoreData 조회가 필요하므로 이 스레드에서 계산한 뒤 알림 서비스에 넘긴다.
    func refreshSpendReminders(now: Date = Date()) {
        guard let config = fetchBudgetConfig(), config.spendReminderEnabled else {
            NotificationService.shared.cancelAllSpendReminders()
            return
        }
        let fireDates = SpendReminderSchedule.pendingDates(
            from: now,
            hour: config.spendReminderHour,
            minute: config.spendReminderMinute,
            hasRecord: { [weak self] date in
                !(self?.fetchSpendingRecords(date: date).isEmpty ?? true)
            })
        NotificationService.shared.refreshSpendReminders(fireDates: fireDates)
    }

    /// 리마인더 설정 변경 (토글·시각) 후 알림을 즉시 재예약한다.
    @discardableResult
    func updateSpendReminder(enabled: Bool, hour: Int, minute: Int) -> Bool {
        guard let config = fetchBudgetConfigEntity() else { return false }
        config.spendReminderEnabled = enabled
        config.spendReminderHour = Int16(hour)
        config.spendReminderMinute = Int16(minute)
        guard saveContext() else { return false }
        refreshSpendReminders()
        return true
    }

    // MARK: - 변동 고정비 월별 확정 금액

    /// 특정 (변동 고정비, 연, 월)의 확정 엔트리를 조회한다 (없으면 nil = 미확정).
    func fetchMonthlyEntry(fixedCostId: UUID, year: Int, month: Int) -> MonthlyFixedCostEntryModel? {
        let request: NSFetchRequest<MonthlyFixedCostEntry> = MonthlyFixedCostEntry.fetchRequest()
        request.predicate = NSPredicate(format: "fixedCost.id == %@ AND year == %d AND month == %d",
                                        fixedCostId as CVarArg, Int16(year), Int16(month))
        request.fetchLimit = 1
        return (try? context.fetch(request).first).map(MonthlyFixedCostEntryModel.init)
    }

    /// 변동 고정비의 이번 달 확정 금액을 입력/수정한다.
    /// - 월별 엔트리를 upsert(이력 기록)하고,
    /// - FixedCost.amount(현재 예상액=확정액)를 갱신해 이후 일일 예산 배분에 반영한다.
    ///   과거 일자 예산은 불변, 오늘부터 `recalculateTodayBudget` 경로로 재계산된다.
    @discardableResult
    func confirmMonthlyAmount(fixedCostId: UUID, year: Int, month: Int, amount: Int) -> Bool {
        guard let fixedCost = fetchFixedCostEntity(id: fixedCostId) else { return false }

        // upsert
        let request: NSFetchRequest<MonthlyFixedCostEntry> = MonthlyFixedCostEntry.fetchRequest()
        request.predicate = NSPredicate(format: "fixedCost.id == %@ AND year == %d AND month == %d",
                                        fixedCostId as CVarArg, Int16(year), Int16(month))
        request.fetchLimit = 1
        let entry = (try? context.fetch(request).first) ?? {
            let e = MonthlyFixedCostEntry(context: context)
            e.id = UUID()
            e.year = Int16(year)
            e.month = Int16(month)
            e.fixedCost = fixedCost
            fixedCost.addToMonthlyEntries(e)
            return e
        }()

        entry.amount = NSDecimalNumber(value: amount)
        entry.confirmedAt = Date()

        // 배분에 반영: 현재 예상액을 확정액으로 갱신
        fixedCost.amount = NSDecimalNumber(value: amount)

        return saveContext()
    }

    // MARK: - 할부 CRUD

    func fetchInstallments() -> [InstallmentModel] {
        let request: NSFetchRequest<Installment> = Installment.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map(InstallmentModel.init)
    }

    private func fetchInstallmentEntity(id: UUID) -> Installment? {
        let request: NSFetchRequest<Installment> = Installment.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }

    func createInstallment(_ model: InstallmentModel) -> Bool {
        let new = Installment(context: context)
        new.id = model.id
        new.title = model.title
        new.totalAmount = NSDecimalNumber(value: model.totalAmount)
        new.months = Int16(model.months)
        new.startYear = Int16(model.startYear)
        new.startMonth = Int16(model.startMonth)
        new.createdAt = model.createdAt
        return saveContext()
    }

    func updateInstallment(_ model: InstallmentModel) -> Bool {
        guard let entity = fetchInstallmentEntity(id: model.id) else { return false }
        entity.title = model.title
        entity.totalAmount = NSDecimalNumber(value: model.totalAmount)
        entity.months = Int16(model.months)
        entity.startYear = Int16(model.startYear)
        entity.startMonth = Int16(model.startMonth)
        return saveContext()
    }

    func deleteInstallment(id: UUID) -> Bool {
        guard let entity = fetchInstallmentEntity(id: id) else { return false }
        context.delete(entity)
        return saveContext()
    }

    // MARK: - 페이백 CRUD (미확정·기간형)

    func fetchPaybacks() -> [PaybackModel] {
        let request: NSFetchRequest<Payback> = Payback.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return ((try? context.fetch(request)) ?? []).map(PaybackModel.init)
    }

    private func fetchPaybackEntity(id: UUID) -> Payback? {
        let request: NSFetchRequest<Payback> = Payback.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }

    func createPayback(_ model: PaybackModel) -> Bool {
        let e = Payback(context: context)
        applyPayback(model, to: e)
        e.createdAt = model.createdAt
        return saveContext()
    }

    func updatePayback(_ model: PaybackModel) -> Bool {
        guard let e = fetchPaybackEntity(id: model.id) else { return false }
        applyPayback(model, to: e)
        return saveContext()
    }

    private func applyPayback(_ m: PaybackModel, to e: Payback) {
        e.id = m.id
        e.title = m.title
        e.type = m.type.rawValue
        e.status = m.status.rawValue
        e.estimatedAmount = Int32(m.estimatedAmount)
        e.confirmedAmount = Int32(m.confirmedAmount)
        e.receivedAmount = Int32(m.receivedAmount)
        e.expectedDate = m.expectedDate
        e.receivedDate = m.receivedDate
        e.periodStart = m.periodStart
        e.periodEnd = m.periodEnd
    }

    func deletePayback(id: UUID) -> Bool {
        guard let e = fetchPaybackEntity(id: id) else { return false }
        context.delete(e)
        return saveContext()
    }

    /// 페이백 수령 처리 — 상태를 '수령'으로, 오늘 예산에 수령액을 +크레딧한다. 재수령 방지.
    @discardableResult
    func markPaybackReceived(id: UUID, amount: Int) -> Bool {
        guard amount > 0, let e = fetchPaybackEntity(id: id) else { return false }
        guard PaybackStatus.from(e.status) != .received else { return false }

        e.receivedAmount = Int32(amount)
        e.status = PaybackStatus.received.rawValue
        e.receivedDate = Date()

        let today = Calendar.current.startOfDay(for: Date())
        guard let budget = fetchOrCreateDailyBudgetEntity(date: today) else { return false }
        let credit = CarryOverSource(context: context)
        credit.id = UUID()
        credit.amount = NSDecimalNumber(value: amount)
        credit.date = today
        credit.toDate = today
        credit.dailyBudget = budget
        budget.addToCarryOverSources(credit)

        return saveContext()
    }

    // MARK: - DailyBudget CRUD
    func createDailyBudget(_ model: DailyBudgetModel) -> Bool {
        let dailyBudget = DailyBudget(context: context)
        dailyBudget.availableAmount = NSDecimalNumber(value: model.availableAmount)
        dailyBudget.date = model.date

        for source in model.carryOverSources {
            let carryOverSource = CarryOverSource(context: context)
            carryOverSource.amount = NSDecimalNumber(value: source.amount)
            carryOverSource.date = source.date
            carryOverSource.toDate = source.toDate
            
            carryOverSource.dailyBudget = dailyBudget
            dailyBudget.addToCarryOverSources(carryOverSource)
        }
        
        for record in model.spendingRecords {
            let spendingRecord = SpendingRecord(context: context)
            spendingRecord.title = record.title
            spendingRecord.amount = NSDecimalNumber(value: record.amount)
            spendingRecord.date = record.date
            
            spendingRecord.dailyBudget = dailyBudget
            dailyBudget.addToSpendingRecords(spendingRecord)
        }

        return saveContext()
    }
    
    func fetchDailyBudgetEntity(date: Date) -> DailyBudget? {
        let request: NSFetchRequest<DailyBudget> = DailyBudget.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: date)
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        return try? context.fetch(request).first
    }
    
    func fetchDailyBudgetModel(date: Date) -> DailyBudgetModel? {
        let request: NSFetchRequest<DailyBudget> = DailyBudget.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: date)
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)

        do {
            if let config = try context.fetch(request).first {
                return DailyBudgetModel(entity: config)
            } else {
                return nil
            }
        } catch {
            DebugLogger.log("❌ DailyBudget fetch 실패: \(error)")
            return nil
        }
    }
    
    func updateDailyBudget(_ model: DailyBudgetModel) -> Bool {
        guard let dailyBudget = fetchDailyBudgetEntity(date: model.date) else {
            return false
        }
        
        dailyBudget.availableAmount = NSDecimalNumber(value: model.availableAmount)
        dailyBudget.date = model.date
        
        return saveContext()
    }
    
    // MARK: - SpendingRecord CRUD
    func createSpendingRecord(_ model: SpendingRecordModel) -> Bool {
        guard let dailyBudget = fetchDailyBudgetEntity(date: model.date) else {
            return false
        }

        let newSpendingRecord = SpendingRecord(context: context)
        newSpendingRecord.id = model.id   // 모델 id 유지 (환급 받음 등 id 조회 일관성)
        newSpendingRecord.title = model.title
        newSpendingRecord.amount = NSDecimalNumber(value: model.amount)
        newSpendingRecord.date = model.date
        newSpendingRecord.category = model.category.rawValue
        newSpendingRecord.expectedPayback = Int32(model.expectedPayback)
        newSpendingRecord.paybackReceived = model.paybackReceived
        newSpendingRecord.dailyBudget = dailyBudget
        dailyBudget.addToSpendingRecords(newSpendingRecord)

        return saveContext()
    }
    
    func fetchSpendingRecordEntity(id: UUID) -> SpendingRecord? {
        let request: NSFetchRequest<SpendingRecord> = SpendingRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }
    
    /// 기존 소비 기록에서 파생한 항목 자동완성 추천
    func fetchSpendingSuggestions() -> [SpendingSuggestion] {
        let request: NSFetchRequest<SpendingRecord> = SpendingRecord.fetchRequest()
        let entities = (try? context.fetch(request)) ?? []
        return SpendingSuggestionEngine.build(from: entities.map(SpendingRecordModel.init))
    }

    func fetchSpendingRecords(date: Date) -> [SpendingRecordModel] {
        let request: NSFetchRequest<SpendingRecord> = SpendingRecord.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let results = try context.fetch(request)
            return results.map(SpendingRecordModel.init)
        } catch {
            DebugLogger.log("❌ 지출 비용 fetch 실패: \(error)")
            return []
        }
    }
    
    func updateSpendingRecord(_ model: SpendingRecordModel) -> Bool {
        guard let spendingRecord = fetchSpendingRecordEntity(id: model.id) else {
            return false
        }

        // 일 예산 귀속은 자정 기준(day)으로, 기록 자체는 전체 시각을 보존한다 (시간대 리포트용)
        let newDate = Calendar.current.startOfDay(for: model.date)

        // 날짜가 바뀌면 해당 날짜의 DailyBudget에 재연결 (없으면 생성)
        if let currentBudget = spendingRecord.dailyBudget,
           let currentDate = currentBudget.date,
           Calendar.current.startOfDay(for: currentDate) != newDate {
            guard let targetBudget = fetchOrCreateDailyBudgetEntity(date: newDate) else {
                return false
            }
            currentBudget.removeFromSpendingRecords(spendingRecord)
            spendingRecord.dailyBudget = targetBudget
            targetBudget.addToSpendingRecords(spendingRecord)
        } else if spendingRecord.dailyBudget == nil {
            // 연결이 끊긴 비정상 케이스 방어
            guard let targetBudget = fetchOrCreateDailyBudgetEntity(date: newDate) else {
                return false
            }
            spendingRecord.dailyBudget = targetBudget
            targetBudget.addToSpendingRecords(spendingRecord)
        }

        spendingRecord.title = model.title
        spendingRecord.amount = NSDecimalNumber(value: model.amount)
        spendingRecord.date = model.date   // 전체 타임스탬프 보존 (시간대 리포트용)
        spendingRecord.category = model.category.rawValue
        spendingRecord.expectedPayback = Int32(model.expectedPayback)
        spendingRecord.paybackReceived = model.paybackReceived

        return saveContext()
    }

    /// 환급/페이백을 실제로 받음 처리 — 오늘 예산에 환급액을 되돌려준다(+이월).
    /// 재수령 방지: 이미 받았거나 환급 예정 0이면 무시.
    @discardableResult
    func receivePayback(recordId: UUID) -> Bool {
        guard let record = fetchSpendingRecordEntity(id: recordId) else { return false }
        let payback = Int(record.expectedPayback)
        guard payback > 0, !record.paybackReceived else { return false }

        record.paybackReceived = true

        let today = Calendar.current.startOfDay(for: Date())
        guard let budget = fetchOrCreateDailyBudgetEntity(date: today) else { return false }
        let credit = CarryOverSource(context: context)
        credit.id = UUID()
        credit.amount = NSDecimalNumber(value: payback)
        credit.date = today
        credit.toDate = today
        credit.dailyBudget = budget
        budget.addToCarryOverSources(credit)

        return saveContext()
    }

    /// 특정 날짜의 DailyBudget 엔티티를 반환 (없으면 기본예산으로 생성).
    /// 지출 날짜 변경 시 대상 날짜에 기록을 재연결하기 위해 사용.
    private func fetchOrCreateDailyBudgetEntity(date: Date) -> DailyBudget? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        if let existing = fetchDailyBudgetEntity(date: startOfDay) {
            return existing
        }
        guard let config = fetchBudgetConfig() else { return nil }
        let base = DailyBudgetCalculator.calculate(from: config, installments: fetchInstallments(), for: startOfDay)
        let dailyBudget = DailyBudget(context: context)
        dailyBudget.availableAmount = NSDecimalNumber(value: base)
        dailyBudget.date = startOfDay
        return dailyBudget
    }

    // MARK: - Stats Queries

    /// 날짜 범위 내 모든 지출 기록 조회 (통계용)
    func fetchSpendingRecords(from startDate: Date, to endDate: Date) -> [SpendingRecordModel] {
        let request: NSFetchRequest<SpendingRecord> = SpendingRecord.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        do {
            return try context.fetch(request).map(SpendingRecordModel.init)
        } catch {
            DebugLogger.log("❌ 통계 지출 fetch 실패: \(error)")
            return []
        }
    }

    /// 특정 월의 지출 기록 조회
    func fetchSpendingRecords(year: Int, month: Int) -> [SpendingRecordModel] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else { return [] }
        return fetchSpendingRecords(from: startDate, to: endDate)
    }

    /// 최근 N일 일별 지출 합계 [(Date, Int)] 반환
    func fetchDailyTotals(days: Int) -> [(date: Date, total: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        let records = fetchSpendingRecords(from: startDate, to: calendar.date(byAdding: .day, value: 1, to: today)!)

        return (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let total = records
                .filter { $0.date >= startOfDay && $0.date < endOfDay }
                .reduce(0) { $0 + $1.amount }
            return (date: startOfDay, total: total)
        }
    }
    
    func deleteSpendingRecord(id: UUID) -> Bool {
        guard let spendingRecord = fetchSpendingRecordEntity(id: id),
              let _ = spendingRecord.dailyBudget else {
            return false
        }

        context.delete(spendingRecord)

        return saveContext()
    }
    
    // MARK: - CarryOverSource CRUD
    func createCarryOverSource(_ model: CarryOverSourceModel) -> Bool {
        guard let dailyBudget = fetchDailyBudgetEntity(date: model.date) else {
            return false
        }
        
        let newCarryOverSource = CarryOverSource(context: context)
        newCarryOverSource.id = UUID()
        newCarryOverSource.amount = NSDecimalNumber(value: model.amount)
        newCarryOverSource.date = model.date
        newCarryOverSource.toDate = model.toDate
        newCarryOverSource.dailyBudget = dailyBudget
        dailyBudget.addToCarryOverSources(newCarryOverSource)
        
        return saveContext()
    }
    
    func fetchCarryOverSourceEntity(id: UUID) -> CarryOverSource? {
        let request: NSFetchRequest<CarryOverSource> = CarryOverSource.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }
    
    func fetchCarryOverSources(date: Date) -> [CarryOverSourceModel] {
        let request: NSFetchRequest<CarryOverSource> = CarryOverSource.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: date)
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        
        do {
            let results = try context.fetch(request)
            return results.map(CarryOverSourceModel.init)
        } catch {
            DebugLogger.log("❌ 이월 금액 fetch 실패: \(error)")
            return []
        }
    }
    
    func updateCarryOverSource(_ model: CarryOverSourceModel) -> Bool {
        guard let carryOverSource = fetchCarryOverSourceEntity(id: model.id) else {
            return false
        }
        
        carryOverSource.amount = NSDecimalNumber(value: model.amount)
        carryOverSource.date = model.date
        carryOverSource.toDate = model.toDate
        
        return saveContext()
    }
    
    func deleteCarryOverSource(id: UUID) -> Bool {
        guard let carryOverSource = fetchCarryOverSourceEntity(id: id) else {
            return false
        }
        
        context.delete(carryOverSource)
        return saveContext()
    }
    
    func deleteCarryOver(_ entity: CarryOverSource) {
        context.delete(entity)
        saveContext()
    }

    // MARK: - Utilities
    func resetAllData() {
        let entityNames = ["BudgetConfig", "FixedCost", "MonthlyFixedCostEntry", "Installment", "Payback", "DailyBudget", "SpendingRecord", "CarryOverSource", "CarryOverPoolEntry", "WishItem", "WishSavingEntry", "SpendingDebt", "DebtRepaymentEntry"]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs

            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                }
            } catch {
                DebugLogger.log("❌ Failed to reset \(entityName): \(error)")
            }
        }

        saveContext()
        DebugLogger.log("✅ CoreData reset completed")
    }
    
    /// 오늘 날짜의 DailyBudgetModel을 "항상" 반환 (없으면 생성)
    func fetchOrCreateTodayDailyBudget() -> DailyBudgetModel? {
        let today = Calendar.current.startOfDay(for: Date())

        if let model = fetchDailyBudgetModel(date: today) {
            return model
        }
        // BudgetConfig 없으면 nil
        guard let config = fetchBudgetConfig() else {
            DebugLogger.log("❌ BudgetConfig 없음 → Budget 설정 필요")
            return nil
        }
        let baseAmount = DailyBudgetCalculator.calculate(from: config, installments: fetchInstallments(), for: today)
        let newModel = DailyBudgetModel(
            availableAmount: baseAmount,
            date: today,
            carryOverSources: [],
            spendingRecords: []
        )
        guard createDailyBudget(newModel) else { return nil }
        // 활성 위시가 있으면 오늘 저금 반영 후 최신 모델 반환
        applyWishSaving(on: today)
        return fetchDailyBudgetModel(date: today) ?? newModel
    }

    // MARK: - Carry-over 자동 처리

    /// 마지막 기록일 다음날부터 `date`(보통 오늘)까지 누락된 DailyBudget을 생성하며
    /// 전날 잔액(todayAvailable, 음수 가능)을 다음날 이월금으로 누적 연결한다.
    /// - 멱등성: 이미 존재하는 날짜는 건너뛰므로 여러 번 호출해도 중복 이월되지 않는다.
    func processDailyBudgets(upTo date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        guard let config = fetchBudgetConfig() else {
            DebugLogger.log("❌ BudgetConfig 없음 → 이월 처리 생략")
            return
        }
        let installments = fetchInstallments()

        // 가장 최근 DailyBudget 날짜 조회
        let request: NSFetchRequest<DailyBudget> = DailyBudget.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = 1
        guard let latest = try? context.fetch(request).first,
              let latestDate = latest.date else {
            // 기록이 전혀 없으면 신규 사용자 → 오늘은 fetchOrCreateTodayDailyBudget()가 이월 0으로 생성
            return
        }

        let latestDay = calendar.startOfDay(for: latestDate)
        guard latestDay < today else { return }  // 이미 오늘까지 처리됨

        // latestDay + 1 ~ today 까지 순회하며 누락된 날짜 생성
        var cursor = calendar.date(byAdding: .day, value: 1, to: latestDay)!
        while cursor <= today {
            // 이미 존재하면 건너뜀 (멱등성)
            if fetchDailyBudgetEntity(date: cursor) == nil {
                let base = DailyBudgetCalculator.calculate(from: config, installments: installments, for: cursor)
                let prevDay = calendar.date(byAdding: .day, value: -1, to: cursor)!
                let prevBalance = fetchDailyBudgetModel(date: prevDay)?.todayAvailable ?? 0

                // 초과분(음수)을 부채로 분리할지 판정. 분리하면 그날 음수 이월은 0이 된다.
                let debtAmount = overspendToConvert(prevBalance: prevBalance, dailyBudget: base, config: config)

                // 이월 방식: 전액 이월은 ±전액, 분리 모드는 음수(페널티)만 이월
                let rawCarry = (config.carryOverMode == .separate) ? min(0, prevBalance) : prevBalance
                let carry = debtAmount > 0 ? max(0, rawCarry) : rawCarry

                var sources: [CarryOverSourceModel] = []
                if carry != 0 {
                    sources.append(CarryOverSourceModel(amount: carry, date: prevDay, toDate: cursor))
                }

                let newModel = DailyBudgetModel(
                    availableAmount: base,
                    date: cursor,
                    carryOverSources: sources,
                    spendingRecords: []
                )
                _ = createDailyBudget(newModel)
                // 활성 위시가 있으면 이 날짜의 저금을 반영 (다음날 이월 계산이 이를 포함)
                applyWishSaving(on: cursor)

                // 분리 모드: 전날의 남은 양수는 '모아둔 이월금' 풀로 적립
                if config.carryOverMode == .separate {
                    let deposit = max(0, prevBalance)
                    if deposit > 0 { depositToPool(amount: deposit, date: cursor) }
                }

                // 초과분을 부채에 합산 (계획 미확정 상태로 생성/누적)
                if debtAmount > 0 { addToDebt(amount: debtAmount, on: cursor) }
            }
            // 계획이 확정된 부채가 있으면 이 날짜의 상환액을 차감한다 (일자당 1회, 멱등)
            applyDebtRepayment(on: cursor, config: config)

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
    }

    /// 과거 소비 수정/삭제 후, `from`(변경된 소비 날짜)부터 오늘까지 일자 이월(및 분리 모드
    /// 풀 적립)을 다시 계산한다. 인출·환급 크레딧(date==그날)과 위시 저금은 건드리지 않는다.
    func recalculateCarryOverChain(from: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: from)
        guard startDay < today else { return }          // 오늘 이후 영향 없음
        guard let config = fetchBudgetConfig() else { return }

        var cursor = calendar.date(byAdding: .day, value: 1, to: startDay)!
        while cursor <= today {
            if let budget = fetchDailyBudgetEntity(date: cursor) {
                let prevDay = calendar.date(byAdding: .day, value: -1, to: cursor)!
                let prevBalance = fetchDailyBudgetModel(date: prevDay)?.todayAvailable ?? 0

                // 1) 기존 '일자 이월'(date < cursor)만 제거
                let sources = budget.carryOverSources?.allObjects as? [CarryOverSource] ?? []
                for s in sources where calendar.startOfDay(for: s.date ?? cursor) < cursor {
                    budget.removeFromCarryOverSources(s)
                    context.delete(s)
                }
                // 2) 이 날짜의 '풀 적립'(양수, date==cursor)만 제거 (인출[음수]·다른 날 적립은 보존)
                let poolReq: NSFetchRequest<CarryOverPoolEntry> = CarryOverPoolEntry.fetchRequest()
                let cursorEnd = calendar.date(byAdding: .day, value: 1, to: cursor)!
                poolReq.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND amount > 0",
                                                cursor as NSDate, cursorEnd as NSDate)
                for e in (try? context.fetch(poolReq)) ?? [] { context.delete(e) }

                // 3) 현재 이월 방식으로 재생성
                let carry = (config.carryOverMode == .separate) ? min(0, prevBalance) : prevBalance
                if carry != 0 {
                    let cos = CarryOverSource(context: context)
                    cos.id = UUID()
                    cos.amount = NSDecimalNumber(value: carry)
                    cos.date = prevDay
                    cos.toDate = cursor
                    cos.dailyBudget = budget
                    budget.addToCarryOverSources(cos)
                }
                if config.carryOverMode == .separate {
                    let deposit = max(0, prevBalance)
                    if deposit > 0 {
                        let entry = CarryOverPoolEntry(context: context)
                        entry.id = UUID()
                        entry.date = cursor
                        entry.amount = NSDecimalNumber(value: deposit)
                    }
                }
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        _ = saveContext()
    }

    // MARK: - 초과 소비 상환 계획 (부채)

    /// 활성 부채 엔티티 (완납되지 않은 것). 항상 최대 1개.
    private func fetchActiveDebtEntity() -> SpendingDebt? {
        let request: NSFetchRequest<SpendingDebt> = SpendingDebt.fetchRequest()
        request.predicate = NSPredicate(format: "completedAt == nil")
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// 활성 부채 (없으면 nil)
    func fetchActiveDebt() -> SpendingDebtModel? {
        fetchActiveDebtEntity().map(SpendingDebtModel.init)
    }

    /// 전날 잔액 중 부채로 전환할 초과 금액. 0이면 기존대로 음수 이월한다.
    /// - 기능이 꺼져 있거나 초과분이 임계값(기본 예산 10%) 미만이면 전환하지 않는다.
    private func overspendToConvert(prevBalance: Int, dailyBudget: Int,
                                    config: BudgetConfigModel) -> Int {
        guard config.debtPlanEnabled, prevBalance < 0 else { return 0 }
        let threshold = DebtRepaymentPlan.threshold(dailyBudget: dailyBudget)
        guard threshold > 0 else { return 0 }
        let overspend = -prevBalance
        return overspend >= threshold ? overspend : 0
    }

    /// 초과분을 부채에 합산한다. 활성 부채가 없으면 계획 미확정 상태로 새로 만든다.
    /// (재초과 시 비율은 유지하고 남은 금액만 늘어나 기간이 재계산된다)
    private func addToDebt(amount: Int, on date: Date) {
        guard amount > 0 else { return }
        let day = Calendar.current.startOfDay(for: date)

        if let debt = fetchActiveDebtEntity() {
            debt.originalAmount = NSDecimalNumber(value: Int(truncating: debt.originalAmount ?? 0) + amount)
            debt.remainingAmount = NSDecimalNumber(value: Int(truncating: debt.remainingAmount ?? 0) + amount)
        } else {
            let debt = SpendingDebt(context: context)
            debt.id = UUID()
            debt.originalAmount = NSDecimalNumber(value: amount)
            debt.remainingAmount = NSDecimalNumber(value: amount)
            debt.repayRatePercent = Int16(DebtRepaymentPlan.defaultRate)
            debt.isPlanned = false
            debt.startedAt = day
        }
        _ = saveContext()
    }

    /// 그날 이미 상환 원장이 있는지 (멱등성 가드)
    private func hasRepayment(on day: Date) -> Bool {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        let request: NSFetchRequest<DebtRepaymentEntry> = DebtRepaymentEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", day as NSDate, end as NSDate)
        request.fetchLimit = 1
        return ((try? context.fetch(request).first) ?? nil) != nil
    }

    /// 계획이 확정된 부채가 있으면 `date`의 상환액을 차감한다.
    /// 상환액은 `CarryOverSource(음수, date == toDate == 그날)`로 기록하므로
    /// `withdrawFromPool`과 동일하게 `recalculateCarryOverChain`에서 보존된다.
    private func applyDebtRepayment(on date: Date, config: BudgetConfigModel) {
        guard config.debtPlanEnabled else { return }
        guard let debt = fetchActiveDebtEntity(), debt.isPlanned else { return }

        let remaining = Int(truncating: debt.remainingAmount ?? 0)
        guard remaining > 0 else { return }

        let day = Calendar.current.startOfDay(for: date)
        guard !hasRepayment(on: day) else { return }
        guard let budget = fetchDailyBudgetEntity(date: day) else { return }

        let base = Int(truncating: budget.availableAmount ?? 0)
        let plan = DebtRepaymentPlan.calculate(debt: remaining, dailyBudget: base,
                                               ratePercent: Int(debt.repayRatePercent))
        guard plan.perDay > 0 else { return }
        let amount = min(remaining, plan.perDay)

        let cos = CarryOverSource(context: context)
        cos.id = UUID()
        cos.amount = NSDecimalNumber(value: -amount)
        cos.date = day
        cos.toDate = day
        cos.dailyBudget = budget
        budget.addToCarryOverSources(cos)

        let entry = DebtRepaymentEntry(context: context)
        entry.id = UUID()
        entry.date = day
        entry.amount = NSDecimalNumber(value: amount)
        entry.debt = debt
        debt.addToRepayments(entry)

        let newRemaining = remaining - amount
        debt.remainingAmount = NSDecimalNumber(value: newRemaining)
        if newRemaining == 0 { debt.completedAt = day }

        _ = saveContext()
    }

    /// 상환 계획을 확정한다 (팝업의 "이 계획으로 갚기"). 확정한 날부터 상환이 시작된다.
    @discardableResult
    func confirmDebtPlan(ratePercent: Int) -> Bool {
        guard let debt = fetchActiveDebtEntity() else { return false }
        debt.isPlanned = true
        debt.repayRatePercent = Int16(ratePercent)
        debt.deferredAt = nil
        guard saveContext() else { return false }

        if let config = fetchBudgetConfig() {
            applyDebtRepayment(on: Date(), config: config)
        }
        return true
    }

    /// 계획 설정을 오늘 미룬다 (팝업의 "나중에"). 다음 날 다시 표시된다.
    @discardableResult
    func deferDebtPlan() -> Bool {
        guard let debt = fetchActiveDebtEntity() else { return false }
        debt.deferredAt = Calendar.current.startOfDay(for: Date())
        return saveContext()
    }

    /// 상환 비율만 변경 (설정 화면). 오늘 상환이 이미 반영됐으면 내일부터 적용된다.
    @discardableResult
    func updateDebtRate(_ ratePercent: Int) -> Bool {
        guard let debt = fetchActiveDebtEntity() else { return false }
        debt.repayRatePercent = Int16(ratePercent)
        return saveContext()
    }

    /// 남은 부채를 오늘 예산에서 한 번에 차감하고 종료한다 (조기 완납 / 기능 OFF 전환).
    @discardableResult
    func settleDebtImmediately() -> Bool {
        guard let debt = fetchActiveDebtEntity() else { return false }
        let remaining = Int(truncating: debt.remainingAmount ?? 0)
        let today = Calendar.current.startOfDay(for: Date())

        if remaining > 0, let budget = fetchOrCreateDailyBudgetEntity(date: today) {
            let cos = CarryOverSource(context: context)
            cos.id = UUID()
            cos.amount = NSDecimalNumber(value: -remaining)
            cos.date = today
            cos.toDate = today
            cos.dailyBudget = budget
            budget.addToCarryOverSources(cos)

            let entry = DebtRepaymentEntry(context: context)
            entry.id = UUID()
            entry.date = today
            entry.amount = NSDecimalNumber(value: remaining)
            entry.debt = debt
            debt.addToRepayments(entry)
        }

        debt.remainingAmount = 0
        debt.completedAt = today
        return saveContext()
    }

    /// 상환 계획 기능 on/off. 끄면 남은 부채를 오늘 예산에 즉시 반영하고 종료한다.
    @discardableResult
    func setDebtPlanEnabled(_ enabled: Bool) -> Bool {
        guard let config = fetchBudgetConfigEntity() else { return false }
        config.debtPlanEnabled = enabled
        guard saveContext() else { return false }
        if !enabled, fetchActiveDebtEntity() != nil {
            return settleDebtImmediately()
        }
        return true
    }

    /// 오늘 상환한 금액 (홈 표시용)
    func todayDebtRepaymentAmount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let request: NSFetchRequest<DebtRepaymentEntry> = DebtRepaymentEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", today as NSDate, end as NSDate)
        let entries = (try? context.fetch(request)) ?? []
        return entries.reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
    }

    // MARK: - 모아둔 이월금 (분리 모드 풀)

    /// 풀 잔액 = 적립(+) − 인출(−) 합계
    func carryOverPoolBalance() -> Int {
        let request: NSFetchRequest<CarryOverPoolEntry> = CarryOverPoolEntry.fetchRequest()
        let entries = (try? context.fetch(request)) ?? []
        return entries.reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
    }

    /// 오늘 모아둔 이월금에서 가져온(인출·부족액 충당) 금액 합
    func todayPoolWithdrawnAmount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let req: NSFetchRequest<CarryOverPoolEntry> = CarryOverPoolEntry.fetchRequest()
        req.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND amount < 0", today as NSDate, end as NSDate)
        let entries = (try? context.fetch(req)) ?? []
        return entries.reduce(0) { $0 - Int(truncating: $1.amount ?? 0) }   // 음수의 절대값 합
    }

    /// 남은 양수를 풀에 적립 (분리 모드 일자 생성 시 내부 호출)
    private func depositToPool(amount: Int, date: Date) {
        guard amount > 0 else { return }
        let entry = CarryOverPoolEntry(context: context)
        entry.id = UUID()
        entry.date = date
        entry.amount = NSDecimalNumber(value: amount)
        _ = saveContext()
    }

    /// 풀에서 오늘 예산으로 꺼내 쓴다. 오늘 이월(+) 추가 + 풀 인출(−). 잔액 초과 불가.
    @discardableResult
    func withdrawFromPool(amount: Int) -> Bool {
        guard amount > 0, amount <= carryOverPoolBalance() else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        guard let budget = fetchOrCreateDailyBudgetEntity(date: today) else { return false }

        let cos = CarryOverSource(context: context)
        cos.id = UUID()
        cos.amount = NSDecimalNumber(value: amount)
        cos.date = today
        cos.toDate = today
        cos.dailyBudget = budget
        budget.addToCarryOverSources(cos)

        let entry = CarryOverPoolEntry(context: context)
        entry.id = UUID()
        entry.date = today
        entry.amount = NSDecimalNumber(value: -amount)

        return saveContext()
    }

    // MARK: - 위시리스트 저금

    /// 현재 활성(저금중) 위시 아이템 엔티티
    func fetchActiveWishItemEntity() -> WishItem? {
        let request: NSFetchRequest<WishItem> = WishItem.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", WishStatus.saving.rawValue)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// 위시 아이템의 누적 저금액 (저금 엔트리 합계)
    func savedAmount(for wishItemId: UUID) -> Int {
        let request: NSFetchRequest<WishSavingEntry> = WishSavingEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wishItem.id == %@", wishItemId as CVarArg)
        let entries = (try? context.fetch(request)) ?? []
        return entries.reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
    }

    /// 활성 위시가 있으면 해당 날짜에 저금 엔트리를 생성한다.
    /// - 멱등: 이미 이 아이템의 이 날짜 저금이 있으면 skip
    /// - 목표 도달 시 남은 금액만 저금하고 상태를 구매가능으로 전환
    private func applyWishSaving(on date: Date) {
        guard let active = fetchActiveWishItemEntity(), let activeId = active.id else { return }
        let day = Calendar.current.startOfDay(for: date)
        // 활성화일 이전으로 저금이 소급되지 않도록
        if let activatedAt = active.activatedAt,
           day < Calendar.current.startOfDay(for: activatedAt) { return }
        guard let budget = fetchDailyBudgetEntity(date: day) else { return }

        let existing = (budget.wishSavingEntries?.allObjects as? [WishSavingEntry] ?? [])
            .contains { $0.wishItem?.id == activeId }
        if existing { return }

        let target = Int(truncating: active.targetAmount ?? 0)
        let saved = savedAmount(for: activeId)
        let remaining = target - saved
        if remaining <= 0 {
            active.status = WishStatus.purchasable.rawValue
            _ = saveContext()
            return
        }

        let daily = Int(truncating: active.dailySaving ?? 0)
        let amount = min(daily, remaining)

        let entry = WishSavingEntry(context: context)
        entry.id = UUID()
        entry.date = day
        entry.amount = NSDecimalNumber(value: amount)
        entry.wishItem = active
        entry.dailyBudget = budget
        active.addToSavingEntries(entry)
        budget.addToWishSavingEntries(entry)

        if saved + amount >= target {
            active.status = WishStatus.purchasable.rawValue
        }
        _ = saveContext()
    }

    // MARK: 위시 CRUD

    func createWishItem(_ model: WishItemModel) -> Bool {
        let new = WishItem(context: context)
        new.id = model.id
        new.title = model.title
        new.targetAmount = NSDecimalNumber(value: model.targetAmount)
        new.dailySaving = NSDecimalNumber(value: model.dailySaving)
        new.status = model.status.rawValue
        new.kind = model.kind.rawValue
        new.createdAt = model.createdAt
        return saveContext()
    }

    func fetchWishItems() -> [WishItemModel] {
        let request: NSFetchRequest<WishItem> = WishItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map { WishItemModel(entity: $0, savedAmount: savedAmount(for: $0.id ?? UUID())) }
    }

    func fetchActiveWishItem() -> WishItemModel? {
        guard let entity = fetchActiveWishItemEntity(), let id = entity.id else { return nil }
        return WishItemModel(entity: entity, savedAmount: savedAmount(for: id))
    }

    private func fetchWishItemEntity(id: UUID) -> WishItem? {
        let request: NSFetchRequest<WishItem> = WishItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }

    /// 제목·목표금액·종류(희망/필수) 수정 (저금 상태는 건드리지 않음)
    func updateWishItem(id: UUID, title: String, targetAmount: Int, kind: WishKind) -> Bool {
        guard let entity = fetchWishItemEntity(id: id) else { return false }
        entity.title = title
        entity.targetAmount = NSDecimalNumber(value: targetAmount)
        entity.kind = kind.rawValue
        return saveContext()
    }

    /// 위시 저금 활성화. 다른 활성 아이템이 있으면 실패(1개만 저금 가능).
    func activateWish(id: UUID, dailySaving: Int) -> Bool {
        guard dailySaving > 0 else { return false }
        if let other = fetchActiveWishItemEntity(), other.id != id { return false }
        guard let entity = fetchWishItemEntity(id: id) else { return false }

        // 재활성화 대비: 기존 엔트리 제거 후 새 저금 시작
        for e in (entity.savingEntries?.allObjects as? [WishSavingEntry] ?? []) {
            context.delete(e)
        }
        entity.status = WishStatus.saving.rawValue
        entity.dailySaving = NSDecimalNumber(value: dailySaving)
        entity.activatedAt = Date()
        _ = saveContext()

        // 오늘 저금 즉시 반영
        applyWishSaving(on: Date())
        return true
    }

    /// 위시 저금 해지 — 누적액을 오늘 잔액으로 환급하고 대기 상태로.
    @discardableResult
    func deactivateWish(id: UUID) -> Bool {
        guard let entity = fetchWishItemEntity(id: id) else { return false }
        refundWishSaving(entity)
        entity.status = WishStatus.waiting.rawValue
        entity.dailySaving = 0
        entity.activatedAt = nil
        return saveContext()
    }

    /// 위시 구매 완료 — 소비 기록 생성 없이 완료 처리 (이미 매일 차감으로 모은 돈).
    func completeWish(id: UUID) -> Bool {
        guard let entity = fetchWishItemEntity(id: id) else { return false }
        entity.status = WishStatus.completed.rawValue
        entity.completedAt = Date()
        return saveContext()
    }

    func deleteWishItem(id: UUID) -> Bool {
        guard let entity = fetchWishItemEntity(id: id) else { return false }
        // 저금 중이었다면 누적액 환급 후 삭제
        if WishStatus.from(entity.status) == .saving {
            refundWishSaving(entity)
        }
        context.delete(entity)   // savingEntries는 Cascade 삭제
        return saveContext()
    }

    /// 과거 일자에 이미 이월로 반영된 저금분을 오늘 잔액으로 환급한다.
    /// 오늘 저금분은 엔트리 삭제(라이브 차감 제거)로 자연 환급되므로, 환급 이월액은
    /// "오늘 이전 엔트리 합계"만 더한다. (이중 환급 방지)
    private func refundWishSaving(_ entity: WishItem) {
        let today = Calendar.current.startOfDay(for: Date())
        let entries = entity.savingEntries?.allObjects as? [WishSavingEntry] ?? []
        let pastTotal = entries
            .filter { Calendar.current.startOfDay(for: $0.date ?? today) < today }
            .reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }

        if pastTotal != 0, let budget = fetchOrCreateDailyBudgetEntity(date: today) {
            let refund = CarryOverSource(context: context)
            refund.id = UUID()
            refund.amount = NSDecimalNumber(value: pastTotal)
            refund.date = today
            refund.toDate = today
            refund.dailyBudget = budget
            budget.addToCarryOverSources(refund)
        }
        // 엔트리 제거 (오늘 엔트리 라이브 차감도 함께 해제됨)
        for e in entries { context.delete(e) }
    }
}
