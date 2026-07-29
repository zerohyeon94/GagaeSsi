//
//  BudgetModels.swift
//  GagaeSsi
//
//  예산 관련 모델들
//

import Foundation

// MARK: - 이월 방식
enum CarryOverMode: String, Codable {
    /// 전날 잔액(±) 전액을 다음날 오늘 예산에 반영 (기본, 기존 동작)
    case full
    /// 남은 양수는 '모아둔 이월금' 풀로 적립(오늘 예산 미포함), 음수(과소비)만 다음날 이월(페널티)
    case separate

    static func from(_ raw: String?) -> CarryOverMode {
        CarryOverMode(rawValue: raw ?? "") ?? .full
    }

    var label: String {
        switch self {
        case .full: return "전액 이월"
        case .separate: return "모아둔 이월금으로 분리"
        }
    }
}

// MARK: - 예산 설정 모델
struct BudgetConfigModel: Equatable, Codable, Identifiable {
    var id: UUID = UUID()
    var salary: Int
    var payday: Int
    var fixedCosts: [FixedCostModel]
    var carryOverMode: CarryOverMode

    // MARK: - Initializer
    /// 일반 생성자
    init(salary: Int, payday: Int, fixedCosts: [FixedCostModel], carryOverMode: CarryOverMode = .full) {
        self.salary = salary
        self.payday = payday
        self.fixedCosts = fixedCosts
        self.carryOverMode = carryOverMode
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: BudgetConfig) {
        self.salary = Int(truncating: entity.salary ?? 0)
        self.payday = Int(truncating: entity.payday ?? 0)
        let costs = entity.fixedCosts?.allObjects as? [FixedCost] ?? []
        self.fixedCosts = costs.map(FixedCostModel.init)
        self.carryOverMode = CarryOverMode.from(entity.carryOverMode)
    }
}

// MARK: - 고정비 모델
struct FixedCostModel: Equatable, Codable, Identifiable {
    var id: UUID
    var title: String
    /// 변동형은 "현재 예상액(= 마지막 확정액)". 고정형은 고정 월액.
    var amount: Int
    /// 변동 고정비 여부 (관리비/금리/환율 등 매달 금액이 달라지는 항목)
    var isVariable: Bool
    /// 지출일 (1~31, 0=미설정). 변동형의 월별 확정·알림 기준일.
    var dueDay: Int

    // MARK: - Initializer
    init(id: UUID = UUID(), title: String, amount: Int,
         isVariable: Bool = false, dueDay: Int = 0) {
        self.id = id
        self.title = title
        self.amount = amount
        self.isVariable = isVariable
        self.dueDay = dueDay
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: FixedCost) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.amount = Int(truncating: entity.amount ?? 0)
        self.isVariable = entity.isVariable
        self.dueDay = Int(entity.dueDay)
    }
}

// MARK: - 변동 고정비 월별 확정 금액 모델
struct MonthlyFixedCostEntryModel: Identifiable {
    var id: UUID
    var year: Int
    var month: Int
    var amount: Int
    var confirmedAt: Date

    init(id: UUID = UUID(), year: Int, month: Int, amount: Int, confirmedAt: Date = Date()) {
        self.id = id
        self.year = year
        self.month = month
        self.amount = amount
        self.confirmedAt = confirmedAt
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: MonthlyFixedCostEntry) {
        self.id = entity.id ?? UUID()
        self.year = Int(entity.year)
        self.month = Int(entity.month)
        self.amount = Int(truncating: entity.amount ?? 0)
        self.confirmedAt = entity.confirmedAt ?? Date()
    }
}

// MARK: - 날짜별 예산 모델
struct DailyBudgetModel: Identifiable {
    var id: UUID = UUID()
    var availableAmount: Int
    var date: Date
    var carryOverSources: [CarryOverSourceModel]
    var spendingRecords: [SpendingRecordModel]
    /// 그날 위시리스트에 저금한 금액 합계 (오늘 가용 금액에서 차감)
    var wishSavingAmount: Int

    // 실제 오늘 쓸 수 있는 총 금액
    var todayAvailable: Int {
        let carry = carryOverSources.map { $0.amount }.reduce(0, +)
        let spent = spendingRecords.map { $0.amount }.reduce(0, +)
        return availableAmount + carry - spent - wishSavingAmount
    }

    // MARK: - Initializer
    init(availableAmount: Int, date: Date, carryOverSources: [CarryOverSourceModel],
         spendingRecords: [SpendingRecordModel], wishSavingAmount: Int = 0) {
        self.availableAmount = availableAmount
        self.date = date
        self.carryOverSources = carryOverSources
        self.spendingRecords = spendingRecords
        self.wishSavingAmount = wishSavingAmount
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: DailyBudget) {
        self.availableAmount = Int(truncating: entity.availableAmount ?? 0)
        self.date = entity.date ?? Date()

        let sources = entity.carryOverSources?.allObjects as? [CarryOverSource] ?? []
        self.carryOverSources = sources.map(CarryOverSourceModel.init)

        let records = entity.spendingRecords?.allObjects as? [SpendingRecord] ?? []
        self.spendingRecords = records.map(SpendingRecordModel.init)

        let savings = entity.wishSavingEntries?.allObjects as? [WishSavingEntry] ?? []
        self.wishSavingAmount = savings.reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
    }
}

// MARK: - 이월 금액 모델
struct CarryOverSourceModel: Identifiable {
    var id: UUID
    var amount: Int
    var date: Date      // 남은 금액이 발생한 날짜
    var toDate: Date    // 이월된 날짜 (다음날)
    
    init(id: UUID = UUID(), amount: Int, date: Date, toDate: Date) {
        self.id = id
        self.amount = amount
        self.date = date
        self.toDate = toDate
    }
    
    init(entity: CarryOverSource) {
        self.id = entity.id ?? UUID()
        self.amount = Int(truncating: entity.amount ?? 0)
        self.date = entity.date ?? Date()
        self.toDate = entity.toDate ?? Date()
    }
}

// MARK: - 소비 기록 모델
struct SpendingRecordModel: Identifiable {
    var id: UUID
    var title: String
    var amount: Int
    var date: Date
    var category: SpendingCategory

    init(id: UUID = UUID(), title: String, amount: Int, date: Date, category: SpendingCategory = .other) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: SpendingRecord) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.amount = Int(truncating: entity.amount ?? 0)
        self.date = entity.date ?? Date()
        self.category = SpendingCategory.from(rawValue: entity.category)
    }
}
