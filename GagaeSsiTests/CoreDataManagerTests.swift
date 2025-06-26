//
//  CoreDataManagerTests.swift
//  GagaeSsi
//
//  Created by 조영현 on 6/25/25.
//

import XCTest
@testable import GagaeSsi

final class CoreDataManagerTests: XCTestCase {
    var sut: CoreDataManager!
    
    // 임의로 쓸 날짜
    let testDate = Calendar.current.startOfDay(for: Date())
    let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
    
    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
    }
    override func tearDownWithError() throws {
        sut = nil
    }
    
    // MARK: - BudgetConfig
    func testBudgetConfig_CRUD() {
        // 생성
        let configModel = BudgetConfigModel(salary: 2000000, payday: 22, fixedCosts: [])
        XCTAssertTrue(sut.createBudgetConfig(from: configModel))
        // 조회
        var fetched = sut.fetchBudgetConfig()
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.salary, 2000000)
        // 수정
        let updated = BudgetConfigModel(salary: 3000000, payday: 25, fixedCosts: [])
        XCTAssertTrue(sut.updateBudgetConfig(updated))
        fetched = sut.fetchBudgetConfig()
        XCTAssertEqual(fetched?.salary, 3000000)
    }
    
    // MARK: - FixedCost
    func testFixedCost_CRUD() {
        // BudgetConfig가 있어야 하므로 생성
        let configModel = BudgetConfigModel(salary: 2000000, payday: 20, fixedCosts: [])
        sut.createBudgetConfig(from: configModel)
        // 생성
        let fixedModel = FixedCostModel(id: UUID(), title: "Rent", amount: 100000)
        XCTAssertTrue(sut.createFixedCost(fixedModel))
        // 조회
        let allFixed = sut.fetchFixedCosts()
        XCTAssertEqual(allFixed.count, 1)
        XCTAssertEqual(allFixed.first?.title, "Rent")
        // 수정
        var toUpdate = allFixed.first!
        toUpdate.title = "UpdatedRent"
        toUpdate.amount = 120000
        XCTAssertTrue(sut.updateFixedCost(toUpdate))
        // 다시 조회
        let updated = sut.fetchFixedCosts().first
        XCTAssertEqual(updated?.title, "UpdatedRent")
        XCTAssertEqual(updated?.amount, 120000)
        // 삭제
        XCTAssertTrue(sut.deleteFixedCost(id: toUpdate.id))
        XCTAssertTrue(sut.fetchFixedCosts().isEmpty)
    }
    
    // MARK: - DailyBudget
    func testDailyBudget_CRUD() {
        // 생성
        let model = DailyBudgetModel(availableAmount: 30000, date: testDate, carryOverSources: [], spendingRecords: [])
        XCTAssertTrue(sut.createDailyBudget(model))
        // 조회
        let fetched = sut.fetchDailyBudgetModel(date: testDate)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.availableAmount, 30000)
        // 수정
        let updated = DailyBudgetModel(availableAmount: 40000, date: testDate, carryOverSources: [], spendingRecords: [])
        XCTAssertTrue(sut.updateDailyBudget(updated))
        let fetched2 = sut.fetchDailyBudgetModel(date: testDate)
        XCTAssertEqual(fetched2?.availableAmount, 40000)
        // (DailyBudget 삭제 미구현이면 생략)
    }
    
    // MARK: - SpendingRecord
    func testSpendingRecord_CRUD() {
        // DailyBudget 생성
        let dbModel = DailyBudgetModel(availableAmount: 25000, date: testDate, carryOverSources: [], spendingRecords: [])
        sut.createDailyBudget(dbModel)
        // 생성
        let spendModel = SpendingRecordModel(id: UUID(), title: "Lunch", amount: 8000, date: testDate)
        XCTAssertTrue(sut.createSpendingRecord(spendModel))
        // 조회
        let allSpend = sut.fetchSpendingRecords(date: testDate)
        XCTAssertEqual(allSpend.count, 1)
        XCTAssertEqual(allSpend.first?.title, "Lunch")
        // 수정
        var toUpdate = allSpend.first!
        toUpdate.title = "LunchUpdated"
        toUpdate.amount = 9000
        XCTAssertTrue(sut.updateSpendingRecord(toUpdate))
        let updated = sut.fetchSpendingRecords(date: testDate).first
        XCTAssertEqual(updated?.title, "LunchUpdated")
        XCTAssertEqual(updated?.amount, 9000)
        // 삭제
        XCTAssertTrue(sut.deleteSpendingRecord(id: toUpdate.id))
        XCTAssertTrue(sut.fetchSpendingRecords(date: testDate).isEmpty)
    }
    
    // MARK: - CarryOverSource
    func testCarryOverSource_CRUD() {
        // DailyBudget 생성
        let dbModel = DailyBudgetModel(availableAmount: 25000, date: testDate, carryOverSources: [], spendingRecords: [])
        sut.createDailyBudget(dbModel)
        // 생성
        let coModel = CarryOverSourceModel(id: UUID(), amount: 5000, date: testDate, toDate: tomorrow)
        XCTAssertTrue(sut.createCarryOverSource(coModel))
        // 조회
        let allCO = sut.fetchCarryOverSources(date: testDate)
        XCTAssertEqual(allCO.count, 1)
        XCTAssertEqual(allCO.first?.amount, 5000)
        // 수정
        var toUpdate = allCO.first!
        toUpdate.amount = 7000
        toUpdate.date = testDate
        toUpdate.toDate = tomorrow
        XCTAssertTrue(sut.updateCarryOverSource(toUpdate))
        let updated = sut.fetchCarryOverSources(date: testDate).first
        XCTAssertEqual(updated?.amount, 7000)
        // 삭제
        XCTAssertTrue(sut.deleteCarryOverSource(id: toUpdate.id))
        XCTAssertTrue(sut.fetchCarryOverSources(date: testDate).isEmpty)
    }
    
    // MARK: - resetAllData
    func testResetAllData_DeletesEverything() {
        let configModel = BudgetConfigModel(salary: 2000000, payday: 22, fixedCosts: [])
        sut.createBudgetConfig(from: configModel)
        let fixedModel = FixedCostModel(id: UUID(), title: "Rent", amount: 100000)
        sut.createFixedCost(fixedModel)
        let dbModel = DailyBudgetModel(availableAmount: 25000, date: testDate, carryOverSources: [], spendingRecords: [])
        sut.createDailyBudget(dbModel)
        let spendModel = SpendingRecordModel(id: UUID(), title: "Lunch", amount: 8000, date: testDate)
        sut.createSpendingRecord(spendModel)
        let coModel = CarryOverSourceModel(id: UUID(), amount: 5000, date: testDate, toDate: tomorrow)
        sut.createCarryOverSource(coModel)
        sut.resetAllData()
        XCTAssertNil(sut.fetchBudgetConfig())
        XCTAssertTrue(sut.fetchFixedCosts().isEmpty)
        XCTAssertNil(sut.fetchDailyBudgetModel(date: testDate))
        XCTAssertTrue(sut.fetchSpendingRecords(date: testDate).isEmpty)
        XCTAssertTrue(sut.fetchCarryOverSources(date: testDate).isEmpty)
    }
}
