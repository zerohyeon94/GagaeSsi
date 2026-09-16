//
//  CoreDataMigrationTests.swift
//  GagaeSsi
//
//  GagaeSsi 2 → 3 lightweight migration 검증.
//  인메모리 스토어는 마이그레이션 경로를 타지 않으므로, 임시 SQLite 파일에
//  구버전 모델로 데이터를 쓴 뒤 현재 모델로 다시 열어 확인한다.
//

import XCTest
import CoreData
@testable import GagaeSsi

final class CoreDataMigrationTests: XCTestCase {
    private var storeURL: URL!

    override func setUpWithError() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            try? FileManager.default.removeItem(at: url)
        }
        storeURL = nil
    }

    // MARK: - Helpers

    /// 앱 번들의 momd에서 특정 버전 모델을 로드한다.
    private func model(named version: String) throws -> NSManagedObjectModel {
        let bundle = Bundle(for: CoreDataManager.self)
        let momdURL = try XCTUnwrap(bundle.url(forResource: "GagaeSsi", withExtension: "momd"),
                                    "GagaeSsi.momd를 찾을 수 없다")
        let momURL = momdURL.appendingPathComponent("\(version).mom")
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: momURL),
                             "\(version).mom을 로드할 수 없다")
    }

    /// 현재 모델(.xccurrentversion). 버전을 올릴 때마다 테스트를 고치지 않도록 momd에서 읽는다.
    ///
    /// `BudgetConfigModel(entity:)` 같은 변환 생성자는 **최신 속성을 모두 읽으므로**
    /// 구버전 모델로 연 스토어에 쓰면 예외가 난다. 변환을 검증하는 테스트는 이걸 쓴다.
    private func currentModel() throws -> NSManagedObjectModel {
        let bundle = Bundle(for: CoreDataManager.self)
        let momdURL = try XCTUnwrap(bundle.url(forResource: "GagaeSsi", withExtension: "momd"))
        let info = NSDictionary(contentsOf: momdURL.appendingPathComponent("VersionInfo.plist"))
        let version = try XCTUnwrap(info?["NSManagedObjectModel_CurrentVersionName"] as? String,
                                    "momd에서 현재 버전 이름을 찾을 수 없다")
        return try model(named: version)
    }

    /// 지정한 모델로 스토어를 열고 컨테이너를 반환한다 (lightweight migration 켬).
    private func container(with model: NSManagedObjectModel) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "GagaeSsi", managedObjectModel: model)
        let desc = NSPersistentStoreDescription(url: storeURL)
        desc.shouldMigrateStoreAutomatically = true
        desc.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [desc]

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container
    }

    private func unload(_ container: NSPersistentContainer) throws {
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }

    // MARK: - Tests

    func test_GagaeSsi2에서_3으로_lightweight_migration이_성공한다() throws {
        // 1) 구버전(GagaeSsi 2) 모델로 스토어를 만들고 기존 사용자 데이터를 쓴다
        let oldContainer = try container(with: try model(named: "GagaeSsi 2"))
        let oldContext = oldContainer.viewContext

        let config = NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig", into: oldContext)
        config.setValue(NSDecimalNumber(value: 3_000_000), forKey: "salary")
        config.setValue(NSDecimalNumber(value: 25), forKey: "payday")
        config.setValue("separate", forKey: "carryOverMode")

        let record = NSEntityDescription.insertNewObject(forEntityName: "SpendingRecord", into: oldContext)
        record.setValue(UUID(), forKey: "id")
        record.setValue("점심", forKey: "title")
        record.setValue(NSDecimalNumber(value: 12_000), forKey: "amount")
        record.setValue(Date(), forKey: "date")

        try oldContext.save()
        try unload(oldContainer)

        // 2) 현재 모델(GagaeSsi 3)로 같은 스토어를 다시 연다 → 마이그레이션 발생
        let newContainer = try container(with: try model(named: "GagaeSsi 3"))
        let newContext = newContainer.viewContext

        // 3) 기존 데이터가 보존되는지
        let configs = try newContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "BudgetConfig"))
        XCTAssertEqual(configs.count, 1)
        let migrated = try XCTUnwrap(configs.first)
        XCTAssertEqual(migrated.value(forKey: "salary") as? NSDecimalNumber, NSDecimalNumber(value: 3_000_000))
        XCTAssertEqual(migrated.value(forKey: "carryOverMode") as? String, "separate",
                       "기존 이월 방식 설정이 보존되어야 한다")

        let records = try newContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "SpendingRecord"))
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.value(forKey: "title") as? String, "점심")

        // 4) 신규 속성이 설계한 기본값으로 채워지는지
        XCTAssertEqual(migrated.value(forKey: "debtPlanEnabled") as? Bool, true,
                       "상환 계획은 기본 ON이어야 한다")
        XCTAssertEqual(migrated.value(forKey: "spendReminderEnabled") as? Bool, false,
                       "리마인더 알림은 기본 OFF여야 한다")

        // 5) 신규 엔티티가 사용 가능한지
        let debt = NSEntityDescription.insertNewObject(forEntityName: "SpendingDebt", into: newContext)
        debt.setValue(UUID(), forKey: "id")
        debt.setValue(NSDecimalNumber(value: 100_000), forKey: "originalAmount")
        debt.setValue(NSDecimalNumber(value: 100_000), forKey: "remainingAmount")
        debt.setValue(Int16(20), forKey: "repayRatePercent")
        debt.setValue(Date(), forKey: "startedAt")

        let entry = NSEntityDescription.insertNewObject(forEntityName: "DebtRepaymentEntry", into: newContext)
        entry.setValue(UUID(), forKey: "id")
        entry.setValue(Date(), forKey: "date")
        entry.setValue(NSDecimalNumber(value: 10_000), forKey: "amount")
        entry.setValue(debt, forKey: "debt")

        XCTAssertNoThrow(try newContext.save(), "신규 엔티티 저장이 가능해야 한다")
        try unload(newContainer)
    }

    /// GagaeSsi 3은 이미 사용자 기기에 설치된 버전이라 in-place 수정이 불가능하다.
    /// (모델 해시가 바뀌면 저장된 스토어의 소스 모델을 못 찾아 앱이 실행 즉시 죽는다)
    func test_GagaeSsi3에서_4로_마이그레이션되고_기존_상환원장은_daily로_남는다() throws {
        let oldContainer = try container(with: try model(named: "GagaeSsi 3"))
        let oldContext = oldContainer.viewContext

        let debt = NSEntityDescription.insertNewObject(forEntityName: "SpendingDebt", into: oldContext)
        debt.setValue(UUID(), forKey: "id")
        debt.setValue(NSDecimalNumber(value: 300_000), forKey: "originalAmount")
        debt.setValue(NSDecimalNumber(value: 280_000), forKey: "remainingAmount")
        debt.setValue(Int16(20), forKey: "repayRatePercent")
        debt.setValue(Date(), forKey: "startedAt")

        let entry = NSEntityDescription.insertNewObject(forEntityName: "DebtRepaymentEntry", into: oldContext)
        entry.setValue(UUID(), forKey: "id")
        entry.setValue(Date(), forKey: "date")
        entry.setValue(NSDecimalNumber(value: 20_000), forKey: "amount")
        entry.setValue(debt, forKey: "debt")

        try oldContext.save()
        try unload(oldContainer)

        let newContainer = try container(with: try model(named: "GagaeSsi 4"))
        let newContext = newContainer.viewContext

        let entries = try newContext.fetch(NSFetchRequest<DebtRepaymentEntry>(entityName: "DebtRepaymentEntry"))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(DebtRepaymentEntryModel(entity: entries[0]).source, .daily,
                       "출처가 없던 기존 원장은 매일 상환으로 해석되어야 한다")

        let debts = try newContext.fetch(NSFetchRequest<SpendingDebt>(entityName: "SpendingDebt"))
        XCTAssertEqual(SpendingDebtModel(entity: debts[0]).remainingAmount, 280_000,
                       "진행 중이던 부채가 보존되어야 한다")

        try unload(newContainer)
    }

    /// GagaeSsi 4는 이미 사용자 기기에 설치된 버전이라 in-place 수정이 불가능하다.
    /// 저축·투자(AssetTransfer)가 들어온 5로 올라가도 기존 기록이 보존되는지.
    /// `DailyBudgetModel(entity:)`가 최신 속성을 모두 읽으므로 최신 모델로 연다
    /// (구버전 모델로 열면 이후 버전에서 추가된 관계를 읽다 예외가 난다).
    func test_GagaeSsi4에서_최신으로_마이그레이션되고_기존_기록이_보존된다() throws {
        let oldContainer = try container(with: try model(named: "GagaeSsi 4"))
        let oldContext = oldContainer.viewContext

        let budget = NSEntityDescription.insertNewObject(forEntityName: "DailyBudget", into: oldContext)
        budget.setValue(NSDecimalNumber(value: 50_000), forKey: "availableAmount")
        budget.setValue(Date(), forKey: "date")

        let record = NSEntityDescription.insertNewObject(forEntityName: "SpendingRecord", into: oldContext)
        record.setValue(UUID(), forKey: "id")
        record.setValue("커피", forKey: "title")
        record.setValue(NSDecimalNumber(value: 4_000), forKey: "amount")
        record.setValue(Date(), forKey: "date")
        record.setValue(budget, forKey: "dailyBudget")

        try oldContext.save()
        try unload(oldContainer)

        let newContainer = try container(with: try currentModel())
        let newContext = newContainer.viewContext

        let budgets = try newContext.fetch(NSFetchRequest<DailyBudget>(entityName: "DailyBudget"))
        XCTAssertEqual(budgets.count, 1)
        let migrated = DailyBudgetModel(entity: budgets[0])
        XCTAssertEqual(migrated.spendingRecords.count, 1, "기존 소비 기록이 보존된다")
        XCTAssertEqual(migrated.transferAmount, 0, "저축·투자는 아직 없으니 0")

        // 신규 엔티티가 사용 가능한지
        let transfer = NSEntityDescription.insertNewObject(forEntityName: "AssetTransfer", into: newContext)
        transfer.setValue(UUID(), forKey: "id")
        transfer.setValue(Date(), forKey: "date")
        transfer.setValue(NSDecimalNumber(value: 100_000), forKey: "amount")
        transfer.setValue("S&P500", forKey: "title")
        transfer.setValue("투자", forKey: "kind")
        transfer.setValue(budgets[0], forKey: "dailyBudget")

        XCTAssertNoThrow(try newContext.save())
        try unload(newContainer)
    }

    /// 아주 오래된 버전(v1)에 머물러 있던 사용자도 현재 버전까지 한 번에 올라와야 한다.
    /// (실패하면 loadPersistentStores가 에러 → 앱은 fatalError로 죽는다)
    func test_최초버전에서_현재버전까지_한번에_마이그레이션된다() throws {
        let oldContainer = try container(with: try model(named: "GagaeSsi"))
        let config = NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig",
                                                         into: oldContainer.viewContext)
        config.setValue(NSDecimalNumber(value: 2_500_000), forKey: "salary")
        config.setValue(NSDecimalNumber(value: 10), forKey: "payday")
        try oldContainer.viewContext.save()
        try unload(oldContainer)

        let newContainer = try container(with: try currentModel())
        let entity = try XCTUnwrap(
            try newContainer.viewContext.fetch(NSFetchRequest<BudgetConfig>(entityName: "BudgetConfig")).first)

        let migrated = BudgetConfigModel(entity: entity)
        XCTAssertEqual(migrated.salary, 2_500_000)
        XCTAssertEqual(migrated.themeMode, .system, "테마는 기본이 기기 설정")
        XCTAssertEqual(migrated.budgetMode, .recurring, "예산 방식은 기본이 정기 수입")
        XCTAssertEqual(migrated.payday, 10)
        XCTAssertTrue(migrated.debtPlanEnabled)
        XCTAssertFalse(migrated.spendReminderEnabled)

        try unload(newContainer)
    }

    /// GagaeSsi 7까지 쓰던 사용자가 테마 설정이 추가된 8로 올라와도 기존 설정이 살아 있어야 한다
    func test_GagaeSsi7에서_8로_마이그레이션되고_테마는_기기설정이_기본() throws {
        let oldContainer = try container(with: try model(named: "GagaeSsi 7"))
        let config = NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig",
                                                         into: oldContainer.viewContext)
        config.setValue(NSDecimalNumber(value: 3_300_000), forKey: "salary")
        config.setValue(NSDecimalNumber(value: 20), forKey: "payday")
        config.setValue("separate", forKey: "carryOverMode")
        try oldContainer.viewContext.save()
        try unload(oldContainer)

        let newContainer = try container(with: try model(named: "GagaeSsi 8"))
        let entity = try XCTUnwrap(
            try newContainer.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "BudgetConfig")).first)

        XCTAssertEqual(entity.value(forKey: "salary") as? NSDecimalNumber,
                       NSDecimalNumber(value: 3_300_000))
        XCTAssertEqual(entity.value(forKey: "carryOverMode") as? String, "separate",
                       "기존 설정이 보존된다")
        XCTAssertEqual(ThemeMode.from(entity.value(forKey: "themeMode") as? String), .system,
                       "테마 값이 비어 있어도 '기기 설정'으로 해석돼야 한다")

        try unload(newContainer)
    }

    /// 8까지 쓰던 사용자는 예산 방식이 비어 있다 → 지금까지와 똑같은 '정기 수입'으로 동작해야 한다
    func test_GagaeSsi8에서_9로_마이그레이션되고_예산방식은_정기수입이_기본() throws {
        let oldContainer = try container(with: try model(named: "GagaeSsi 8"))
        let config = NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig",
                                                         into: oldContainer.viewContext)
        config.setValue(NSDecimalNumber(value: 2_800_000), forKey: "salary")
        config.setValue(NSDecimalNumber(value: 15), forKey: "payday")
        config.setValue("dark", forKey: "themeMode")
        try oldContainer.viewContext.save()
        try unload(oldContainer)

        let newContainer = try container(with: try currentModel())
        let entity = try XCTUnwrap(
            try newContainer.viewContext.fetch(NSFetchRequest<BudgetConfig>(entityName: "BudgetConfig")).first)

        let migrated = BudgetConfigModel(entity: entity)
        XCTAssertEqual(migrated.salary, 2_800_000)
        XCTAssertEqual(migrated.themeMode, .dark, "기존 테마 설정이 보존된다")
        XCTAssertEqual(migrated.budgetMode, .recurring,
                       "예산 방식 값이 비어 있어도 기존 동작(정기 수입)이어야 한다")
        XCTAssertEqual(migrated.totalAmount, 0)
        XCTAssertEqual(migrated.dailyAmount, 0)
        XCTAssertNil(migrated.lumpSumEnd)

        // 기본 일일 예산이 마이그레이션 전과 동일하게 나오는지 (회귀 방지)
        let period = DailyBudgetCalculator.payPeriod(payday: 15, containing: Date())
        let days = Calendar.current.dateComponents([.day], from: period.start, to: period.end).day ?? 0
        XCTAssertEqual(DailyBudgetCalculator.calculate(from: migrated, for: Date()),
                       2_800_000 / days)

        try unload(newContainer)
    }

    func test_마이그레이션_후_BudgetConfigModel_변환이_기본시각을_보정한다() throws {
        // 구버전 스토어 생성 (spendReminderHour가 없으므로 마이그레이션 후 0이 된다)
        let oldContainer = try container(with: try model(named: "GagaeSsi 2"))
        let config = NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig",
                                                         into: oldContainer.viewContext)
        config.setValue(NSDecimalNumber(value: 3_000_000), forKey: "salary")
        config.setValue(NSDecimalNumber(value: 25), forKey: "payday")
        try oldContainer.viewContext.save()
        try unload(oldContainer)

        // 모델 변환(BudgetConfigModel)은 현재 모델의 속성을 모두 읽으므로 최신 버전으로 연다.
        // 구버전으로 열면 나중에 추가된 속성(themeMode 등)이 없어 접근 시 예외가 난다.
        let newContainer = try container(with: try currentModel())
        let entity = try XCTUnwrap(
            try newContainer.viewContext.fetch(NSFetchRequest<BudgetConfig>(entityName: "BudgetConfig")).first)

        let model = BudgetConfigModel(entity: entity)
        XCTAssertFalse(model.spendReminderEnabled)
        XCTAssertEqual(model.spendReminderHour, SpendReminderSchedule.defaultHour,
                       "알림을 켠 적 없는 기존 사용자는 자정이 아니라 기본 시각(21시)으로 보여야 한다")
        XCTAssertEqual(model.spendReminderMinute, SpendReminderSchedule.defaultMinute)
        XCTAssertTrue(model.debtPlanEnabled)

        try unload(newContainer)
    }

    /// 여행 필드가 추가된 12로 올라와도 기존 소비는 "내 개인 소비"로 남아 숫자가 하나도 바뀌지 않아야 한다
    func test_GagaeSsi11에서_12로_마이그레이션되고_기존_소비는_내_몫이_전액이다() throws {
        let oldContainer = try container(with: try model(named: "GagaeSsi 11"))
        let oldContext = oldContainer.viewContext

        let budget = NSEntityDescription.insertNewObject(forEntityName: "DailyBudget", into: oldContext)
        budget.setValue(NSDecimalNumber(value: 50_000), forKey: "availableAmount")
        budget.setValue(Date(), forKey: "date")

        let record = NSEntityDescription.insertNewObject(forEntityName: "SpendingRecord", into: oldContext)
        record.setValue(UUID(), forKey: "id")
        record.setValue("점심", forKey: "title")
        record.setValue(NSDecimalNumber(value: 9_000), forKey: "amount")
        record.setValue(Date(), forKey: "date")
        record.setValue(budget, forKey: "dailyBudget")

        try oldContext.save()
        try unload(oldContainer)

        let newContainer = try container(with: try currentModel())
        let newContext = newContainer.viewContext

        let records = try newContext.fetch(NSFetchRequest<SpendingRecord>(entityName: "SpendingRecord"))
        XCTAssertEqual(records.count, 1)
        // 모델 변환(SpendingRecordModel.init)은 participants에 max(1, ...) 보정을 걸어서,
        // defaultValueString="1"이 모델에서 빠지더라도 이 보정이 0을 1로 감춰버릴 수 있다.
        // 그래서 모델을 거치기 전 원본 엔티티 값을 먼저 직접 확인한다.
        XCTAssertEqual(records[0].participants, 1, "모델의 기본값이 빠지면 0이 되므로 원본 값을 직접 확인한다")
        XCTAssertTrue(records[0].paidByMe)
        let migrated = SpendingRecordModel(entity: records[0])
        XCTAssertNil(migrated.tripId)
        XCTAssertEqual(migrated.participants, 1)
        XCTAssertTrue(migrated.paidByMe)
        XCTAssertEqual(migrated.myShare, 9_000)
        XCTAssertEqual(migrated.budgetAmount, 9_000)
        XCTAssertEqual(migrated.receivable, 0)

        // 신규 Trip 엔티티가 사용 가능한지
        let trip = NSEntityDescription.insertNewObject(forEntityName: "Trip", into: newContext)
        trip.setValue(UUID(), forKey: "id")
        trip.setValue("제주", forKey: "title")
        trip.setValue(Date(), forKey: "startDate")
        trip.setValue(Date(), forKey: "endDate")
        trip.setValue(Int16(3), forKey: "defaultParticipants")
        trip.setValue("진행중", forKey: "status")
        trip.setValue(Date(), forKey: "createdAt")
        records[0].setValue(trip, forKey: "trip")

        XCTAssertNoThrow(try newContext.save())
        try unload(newContainer)
    }
}
