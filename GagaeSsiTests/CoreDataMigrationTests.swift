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
    func test_GagaeSsi4에서_5로_마이그레이션되고_기존_기록이_보존된다() throws {
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

        let newContainer = try container(with: try model(named: "GagaeSsi 5"))
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
    func test_최초버전에서_5까지_한번에_마이그레이션된다() throws {
        let oldContainer = try container(with: try model(named: "GagaeSsi"))
        let config = NSEntityDescription.insertNewObject(forEntityName: "BudgetConfig",
                                                         into: oldContainer.viewContext)
        config.setValue(NSDecimalNumber(value: 2_500_000), forKey: "salary")
        config.setValue(NSDecimalNumber(value: 10), forKey: "payday")
        try oldContainer.viewContext.save()
        try unload(oldContainer)

        let newContainer = try container(with: try model(named: "GagaeSsi 5"))
        let entity = try XCTUnwrap(
            try newContainer.viewContext.fetch(NSFetchRequest<BudgetConfig>(entityName: "BudgetConfig")).first)

        let migrated = BudgetConfigModel(entity: entity)
        XCTAssertEqual(migrated.salary, 2_500_000)
        XCTAssertEqual(migrated.payday, 10)
        XCTAssertTrue(migrated.debtPlanEnabled)
        XCTAssertFalse(migrated.spendReminderEnabled)

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

        let newContainer = try container(with: try model(named: "GagaeSsi 3"))
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
}
