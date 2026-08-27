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

    /// 이월 백필(`processDailyBudgets`)이 도는 중인지. 백필이 만드는 일자가 다시 백필을
    /// 부르는 재진입을 막는다.
    private var isBackfilling = false

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
        config.themeMode = model.themeMode.rawValue
        applyBudgetMode(model, to: config)

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
        config.themeMode = model.themeMode.rawValue
        applyBudgetMode(model, to: config)

        return saveContext()
    }

    /// 예산 모드 관련 필드를 옮긴다 (모드별로 쓰는 필드가 달라 한곳에 모아둔다)
    private func applyBudgetMode(_ model: BudgetConfigModel, to config: BudgetConfig) {
        config.budgetMode = model.budgetMode.rawValue
        config.totalAmount = Int32(model.totalAmount)
        config.lumpSumStart = model.lumpSumStart
        config.lumpSumEnd = model.lumpSumEnd
        config.dailyAmount = Int32(model.dailyAmount)
    }

    /// 앱 테마만 변경 (기기 설정 / 밝게 / 어둡게)
    @discardableResult
    func updateThemeMode(_ mode: ThemeMode) -> Bool {
        guard let config = fetchBudgetConfigEntity() else { return false }
        config.themeMode = mode.rawValue
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
            addPoolEntry(amount: swept, date: today, reason: .sweep)
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

    /// 페이백 수령 예정일 알림을 현재 상태 기준으로 재예약한다.
    /// 아직 받지 않은(예상·확정) 건만 대상이다.
    func refreshPaybackReminders(now: Date = Date()) {
        let items = fetchPaybacks()
            .filter { ($0.status == .estimated || $0.status == .confirmed) && $0.expectedDate != nil }
            .map { (id: $0.id, title: $0.title.isEmpty ? "환급" : $0.title, expectedDate: $0.expectedDate!) }
        NotificationService.shared.refreshPaybackReminders(items: items, now: now)
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
        e.linkedCategory = m.linkedCategory?.rawValue
        e.refundRatePercent = Int16(m.refundRatePercent)
    }

    /// 기간형 페이백에 묶인 소비 (기간 + 카테고리로 자동 수집, 최신순).
    /// K-패스처럼 한 달치 교통비를 사용자가 직접 더하지 않아도 되게 한다.
    func linkedSpending(for payback: PaybackModel) -> [SpendingRecordModel] {
        guard payback.canLinkSpending,
              let start = payback.periodStart, let end = payback.periodEnd,
              let category = payback.linkedCategory else { return [] }

        let calendar = Calendar.current
        let from = calendar.startOfDay(for: start)
        // periodEnd는 사용자가 고른 '마지막 날'이라 그날 전체를 포함해야 한다
        guard let to = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) else {
            return []
        }
        return fetchSpendingRecords(from: from, to: to)
            .filter { $0.category == category }
            .sorted { $0.date > $1.date }
    }

    /// 묶인 소비의 합계와 건수
    func linkedSpendingTotal(for payback: PaybackModel) -> (total: Int, count: Int) {
        let records = linkedSpending(for: payback)
        return (records.reduce(0) { $0 + $1.amount }, records.count)
    }

    /// 수령 예정일이 지났는데 아직 받지 못한 페이백 (알림·배너용)
    func overduePaybacks(asOf date: Date = Date()) -> [PaybackModel] {
        let today = Calendar.current.startOfDay(for: date)
        return fetchPaybacks().filter { payback in
            guard payback.status == .estimated || payback.status == .confirmed,
                  let expected = payback.expectedDate else { return false }
            return Calendar.current.startOfDay(for: expected) <= today
        }
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
            addCarryOverSource(to: dailyBudget, amount: source.amount,
                               date: source.date, toDate: source.toDate, reason: source.reason)
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

        guard saveContext() else { return false }
        recalculateCarryOverChain(from: model.date)
        return true
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
        // 날짜를 옮기면 옛 날짜와 새 날짜 양쪽의 잔액이 달라지므로 이른 쪽부터 다시 계산한다
        let oldDate = Calendar.current.startOfDay(
            for: spendingRecord.dailyBudget?.date ?? spendingRecord.date ?? model.date)

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

        guard saveContext() else { return false }
        recalculateCarryOverChain(from: min(oldDate, newDate))
        return true
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
        addCarryOverSource(to: budget, amount: payback, date: today, toDate: today, reason: .refund)

        return saveContext()
    }

    /// 특정 날짜의 DailyBudget 엔티티를 반환 (없으면 기본예산으로 생성).
    /// 지출 날짜 변경 시 대상 날짜에 기록을 재연결하기 위해 사용.
    private func fetchOrCreateDailyBudgetEntity(date: Date) -> DailyBudget? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        if let existing = fetchDailyBudgetEntity(date: startOfDay) {
            return existing
        }
        // 오늘(이후)을 만드는 경우엔 백필을 먼저 돌려 전날 이월을 이어받게 한다.
        // 과거 날짜는 그날 이후 이월을 소비 CRUD의 체인 재계산이 다시 맞춘다.
        if startOfDay >= Calendar.current.startOfDay(for: Date()) {
            processDailyBudgets(upTo: startOfDay)
            if let filled = fetchDailyBudgetEntity(date: startOfDay) {
                return filled
            }
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
    /// 전체 소비 기록 (최신순) — 항목 이름 정리처럼 기간 제한이 없는 작업용
    func fetchAllSpendingRecords() -> [SpendingRecordModel] {
        let request: NSFetchRequest<SpendingRecord> = SpendingRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map(SpendingRecordModel.init)
    }

    /// 항목 이름 일괄 변경. `titles` 중 하나와 일치하는 기록의 제목을 `newTitle`로 바꾼다.
    ///
    /// 비교는 자동완성과 같은 `정규화 + 소문자` 기준이라 "스타벅스 커피"를 지정하면
    /// "  스타벅스   커피 " 같은 표기도 함께 잡힌다.
    /// **제목만 바꾼다** — 금액·날짜·카테고리는 그대로라 예산·이월 계산에 영향이 없다.
    /// - Returns: 실제로 바뀐 기록 수
    @discardableResult
    func renameSpendingTitles(matching titles: [String], to newTitle: String) -> Int {
        let target = SpendingSuggestionEngine.normalize(newTitle)
        guard !target.isEmpty else { return 0 }

        let keys = Set(titles.map { SpendingSuggestionEngine.normalize($0).lowercased() })
        guard !keys.isEmpty else { return 0 }

        let request: NSFetchRequest<SpendingRecord> = SpendingRecord.fetchRequest()
        let entities = (try? context.fetch(request)) ?? []

        var changed = 0
        for entity in entities {
            let normalized = SpendingSuggestionEngine.normalize(entity.title ?? "")
            guard keys.contains(normalized.lowercased()), normalized != target else { continue }
            entity.title = target
            changed += 1
        }

        guard changed > 0 else { return 0 }
        return saveContext() ? changed : 0
    }

    /// 기간 내 일자별 예산 기록 (날짜 오름차순). `[from, to)` 반개구간.
    func fetchDailyBudgetModels(from startDate: Date, to endDate: Date) -> [DailyBudgetModel] {
        let request: NSFetchRequest<DailyBudget> = DailyBudget.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@",
                                        Calendar.current.startOfDay(for: startDate) as NSDate,
                                        Calendar.current.startOfDay(for: endDate) as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map(DailyBudgetModel.init)
    }

    /// 최근 `months`개월 동안 하루 예산을 넘긴 날 (최신순).
    /// 부채가 어디서 왔는지 되짚어보기 위한 조회.
    func fetchOverspendDays(months: Int = 3, now: Date = Date()) -> [OverspendDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .month, value: -months, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        return OverspendAnalyzer.overspendDays(from: fetchDailyBudgetModels(from: start, to: end))
    }

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
              let budget = spendingRecord.dailyBudget else {
            return false
        }

        let affectedDate = Calendar.current.startOfDay(
            for: budget.date ?? spendingRecord.date ?? Date())
        context.delete(spendingRecord)

        guard saveContext() else { return false }
        recalculateCarryOverChain(from: affectedDate)
        return true
    }
    
    // MARK: - CarryOverSource CRUD
    func createCarryOverSource(_ model: CarryOverSourceModel) -> Bool {
        guard let dailyBudget = fetchDailyBudgetEntity(date: model.date) else {
            return false
        }

        addCarryOverSource(to: dailyBudget, amount: model.amount,
                           date: model.date, toDate: model.toDate, reason: model.reason)
        return saveContext()
    }

    /// 이월 항목 한 줄을 붙인다 (저장은 호출자가 한다).
    /// 모든 생성 지점이 이 함수를 거쳐야 `reason`이 빠지는 항목이 생기지 않는다.
    @discardableResult
    private func addCarryOverSource(to budget: DailyBudget, amount: Int,
                                    date: Date, toDate: Date,
                                    reason: CarryOverReason) -> CarryOverSource {
        let source = CarryOverSource(context: context)
        source.id = UUID()
        source.amount = NSDecimalNumber(value: amount)
        source.date = date
        source.toDate = toDate
        source.reason = reason.rawValue
        source.dailyBudget = budget
        budget.addToCarryOverSources(source)
        return source
    }

    /// `budget`에 달린 이월 항목 중 지정한 성격의 것만 (재계산·멱등성 판정용)
    private func carryOverSources(of budget: DailyBudget,
                                  reason: CarryOverReason) -> [CarryOverSource] {
        let sources = budget.carryOverSources?.allObjects as? [CarryOverSource] ?? []
        return sources.filter {
            CarryOverReason.from($0.reason,
                                 amount: Int(truncating: $0.amount ?? 0),
                                 date: $0.date ?? Date(),
                                 toDate: $0.toDate ?? Date()) == reason
        }
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
        carryOverSource.reason = model.reason.rawValue

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
        let entityNames = ["BudgetConfig", "FixedCost", "MonthlyFixedCostEntry", "Installment", "Payback", "DailyBudget", "SpendingRecord", "CarryOverSource", "CarryOverPoolEntry", "WishItem", "WishSavingEntry", "SpendingDebt", "DebtRepaymentEntry", "AssetTransfer"]

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
        // 이월을 달지 않고 그냥 만들면 전날 잔액이 사라진다. 홈이 아닌 화면에서 먼저
        // 들어와도 같은 결과가 되도록 백필을 먼저 돌린다 (기록이 있으면 오늘까지 채워진다).
        processDailyBudgets(upTo: today)
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
        // 백필 도중 내부에서 일자를 만드는 경로(위시 저금 등)가 다시 백필로 들어오지 않게 한다
        guard !isBackfilling else { return }
        isBackfilling = true
        defer { isBackfilling = false }

        // 그날 처리가 끝난 뒤 부채 잔액을 원장과 맞춘다 (홈 진입마다 — 어긋난 채로 남지 않는다)
        defer { reconcileDebtNow(now: date) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        // 급여일 부채 흡수가 일어나면 다시 읽어야 하므로 var
        guard var config = fetchBudgetConfig() else {
            DebugLogger.log("❌ BudgetConfig 없음 → 이월 처리 생략")
            return
        }
        let installments = fetchInstallments()

        // 채워야 할 첫 날.
        //
        // "가장 최근 날짜 다음"만 보면, 홈보다 먼저 오늘을 만든 경로가 있었을 때
        // 중간이 빈 채로 "이미 처리됨"이 되어 이월이 영영 끊긴다. 실제로 비어 있는
        // 가장 이른 날을 찾아 거기서부터 채운다 (이미 끊긴 데이터도 이때 복구된다).
        let existingDays = fetchDailyBudgetDays()
        guard let firstDay = existingDays.min() else {
            // 기록이 전혀 없으면 신규 사용자 → 오늘은 fetchOrCreateTodayDailyBudget()가 이월 0으로 생성
            return
        }

        guard let startDay = firstMissingDay(after: firstDay, upTo: today, in: existingDays) else {
            // 빈 날이 없어도, 이전 버전에서 넘어온 큰 음수 이월이 남아 있으면 부채로 전환한다.
            // (일자 전환 시점에만 전환하면 업데이트 직후 하루 동안 계속 음수로 보인다)
            convertExistingDeficitToDebt(on: today, config: config)
            return
        }

        // startDay ~ today 까지 순회하며 누락된 날짜 생성 (이미 있는 날은 건너뛴다)
        var cursor = startDay
        while cursor <= today {
            let isNewDay = fetchDailyBudgetEntity(date: cursor) == nil   // 이미 있으면 재생성하지 않음 (멱등성)
            let prevDay = calendar.date(byAdding: .day, value: -1, to: cursor)!
            var prevBalance = 0
            var debtAmount = 0

            if isNewDay {
                let prevBudget = fetchDailyBudgetModel(date: prevDay)
                prevBalance = prevBudget?.todayAvailable ?? 0

                // 임계 판정에는 흡수 반영 전 예산을 쓴다 (흡수 여부와 무관하게 "큰 초과"인지 판단)
                let provisionalBase = DailyBudgetCalculator.calculate(
                    from: config, installments: installments, for: cursor)
                debtAmount = overspendToConvert(prevBudget: prevBudget, prevBalance: prevBalance,
                                                dailyBudget: provisionalBase, config: config)

                // 흡수보다 먼저 합산해야, 이 날이 급여일일 때 전날 초과분까지 새 기간 예산으로 정산된다
                if debtAmount > 0 { addToDebt(amount: debtAmount, on: cursor) }
            }

            // 급여일이면 남은 부채를 새 급여 기간 예산으로 흡수한다 (그날 예산 확정보다 먼저)
            if absorbDebtIfPayday(on: cursor, config: config, installments: installments),
               let refreshed = fetchBudgetConfig() {
                config = refreshed
            }

            if isNewDay {
                let base = DailyBudgetCalculator.calculate(from: config, installments: installments, for: cursor)

                // 이월 방식: 전액 이월은 ±전액, 분리 모드는 음수(페널티)만 이월.
                let carry = (config.carryOverMode == .separate) ? min(0, prevBalance) : prevBalance

                var sources: [CarryOverSourceModel] = []
                if carry != 0 {
                    sources.append(CarryOverSourceModel(amount: carry, date: prevDay, toDate: cursor,
                                                        reason: .carryOver))
                }
                // 부채로 옮긴 적자는 음수 이월을 '지우는' 대신 같은 금액의 상쇄 크레딧으로 덮는다.
                // 지워버리면 이월 체인을 다시 계산할 때(과거 소비 수정·삭제) 같은 적자가
                // 되살아나 부채와 이월에 이중으로 잡힌다.
                if debtAmount > 0 {
                    sources.append(CarryOverSourceModel(amount: debtAmount, date: cursor, toDate: cursor,
                                                        reason: .debtTransfer))
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
            }

            // 계획이 확정된 부채가 있으면 이 날짜의 상환액을 차감한다 (일자당 1회, 멱등)
            applyDebtRepayment(on: cursor, config: config)

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }

        // 채운 날 뒤에 이미 있던 날들은 끊긴 이월을 그대로 들고 있으므로 다시 이어준다.
        // 방금 만든 날들은 같은 값으로 재계산되므로 결과가 달라지지 않는다 (멱등).
        recalculateCarryOverChain(from: calendar.date(byAdding: .day, value: -1, to: startDay)!)
    }

    /// 기록이 있는 모든 일자(자정 기준) 집합. 빈 날 탐지용이라 날짜만 가볍게 읽는다.
    private func fetchDailyBudgetDays() -> Set<Date> {
        let request: NSFetchRequest<DailyBudget> = DailyBudget.fetchRequest()
        request.propertiesToFetch = ["date"]
        let entities = (try? context.fetch(request)) ?? []
        let calendar = Calendar.current
        return Set(entities.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })
    }

    /// `firstDay` 다음날부터 `today`까지 중 기록이 비어 있는 가장 이른 날 (없으면 nil)
    private func firstMissingDay(after firstDay: Date, upTo today: Date,
                                 in existingDays: Set<Date>) -> Date? {
        let calendar = Calendar.current
        var cursor = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        while cursor <= today {
            if !existingDays.contains(cursor) { return cursor }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return nil
    }

    /// `from`(변경된 소비 날짜)부터 오늘까지 일자 이월(및 분리 모드 풀 적립)을 다시 계산한다.
    /// 인출·환급 크레딧(date==그날)과 위시 저금은 건드리지 않는다.
    ///
    /// 소비 CRUD(`createSpendingRecord`/`updateSpendingRecord`/`deleteSpendingRecord`)가
    /// 직접 호출하므로 화면에서 따로 부를 필요가 없다. 호출자에게 맡겼을 때 소비 입력 화면이
    /// 이를 빠뜨려 과거 날짜 추가분이 이후 날 이월에 반영되지 않는 문제가 있었다.
    ///
    /// 아직 부채로 옮긴 적 없는 날에 초과가 생기면(여행 뒤 소급 입력 등) 이 패스에서 전환한다.
    /// 전환을 별도 패스로 빼면 크레딧이 붙는 순간 그 뒤 날들의 이월이 어긋나므로, 한 번의
    /// 전진 패스 안에서 처리해야 체인이 맞는다.
    func recalculateCarryOverChain(from: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: from)
        guard startDay < today else { return }          // 오늘 이후 영향 없음
        guard let config = fetchBudgetConfig() else { return }
        let installments = fetchInstallments()
        let periodStart = currentPeriodStart(config: config, today: today)

        var cursor = calendar.date(byAdding: .day, value: 1, to: startDay)!
        while cursor <= today {
            if let budget = fetchDailyBudgetEntity(date: cursor) {
                let prevDay = calendar.date(byAdding: .day, value: -1, to: cursor)!
                let prevBudget = fetchDailyBudgetModel(date: prevDay)
                let prevBalance = prevBudget?.todayAvailable ?? 0

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
                    addCarryOverSource(to: budget, amount: carry, date: prevDay, toDate: cursor,
                                       reason: .carryOver)
                }
                // 4) 이 날 부채로 옮긴 적자가 있었다면 새로 계산된 적자에 맞춰 크레딧·부채를 함께 조정한다.
                //    적자 전액이 아니라 '전날 소비가 배정을 넘긴 만큼'만 쓴다 — 저축·투자가 만든
                //    적자까지 넣으면 재계산할 때마다 저축이 빚으로 둔갑한다
                //    (`overspendToConvert`와 같은 기준).
                let convertible = convertibleOverspend(of: prevBudget, deficit: max(0, -carry))
                if carryOverSources(of: budget, reason: .debtTransfer).isEmpty {
                    // 아직 옮긴 적 없는 날 — 과거 날짜에 초과를 뒤늦게 넣은 경우가 여기다
                    convertOverspendIfEligible(on: budget, day: cursor, amount: convertible,
                                               config: config, installments: installments,
                                               periodStart: periodStart)
                } else {
                    reconcileDebtTransfer(on: budget, newDeficit: convertible, day: cursor)
                }

                if config.carryOverMode == .separate {
                    let deposit = max(0, prevBalance)
                    if deposit > 0 {
                        addPoolEntry(amount: deposit, date: cursor, reason: .deposit)
                    }
                }
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        _ = saveContext()
    }

    /// 아직 부채로 옮긴 적 없는 날의 초과를 전환한다 (과거 날짜 소급 입력 경로).
    ///
    /// 판정 기준은 일자 생성 시점(`overspendToConvert`)과 같다 — 소비가 배정을 넘긴 만큼만,
    /// 하루 예산의 10% 이상일 때. 다만 **이전 급여 기간은 건드리지 않는다**: 급여일에 남은
    /// 부채를 새 기간 예산으로 흡수해 이미 정산했기 때문에, 그 기간의 초과를 뒤늦게 넣어
    /// 다시 빚으로 만들면 이중 부과가 된다.
    private func convertOverspendIfEligible(on budget: DailyBudget, day: Date, amount: Int,
                                            config: BudgetConfigModel,
                                            installments: [InstallmentModel],
                                            periodStart: Date?) {
        guard config.debtPlanEnabled, amount > 0 else { return }
        if let periodStart, day < periodStart { return }

        let base = DailyBudgetCalculator.calculate(from: config, installments: installments, for: day)
        let threshold = DebtRepaymentPlan.threshold(dailyBudget: base)
        guard threshold > 0, amount >= threshold else { return }

        addCarryOverSource(to: budget, amount: amount, date: day, toDate: day, reason: .debtTransfer)
        addToDebt(amount: amount, on: day)
    }

    /// 오늘이 속한 급여 기간의 시작일. 기간 개념이 없는 모드는 `nil` (컷오프 없음).
    private func currentPeriodStart(config: BudgetConfigModel, today: Date) -> Date? {
        guard config.budgetMode.hasPayPeriod else { return nil }
        return DailyBudgetCalculator.payPeriod(payday: config.payday, containing: today).start
    }

    /// 부채로 옮긴 적자의 상쇄 크레딧을 `newDeficit`에 맞추고, 차액만큼 활성 부채를 조정한다.
    ///
    /// 과거 소비를 고치면 그날 적자 규모 자체가 달라진다. 크레딧만 그대로 두면
    /// "부채에 잡힌 금액"과 "실제로 넘긴 금액"이 어긋나므로 둘을 함께 움직인다.
    /// - 이관 기록이 없는 날은 건드리지 않는다 (재계산이 새 부채를 만들지는 않는다).
    /// - 이미 정산된(급여일 흡수·완납) 부채도 건드리지 않는다. 그 경우 크레딧을 남겨두면
    ///   이미 받은 정산 혜택과 상계되어 총액은 맞는다.
    private func reconcileDebtTransfer(on budget: DailyBudget, newDeficit: Int, day: Date) {
        let credits = carryOverSources(of: budget, reason: .debtTransfer)
        let previous = credits.reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
        guard previous > 0, newDeficit != previous else { return }
        guard let debt = fetchActiveDebtEntity() else { return }

        for credit in credits {
            budget.removeFromCarryOverSources(credit)
            context.delete(credit)
        }
        if newDeficit > 0 {
            addCarryOverSource(to: budget, amount: newDeficit, date: day, toDate: day,
                               reason: .debtTransfer)
        }

        let delta = newDeficit - previous
        let remaining = max(0, Int(truncating: debt.remainingAmount ?? 0) + delta)
        debt.originalAmount = NSDecimalNumber(
            value: max(0, Int(truncating: debt.originalAmount ?? 0) + delta))
        debt.remainingAmount = NSDecimalNumber(value: remaining)
        if remaining == 0 { debt.completedAt = day }
    }

    // MARK: - 부채 잔액 보정 (원장 기준 재계산)

    /// 남은 부채를 원장에서 **다시 계산한** 값.
    ///
    /// `SpendingDebt.remainingAmount`는 한 번 적립되면 다시 계산되지 않는 누적값이라
    /// 잘못 더해진 금액이 영원히 남는다. 반면 "부채로 옮긴 금액"과 상환 내역은 원장에
    /// 그대로 있어 언제든 다시 구할 수 있다:
    ///
    ///     남은 부채 = Σ(이 부채에 옮긴 전환 크레딧) − Σ(그 부채에 갚은 금액)
    ///
    /// 합산 근거는 **실제로 부채로 옮긴 날**(`debtTransfer` 크레딧이 붙은 날)이다.
    /// 기간을 훑어 "초과한 날"을 다시 더하는 방식이 아니다 — 그러면 부채 시작일이
    /// 과거로 잡히는 순간(과거 날짜 소급 입력) 그 사이의 무관한 초과일까지 빨아들여
    /// 이중 계상된다. 크레딧은 과거 소비를 고칠 때 `reconcileDebtTransfer`가 최신
    /// 초과액으로 유지하므로 "크레딧 합 = 전환된 초과 합"이 항상 성립한다.
    /// - Returns: 활성 부채가 없거나, 전환 크레딧이 하나도 없어 다시 계산할 근거가
    ///   없으면 `nil` (상환 계획 기능이 없던 시절에 쌓인 적자가 여기 해당한다)
    func reconciledDebt(now: Date = Date()) -> (original: Int, remaining: Int)? {
        guard let debt = fetchActiveDebtEntity() else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let startedAt = calendar.startOfDay(for: debt.startedAt ?? today)
        guard let end = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }

        // 이전 부채는 이 부채가 시작되기 전에 완납됐으므로, startedAt 이후 크레딧만이 이 부채의 것이다
        let credits = debtTransferCredits(from: startedAt, to: end)
        guard !credits.isEmpty else { return nil }
        let converted = credits.reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }

        let entries = debt.repayments?.allObjects as? [DebtRepaymentEntry] ?? []
        let repaid = entries.reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }

        return (original: max(converted, repaid), remaining: max(0, converted - repaid))
    }

    /// `[from, to)` 구간에 남아 있는 부채 전환 크레딧.
    /// `debtTransfer`는 항상 명시적으로 저장되므로(추론 대상이 아니다) 문자열 조건으로 정확히 걸린다.
    private func debtTransferCredits(from: Date, to: Date) -> [CarryOverSource] {
        let request: NSFetchRequest<CarryOverSource> = CarryOverSource.fetchRequest()
        request.predicate = NSPredicate(format: "reason == %@ AND date >= %@ AND date < %@",
                                        CarryOverReason.debtTransfer.rawValue,
                                        Calendar.current.startOfDay(for: from) as NSDate,
                                        to as NSDate)
        return (try? context.fetch(request)) ?? []
    }

    /// 부채 잔액을 원장 기준으로 즉시 맞춘다.
    /// - Returns: 실제로 값이 바뀌었으면 `true`
    @discardableResult
    func reconcileDebtNow(now: Date = Date()) -> Bool {
        guard let debt = fetchActiveDebtEntity(), let fixed = reconciledDebt(now: now) else { return false }
        let before = Int(truncating: debt.remainingAmount ?? 0)
        guard fixed.remaining != before else { return false }

        DebugLogger.log("🧮 부채 잔액 보정: \(before) → \(fixed.remaining)")
        debt.remainingAmount = NSDecimalNumber(value: fixed.remaining)
        debt.originalAmount = NSDecimalNumber(value: fixed.original)
        if fixed.remaining == 0 { debt.completedAt = Calendar.current.startOfDay(for: now) }
        return saveContext()
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

    /// 부채 하나의 갚기 여정 — 시작(첫 초과)부터 상환·완납까지를 시간순으로 조립한다.
    ///
    /// 새 저장소 없이 기존 원장에서 만든다: 전환 크레딧(`debtTransfer`)이 "부채가 늘어난 날",
    /// `DebtRepaymentEntry`가 "갚은 날"이다. 구간은 `startedAt` ~ `completedAt`(없으면 오늘).
    func fetchDebtTimeline(for debt: SpendingDebtModel, now: Date = Date()) -> DebtTimeline {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: debt.startedAt)
        let last = calendar.startOfDay(for: debt.completedAt ?? now)
        let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last

        var events: [DebtTimelineEvent] = debtTransferCredits(from: start, to: end).map {
            .overspend(id: $0.id ?? UUID(),
                       date: calendar.startOfDay(for: $0.date ?? start),
                       amount: Int(truncating: $0.amount ?? 0))
        }
        events += repaymentEntries(of: debt.id).map { .repayment($0) }

        // 같은 날이면 "넘긴 것"을 먼저 — 그날 부채가 늘고 나서 갚은 순서가 자연스럽다
        events.sort {
            $0.date == $1.date ? $0.signedAmount > $1.signedAmount : $0.date < $1.date
        }
        return DebtTimeline(debt: debt, events: events)
    }

    /// 특정 부채에 달린 상환 원장 (오래된 순)
    private func repaymentEntries(of debtId: UUID) -> [DebtRepaymentEntryModel] {
        let request: NSFetchRequest<DebtRepaymentEntry> = DebtRepaymentEntry.fetchRequest()
        request.predicate = NSPredicate(format: "debt.id == %@", debtId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        return ((try? context.fetch(request)) ?? []).map(DebtRepaymentEntryModel.init)
    }

    /// 다 갚은 초과분 이력 (최근 완납순).
    /// 갚고 나면 활성 부채가 사라져 "예전에 얼마나 넘겼는지"를 볼 방법이 없어진다.
    func fetchCompletedDebts(limit: Int = 20) -> [SpendingDebtModel] {
        let request: NSFetchRequest<SpendingDebt> = SpendingDebt.fetchRequest()
        request.predicate = NSPredicate(format: "completedAt != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        request.fetchLimit = limit
        return ((try? context.fetch(request)) ?? []).map(SpendingDebtModel.init)
    }

    /// 전날 잔액 중 부채로 전환할 초과 금액. 0이면 기존대로 음수 이월한다.
    /// - 기능이 꺼져 있거나 초과분이 임계값(기본 예산 10%) 미만이면 전환하지 않는다.
    private func overspendToConvert(prevBudget: DailyBudgetModel?, prevBalance: Int,
                                    dailyBudget: Int, config: BudgetConfigModel) -> Int {
        guard config.debtPlanEnabled, prevBalance < 0 else { return 0 }
        let threshold = DebtRepaymentPlan.threshold(dailyBudget: dailyBudget)
        guard threshold > 0 else { return 0 }
        let overspend = convertibleOverspend(of: prevBudget, deficit: -prevBalance)
        return overspend >= threshold ? overspend : 0
    }

    /// 적자 중 **부채로 옮길 수 있는 금액** — 그날 소비가 배정을 넘긴 만큼만.
    ///
    /// 잔액(`todayAvailable`)은 저축·투자 이동과 위시 저금까지 빼고 계산된다.
    /// 그 적자까지 부채로 옮기면 "500만원 투자한 날"이 갚아야 할 빚이 되고,
    /// 그런 날은 '초과한 날' 목록에 뜨지 않으므로 '아직 갚는 중' 금액이 목록 합계와 어긋난다.
    /// 초과 판정과 같은 기준(`OverspendAnalyzer`)을 쓰면 두 숫자가 항상 맞는다.
    ///
    /// 모은 돈이 만든 적자는 부채가 되지 않을 뿐, 음수 이월로는 그대로 남아 다음 날 예산을 줄인다.
    /// - Parameter deficit: 전날 잔액의 적자분 (양수)
    /// - Note: 전날 기록이 없으면(예전 버전에서 넘어온 적자) 판단 근거가 없어 적자 전액을 옮긴다.
    private func convertibleOverspend(of budget: DailyBudgetModel?, deficit: Int) -> Int {
        guard let budget else { return deficit }
        return min(deficit, OverspendAnalyzer.evaluate(budget).overspent)
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

    /// 그날 이미 "매일 상환"이 있었는지 (멱등성 가드).
    /// 풀 상환·급여일 흡수·조기 완납은 매일 상환을 대체하지 않으므로 제외한다.
    private func hasRepayment(on day: Date) -> Bool {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        let request: NSFetchRequest<DebtRepaymentEntry> = DebtRepaymentEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND source == %@",
                                        day as NSDate, end as NSDate,
                                        DebtRepaymentSource.daily.rawValue)
        request.fetchLimit = 1
        return ((try? context.fetch(request).first) ?? nil) != nil
    }

    /// 부채에 상환 원장을 남기고 잔액을 줄인다. 잔액이 0이 되면 완납 처리한다.
    private func recordRepayment(_ amount: Int, on day: Date,
                                 source: DebtRepaymentSource, debt: SpendingDebt) {
        let entry = DebtRepaymentEntry(context: context)
        entry.id = UUID()
        entry.date = day
        entry.amount = NSDecimalNumber(value: amount)
        entry.source = source.rawValue
        entry.debt = debt
        debt.addToRepayments(entry)

        let remaining = Int(truncating: debt.remainingAmount ?? 0) - amount
        debt.remainingAmount = NSDecimalNumber(value: max(0, remaining))
        if remaining <= 0 { debt.completedAt = day }
    }

    /// 모아둔 이월금으로 초과분을 갚는다.
    /// 오늘 예산은 건드리지 않는다 — 풀과 부채 모두 같은 예산 흐름에 대한 장부라 그대로 상계된다.
    @discardableResult
    func repayDebtFromPool(amount: Int) -> Bool {
        guard amount > 0, amount <= carryOverPoolBalance() else { return false }
        guard let debt = fetchActiveDebtEntity() else { return false }
        let remaining = Int(truncating: debt.remainingAmount ?? 0)
        guard remaining > 0, amount <= remaining else { return false }

        let today = Calendar.current.startOfDay(for: Date())

        addPoolEntry(amount: -amount, date: today, reason: .debtRepay)
        recordRepayment(amount, on: today, source: .pool, debt: debt)
        return saveContext()
    }

    /// 모아둔 이월금으로 갚을 수 있는 최대 금액 (풀 잔액과 남은 부채 중 작은 쪽)
    func maxRepayableFromPool() -> Int {
        guard let debt = fetchActiveDebt(), debt.isActive else { return 0 }
        return max(0, min(carryOverPoolBalance(), debt.remainingAmount))
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

        addCarryOverSource(to: budget, amount: -amount, date: day, toDate: day, reason: .debtRepay)

        recordRepayment(amount, on: day, source: .daily, debt: debt)
        _ = saveContext()
    }

    /// 이미 생성된 날짜에 남아 있는 "전날에서 넘어온 큰 음수 이월"을 부채로 전환한다.
    ///
    /// 상환 계획 기능이 없던 버전에서 적자가 쌓인 채 업데이트한 경우, 일자 전환 시점에만 전환하면
    /// 하루 동안 계속 "오늘 쓸 수 있는 금액 −29만원" 같은 화면을 보게 된다. 앱 진입 시 즉시 정리한다.
    ///
    /// 오늘 발생한 크레딧·차감(이월금 인출, 환급, 상환 — `date == 그날`)은 건드리지 않는다.
    private func convertExistingDeficitToDebt(on date: Date, config: BudgetConfigModel) {
        guard config.debtPlanEnabled else { return }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard let budget = fetchDailyBudgetEntity(date: day) else { return }

        let deficit = carryOverSources(of: budget, reason: .carryOver)
            .reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }              // 음수면 적자
        // 이미 부채로 옮긴 만큼은 빼고 본다 — 여러 번 호출돼도 같은 적자를 다시 옮기지 않는다
        let transferred = carryOverSources(of: budget, reason: .debtTransfer)
            .reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
        let net = deficit + transferred
        guard net < 0 else { return }

        // 이 적자를 만든 건 전날이므로 전날 기준으로 "소비 초과분"만 옮긴다
        let prevDay = calendar.date(byAdding: .day, value: -1, to: day)!
        let convertible = convertibleOverspend(of: fetchDailyBudgetModel(date: prevDay), deficit: -net)

        let base = Int(truncating: budget.availableAmount ?? 0)
        let threshold = DebtRepaymentPlan.threshold(dailyBudget: base)
        guard threshold > 0, convertible >= threshold else { return }

        // 음수 이월을 지우는 대신 상쇄 크레딧을 남긴다 (이월 체인 재계산 시 이중 계상 방지)
        addCarryOverSource(to: budget, amount: convertible, date: day, toDate: day,
                           reason: .debtTransfer)
        _ = saveContext()

        addToDebt(amount: convertible, on: day)
    }

    /// `date`가 급여 기간 시작일(실효 급여일)이면, 남은 부채를 그 기간 예산으로 흡수하고 부채를 종료한다.
    ///
    /// 부채를 계속 이월하면 사용자가 평소 씀씀이를 유지하는 한 상환액과 재초과분이 상쇄되어
    /// 부채가 영원히 줄지 않는다. 급여일마다 남은 부채를 새 기간 예산에 녹여 하루 예산을 낮추면
    /// 페널티는 유지되면서 부채는 반드시 정산된다.
    ///
    /// - Returns: 흡수가 일어나 config를 다시 읽어야 하면 `true`
    @discardableResult
    private func absorbDebtIfPayday(on date: Date,
                                    config: BudgetConfigModel,
                                    installments: [InstallmentModel]) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)

        // 급여일 정산은 급여 기간이 있는 모드에서만 의미가 있다.
        // 총액 모드는 기간이 한 번뿐이고, 하루 직접 설정 모드는 기간 개념 자체가 없다.
        guard config.budgetMode.hasPayPeriod else { return false }
        let period = DailyBudgetCalculator.payPeriod(payday: config.payday, containing: day)

        guard config.debtPlanEnabled,
              calendar.isDate(period.start, inSameDayAs: day),
              isPendingPeriodAbsorption(config: config, on: day) else { return false }

        // 모아둔 이월금이 있으면 "먼저 갚을까요?"를 물어야 하므로 흡수를 보류한다.
        // 사용자가 답하면 resolvePaydayAbsorption(usingPool:)이 이어서 처리한다.
        guard carryOverPoolBalance() <= 0 else { return false }

        return performPaydayAbsorption(on: date, config: config, installments: installments)
    }

    /// `date`가 속한 급여 기간의 부채 정산이 아직 남아 있는지.
    ///
    /// 급여일 당일만 보지 않는다 — 급여일에 앱을 안 열었거나 이월금 사용 여부를 묻느라 보류됐다면
    /// 기간 중 언제 들어와도 정산할 수 있어야 한다.
    /// 다만 **이번 기간에 새로 생긴 부채는 대상이 아니다** (그건 나눠 갚기로 처리한다).
    /// 급여일 전날 초과분은 급여일에 부채가 만들어지므로 `startedAt <= period.start`로 판정한다.
    private func isPendingPeriodAbsorption(config: BudgetConfigModel, on date: Date) -> Bool {
        guard config.budgetMode.hasPayPeriod else { return false }
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let period = DailyBudgetCalculator.payPeriod(payday: config.payday, containing: day)

        // 같은 기간에 이미 흡수했으면 중복 처리하지 않는다 (멱등성)
        if let absorbed = config.absorbedDebtPeriodStart,
           calendar.isDate(absorbed, inSameDayAs: period.start) { return false }

        guard let debt = fetchActiveDebt(), debt.isActive, debt.remainingAmount > 0 else { return false }
        return calendar.startOfDay(for: debt.startedAt) <= period.start
    }

    /// "모아둔 이월금으로 먼저 갚을지" 물어봐야 하는 상태인지 (홈 프롬프트용)
    func needsPaydayAbsorptionPrompt() -> Bool {
        guard let config = fetchBudgetConfig(), config.debtPlanEnabled else { return false }
        return isPendingPeriodAbsorption(config: config, on: Date()) && carryOverPoolBalance() > 0
    }

    /// 급여일 프롬프트의 사용자 선택을 반영한다.
    /// - Parameter usingPool: true면 모아둔 이월금으로 먼저 갚고 남은 부채만 흡수한다.
    @discardableResult
    func resolvePaydayAbsorption(usingPool: Bool) -> Bool {
        guard let config = fetchBudgetConfig(), config.debtPlanEnabled,
              isPendingPeriodAbsorption(config: config, on: Date()) else { return false }

        if usingPool {
            let amount = maxRepayableFromPool()
            if amount > 0 { _ = repayDebtFromPool(amount: amount) }
            // 풀로 완납됐으면 흡수할 부채가 없다
            guard let debt = fetchActiveDebt(), debt.isActive, debt.remainingAmount > 0 else {
                return true
            }
        }

        guard let refreshed = fetchBudgetConfig() else { return false }
        let ok = performPaydayAbsorption(on: Date(), config: refreshed,
                                         installments: fetchInstallments())
        // 흡수로 이번 기간 기본 예산이 바뀌었으므로 오늘 일자에 반영한다
        if ok { recalculateTodayBaseBudget() }
        return ok
    }

    private func performPaydayAbsorption(on date: Date,
                                         config: BudgetConfigModel,
                                         installments: [InstallmentModel]) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let period = DailyBudgetCalculator.payPeriod(payday: config.payday, containing: day)

        guard let debt = fetchActiveDebtEntity() else { return false }
        let remaining = Int(truncating: debt.remainingAmount ?? 0)
        guard remaining > 0 else { return false }

        // 하루 예산이 음수가 되지 않도록 이번 기간이 감당할 수 있는 만큼만 흡수한다.
        // 남은 부채는 그대로 두고 다음 급여일에 다시 흡수를 시도한다.
        let absorbable = max(0, DailyBudgetCalculator.absorbableSalary(
            from: config, installments: installments, for: day))
        let absorbed = min(remaining, absorbable)
        guard absorbed > 0 else { return false }

        guard let entity = fetchBudgetConfigEntity() else { return false }
        entity.absorbedDebtAmount = Int32(absorbed)
        entity.absorbedDebtPeriodStart = period.start

        recordRepayment(absorbed, on: day, source: .absorbed, debt: debt)
        return saveContext()
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

    /// 남은 초과분을 할부로 전환한다 — 여행처럼 "의도한 큰 지출"용 출구.
    ///
    /// 조기 완납(`settleDebtImmediately`)과 달리 **오늘 예산에서 빼지 않는다.** 대신 할부가
    /// 앞으로 몇 달간 하루 예산을 조금씩 낮춘다. 하루 예산의 20%씩 갚는 것보다 부담이 낮고,
    /// "잘못 썼으니 갚는다"가 아니라 "계획적으로 나눈다"는 성격에 맞는다.
    /// - Returns: 활성 부채가 없거나 개월 수가 유효하지 않으면 `false`
    @discardableResult
    func convertDebtToInstallment(months: Int, title: String = "초과분 분할") -> Bool {
        guard months > 0, let debt = fetchActiveDebtEntity() else { return false }
        let remaining = Int(truncating: debt.remainingAmount ?? 0)
        guard remaining > 0 else { return false }

        let today = Calendar.current.startOfDay(for: Date())
        let comps = Calendar.current.dateComponents([.year, .month], from: today)
        guard let year = comps.year, let month = comps.month else { return false }

        guard createInstallment(InstallmentModel(title: title, totalAmount: remaining,
                                                 months: months,
                                                 startYear: year, startMonth: month)) else {
            return false
        }

        recordRepayment(remaining, on: today, source: .installment, debt: debt)
        guard saveContext() else { return false }
        // 할부가 오늘부터 하루 예산에 반영되도록 기본 예산을 다시 계산한다
        _ = recalculateTodayBaseBudget()
        return true
    }

    /// 남은 부채를 오늘 예산에서 한 번에 차감하고 종료한다 (조기 완납 / 기능 OFF 전환).
    @discardableResult
    func settleDebtImmediately() -> Bool {
        guard let debt = fetchActiveDebtEntity() else { return false }
        let remaining = Int(truncating: debt.remainingAmount ?? 0)
        let today = Calendar.current.startOfDay(for: Date())

        if remaining > 0, let budget = fetchOrCreateDailyBudgetEntity(date: today) {
            addCarryOverSource(to: budget, amount: -remaining, date: today, toDate: today,
                               reason: .debtRepay)

            recordRepayment(remaining, on: today, source: .settle, debt: debt)
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

    /// 최근 `days`일의 하루 평균 소비. 오늘은 아직 진행 중이라 제외한다.
    /// (상환 속도가 부채를 줄이기에 충분한지 판단하는 데 쓴다)
    func recentAverageDailySpending(days: Int = 7) -> Int {
        guard days > 0 else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }

        let records = fetchSpendingRecords(from: start, to: today)
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.amount } / days
    }

    /// 오늘 일자의 기본 예산만 현재 설정 기준으로 다시 계산한다.
    /// (급여일 흡수처럼 기간 예산이 바뀌었을 때 오늘 화면에 즉시 반영하기 위해)
    @discardableResult
    func recalculateTodayBaseBudget() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        guard let config = fetchBudgetConfig(),
              let budget = fetchDailyBudgetEntity(date: today) else { return false }
        let base = DailyBudgetCalculator.calculate(from: config, installments: fetchInstallments(), for: today)
        budget.availableAmount = NSDecimalNumber(value: base)
        return saveContext()
    }

    /// 최근 `months`개월 상환 내역 (최신순). 완납된 부채의 기록도 함께 나온다.
    func fetchDebtRepayments(months: Int = 3, now: Date = Date()) -> [DebtRepaymentEntryModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .month, value: -months, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let request: NSFetchRequest<DebtRepaymentEntry> = DebtRepaymentEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map(DebtRepaymentEntryModel.init)
    }

    /// 오늘 하루 예산에서 차감된 상환액 (홈의 "초과분 상환" 행 표시용).
    /// 풀 상환·급여일 흡수는 오늘 예산을 건드리지 않으므로 제외한다.
    func todayDebtRepaymentAmount() -> Int {
        todayRepaymentAmount(sources: [.daily, .settle])
    }

    /// 오늘 모아둔 이월금으로 갚은 금액 (홈 안내 표시용)
    func todayPoolRepaymentAmount() -> Int {
        todayRepaymentAmount(sources: [.pool])
    }

    private func todayRepaymentAmount(sources: [DebtRepaymentSource]) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let request: NSFetchRequest<DebtRepaymentEntry> = DebtRepaymentEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND source IN %@",
                                        today as NSDate, end as NSDate, sources.map(\.rawValue))
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

    /// 모아둔 이월금 풀에 적립한다 (일자 전환 시 남은 양수 / 테스트 시드용)
    func depositToPool(amount: Int, date: Date, reason: CarryOverPoolReason = .deposit) {
        guard amount > 0 else { return }
        addPoolEntry(amount: amount, date: date, reason: reason)
        _ = saveContext()
    }

    /// 풀에서 오늘 예산으로 꺼내 쓴다. 오늘 이월(+) 추가 + 풀 인출(−). 잔액 초과 불가.
    /// - Parameter reason: 왜 꺼냈는지. 원장에 남아 나중에 사용 내역으로 볼 수 있다.
    @discardableResult
    func withdrawFromPool(amount: Int, reason: CarryOverPoolReason = .withdraw) -> Bool {
        guard amount > 0, amount <= carryOverPoolBalance() else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        guard let budget = fetchOrCreateDailyBudgetEntity(date: today) else { return false }

        addCarryOverSource(to: budget, amount: amount, date: today, toDate: today,
                           reason: .poolWithdraw)

        addPoolEntry(amount: -amount, date: today, reason: reason)
        return saveContext()
    }

    /// 원장 한 줄 추가 (저장은 호출자가 한다)
    private func addPoolEntry(amount: Int, date: Date, reason: CarryOverPoolReason) {
        let entry = CarryOverPoolEntry(context: context)
        entry.id = UUID()
        entry.date = date
        entry.amount = NSDecimalNumber(value: amount)
        entry.reason = reason.rawValue
    }

    /// 최근 `months`개월 모아둔 이월금 원장 (최신순)
    func fetchPoolEntries(months: Int = 3, now: Date = Date()) -> [CarryOverPoolEntryModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .month, value: -months, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let request: NSFetchRequest<CarryOverPoolEntry> = CarryOverPoolEntry.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map(CarryOverPoolEntryModel.init)
    }

    // MARK: - 저축·투자 (이동)

    /// 저축·투자 기록을 추가한다.
    /// SpendingRecord를 만들지 않으므로 소비 통계·초과한 날 판정에 잡히지 않고,
    /// DailyBudget에 달린 관계로만 오늘 예산에서 차감된다 (위시 저금과 같은 구조).
    @discardableResult
    func createAssetTransfer(_ model: AssetTransferModel) -> Bool {
        guard model.amount > 0 else { return false }
        let day = Calendar.current.startOfDay(for: model.date)
        guard let budget = fetchOrCreateDailyBudgetEntity(date: day) else { return false }

        let transfer = AssetTransfer(context: context)
        transfer.id = model.id
        transfer.date = model.date
        transfer.amount = NSDecimalNumber(value: model.amount)
        transfer.title = model.title
        transfer.kind = model.kind.rawValue
        transfer.dailyBudget = budget
        budget.addToAssetTransfers(transfer)

        return saveContext()
    }

    @discardableResult
    func deleteAssetTransfer(id: UUID) -> Bool {
        let request: NSFetchRequest<AssetTransfer> = AssetTransfer.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        guard let entity = try? context.fetch(request).first else { return false }
        context.delete(entity)
        return saveContext()
    }

    /// 특정 날짜의 저축·투자 기록 (최신순)
    func fetchAssetTransfers(date: Date) -> [AssetTransferModel] {
        let day = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        return fetchAssetTransfers(from: day, to: end)
    }

    /// 기간 내 저축·투자 기록 (최신순). `[from, to)` 반개구간.
    func fetchAssetTransfers(from startDate: Date, to endDate: Date) -> [AssetTransferModel] {
        let request: NSFetchRequest<AssetTransfer> = AssetTransfer.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@",
                                        startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map(AssetTransferModel.init)
    }

    /// 그 달의 저축·투자 집계
    func assetTransferSummary(year: Int, month: Int) -> AssetTransferSummary {
        let calendar = Calendar.current
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return AssetTransferSummary()
        }
        return AssetTransferSummary.make(from: fetchAssetTransfers(from: start, to: end))
    }

    /// 오늘 저축·투자로 옮긴 금액 (홈 표시용)
    func todayAssetTransferAmount() -> Int {
        fetchAssetTransfers(date: Date()).reduce(0) { $0 + $1.amount }
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
