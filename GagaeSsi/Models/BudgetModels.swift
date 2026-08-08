//
//  BudgetModels.swift
//  GagaeSsi
//
//  예산 관련 모델들
//

import Foundation
import SwiftUI

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

// MARK: - 예산 모드

/// 기본 일일 예산을 어떻게 산출할지.
///
/// 기존 엔진은 이미 "(금액, 기간) → 기본 일일 예산 + 이월" 구조라, **기본 일일 예산의
/// 산출 방식만 모드화**하면 이월·위시 저금·부채·통계는 그대로 동작한다.
enum BudgetMode: String, Codable, CaseIterable, Identifiable {
    /// 매월 정해진 날 수입이 들어옴 (기존 모델. 월급·용돈 모두 포함)
    case recurring
    /// 모아둔 돈으로 정해진 기간을 버팀 (취준생·수입 중단기)
    case lumpSum
    /// 하루 금액을 직접 정함 (수입 구조를 묻지 않는 최소 폴백)
    case fixedDaily

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recurring: return "정기 수입"
        case .lumpSum: return "모아둔 돈으로 생활"
        case .fixedDaily: return "하루 예산 직접 설정"
        }
    }

    var emoji: String {
        switch self {
        case .recurring: return "💰"
        case .lumpSum: return "🫙"
        case .fixedDaily: return "✏️"
        }
    }

    var summary: String {
        switch self {
        case .recurring: return "매월 정해진 날 들어오는 월급·용돈으로 관리해요"
        case .lumpSum: return "지금 가진 돈으로 언제까지 버틸지 정해요"
        case .fixedDaily: return "수입은 묻지 않고 하루 쓸 금액만 정해요"
        }
    }

    /// 급여일·급여 기간 개념이 있는 모드인지.
    /// 급여일 부채 정산(3-7)은 이 모드에서만 일어난다.
    var hasPayPeriod: Bool { self == .recurring }

    static func from(_ raw: String?) -> BudgetMode {
        BudgetMode(rawValue: raw ?? "") ?? .recurring
    }
}

// MARK: - 테마 모드

/// 앱 테마. 기존 사용자는 라이트 고정에 익숙하므로 직접 고를 수 있게 한다.
enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system   // 기기 설정을 따름
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "기기 설정"
        case .light: return "밝게"
        case .dark: return "어둡게"
        }
    }

    var emoji: String {
        switch self {
        case .system: return "⚙️"
        case .light: return "☀️"
        case .dark: return "🌙"
        }
    }

    /// SwiftUI에 넘길 값. `nil`이면 기기 설정을 따른다.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func from(_ raw: String?) -> ThemeMode {
        ThemeMode(rawValue: raw ?? "") ?? .system
    }
}

// MARK: - 예산 설정 모델
struct BudgetConfigModel: Equatable, Codable, Identifiable {
    var id: UUID = UUID()
    var salary: Int
    var payday: Int
    var fixedCosts: [FixedCostModel]
    var carryOverMode: CarryOverMode
    /// 초과 소비 상환 계획 사용 여부. false면 초과분이 기존처럼 음수 전액 이월된다.
    var debtPlanEnabled: Bool
    /// 소비 기록 리마인더 알림 사용 여부
    var spendReminderEnabled: Bool
    /// 리마인더 알림 시각
    var spendReminderHour: Int
    var spendReminderMinute: Int
    /// 급여일에 새 급여 기간 예산으로 흡수한 부채 금액.
    /// 이 기간의 기본 일일 예산에서 균등 차감된다 (부채가 기간을 넘어 무한히 끌리지 않게).
    var absorbedDebtAmount: Int
    /// 위 금액이 적용되는 급여 기간의 시작일. 다른 기간에는 적용하지 않는다.
    var absorbedDebtPeriodStart: Date?
    /// 앱 테마 (기기 설정 / 밝게 / 어둡게)
    var themeMode: ThemeMode
    /// 예산 산출 방식
    var budgetMode: BudgetMode
    /// 총액 모드: 지금 가진 돈
    var totalAmount: Int
    /// 총액 모드: 버틸 기간 [시작, 종료]
    var lumpSumStart: Date?
    var lumpSumEnd: Date?
    /// 하루 직접 설정 모드: 하루 금액
    var dailyAmount: Int

    // MARK: - Initializer
    /// 일반 생성자
    init(salary: Int, payday: Int, fixedCosts: [FixedCostModel],
         carryOverMode: CarryOverMode = .full,
         debtPlanEnabled: Bool = true,
         spendReminderEnabled: Bool = false,
         spendReminderHour: Int = SpendReminderSchedule.defaultHour,
         spendReminderMinute: Int = SpendReminderSchedule.defaultMinute,
         absorbedDebtAmount: Int = 0,
         absorbedDebtPeriodStart: Date? = nil,
         themeMode: ThemeMode = .system,
         budgetMode: BudgetMode = .recurring,
         totalAmount: Int = 0,
         lumpSumStart: Date? = nil,
         lumpSumEnd: Date? = nil,
         dailyAmount: Int = 0) {
        self.salary = salary
        self.payday = payday
        self.fixedCosts = fixedCosts
        self.carryOverMode = carryOverMode
        self.debtPlanEnabled = debtPlanEnabled
        self.spendReminderEnabled = spendReminderEnabled
        self.spendReminderHour = spendReminderHour
        self.spendReminderMinute = spendReminderMinute
        self.absorbedDebtAmount = absorbedDebtAmount
        self.absorbedDebtPeriodStart = absorbedDebtPeriodStart
        self.themeMode = themeMode
        self.budgetMode = budgetMode
        self.totalAmount = totalAmount
        self.lumpSumStart = lumpSumStart
        self.lumpSumEnd = lumpSumEnd
        self.dailyAmount = dailyAmount
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: BudgetConfig) {
        self.salary = Int(truncating: entity.salary ?? 0)
        self.payday = Int(truncating: entity.payday ?? 0)
        let costs = entity.fixedCosts?.allObjects as? [FixedCost] ?? []
        self.fixedCosts = costs.map(FixedCostModel.init)
        self.carryOverMode = CarryOverMode.from(entity.carryOverMode)
        self.debtPlanEnabled = entity.debtPlanEnabled
        self.spendReminderEnabled = entity.spendReminderEnabled
        self.absorbedDebtAmount = Int(entity.absorbedDebtAmount)
        self.absorbedDebtPeriodStart = entity.absorbedDebtPeriodStart
        self.themeMode = ThemeMode.from(entity.themeMode)
        self.budgetMode = BudgetMode.from(entity.budgetMode)
        self.totalAmount = Int(entity.totalAmount)
        self.lumpSumStart = entity.lumpSumStart
        self.lumpSumEnd = entity.lumpSumEnd
        self.dailyAmount = Int(entity.dailyAmount)
        // 기존 사용자 마이그레이션 시 Int16 기본값이 0(자정)이 되므로,
        // 알림을 켠 적이 없으면 기본 시각(21:00)으로 보정한다.
        if entity.spendReminderEnabled {
            self.spendReminderHour = Int(entity.spendReminderHour)
            self.spendReminderMinute = Int(entity.spendReminderMinute)
        } else {
            let hour = Int(entity.spendReminderHour)
            self.spendReminderHour = hour == 0 ? SpendReminderSchedule.defaultHour : hour
            self.spendReminderMinute = hour == 0 ? SpendReminderSchedule.defaultMinute
                                                 : Int(entity.spendReminderMinute)
        }
    }
}

// MARK: - 고정비 종류
enum FixedCostKind: String, Codable, CaseIterable, Identifiable {
    case spending = "지출"   // 순수 지출 (월세·구독·통신 등)
    case saving = "저축"     // 저축성
    case investment = "투자" // 투자성

    var id: String { rawValue }
    var label: String { rawValue }
    var emoji: String {
        switch self {
        case .spending: return "💸"
        case .saving: return "🐷"
        case .investment: return "📈"
        }
    }
    static func from(_ raw: String?) -> FixedCostKind {
        FixedCostKind(rawValue: raw ?? "") ?? .spending
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
    /// 종류 (지출/저축/투자). 표시·분류용 — 예산 계산에는 영향 없음(모두 차감).
    var kind: FixedCostKind

    // MARK: - Initializer
    init(id: UUID = UUID(), title: String, amount: Int,
         isVariable: Bool = false, dueDay: Int = 0, kind: FixedCostKind = .spending) {
        self.id = id
        self.title = title
        self.amount = amount
        self.isVariable = isVariable
        self.dueDay = dueDay
        self.kind = kind
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: FixedCost) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.amount = Int(truncating: entity.amount ?? 0)
        self.isVariable = entity.isVariable
        self.dueDay = Int(entity.dueDay)
        self.kind = FixedCostKind.from(entity.kind)
    }
}

// MARK: - 고정비 그룹핑 (순수 로직)
struct FixedCostGrouped {
    var fixedSpending: [FixedCostModel] = []      // 지출·고정
    var variableSpending: [FixedCostModel] = []   // 지출·변동 (결제일 순)
    var savingInvestment: [FixedCostModel] = []   // 저축/투자
    var spendingTotal: Int = 0
    var savingTotal: Int = 0
    var investmentTotal: Int = 0
    var total: Int { spendingTotal + savingTotal + investmentTotal }
}

enum FixedCostGrouping {
    /// 고정비 배열을 종류·고정/변동으로 분류하고 종류별 합계를 낸다.
    /// - 종류 우선: 저축/투자는 변동이어도 저축·투자 그룹에.
    /// - 변동 지출은 결제일(dueDay) 오름차순 정렬.
    static func group(_ costs: [FixedCostModel]) -> FixedCostGrouped {
        var g = FixedCostGrouped()
        let spending = costs.filter { $0.kind == .spending }
        g.fixedSpending = spending.filter { !$0.isVariable }
        g.variableSpending = spending.filter { $0.isVariable }.sorted { $0.dueDay < $1.dueDay }
        g.savingInvestment = costs.filter { $0.kind == .saving || $0.kind == .investment }
        g.spendingTotal = spending.reduce(0) { $0 + $1.amount }
        g.savingTotal = costs.filter { $0.kind == .saving }.reduce(0) { $0 + $1.amount }
        g.investmentTotal = costs.filter { $0.kind == .investment }.reduce(0) { $0 + $1.amount }
        return g
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
    /// 그날 저축·투자로 옮긴 금액 합계.
    /// 예산에서는 빠지지만 소비가 아니라 '이동'이라 소비 통계·초과 판정에는 잡히지 않는다.
    var transferAmount: Int

    // 실제 오늘 쓸 수 있는 총 금액
    var todayAvailable: Int {
        let carry = carryOverSources.map { $0.amount }.reduce(0, +)
        let spent = spendingRecords.map { $0.amount }.reduce(0, +)
        return availableAmount + carry - spent - wishSavingAmount - transferAmount
    }

    // MARK: - Initializer
    init(availableAmount: Int, date: Date, carryOverSources: [CarryOverSourceModel],
         spendingRecords: [SpendingRecordModel], wishSavingAmount: Int = 0,
         transferAmount: Int = 0) {
        self.availableAmount = availableAmount
        self.date = date
        self.carryOverSources = carryOverSources
        self.spendingRecords = spendingRecords
        self.wishSavingAmount = wishSavingAmount
        self.transferAmount = transferAmount
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

        let transfers = entity.assetTransfers?.allObjects as? [AssetTransfer] ?? []
        self.transferAmount = transfers.reduce(0) { $0 + Int(truncating: $1.amount ?? 0) }
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
    /// 나중에 돌려받을 환급/페이백 예정 금액 (0이면 없음)
    var expectedPayback: Int
    /// 환급을 실제로 받았는지 여부
    var paybackReceived: Bool

    /// 순 지출 (실지출 − 환급 예정)
    var netAmount: Int { amount - expectedPayback }

    init(id: UUID = UUID(), title: String, amount: Int, date: Date,
         category: SpendingCategory = .other,
         expectedPayback: Int = 0, paybackReceived: Bool = false) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.expectedPayback = expectedPayback
        self.paybackReceived = paybackReceived
    }

    /// CoreData Entity -> Model 변환 생성자
    init(entity: SpendingRecord) {
        self.id = entity.id ?? UUID()
        self.title = entity.title ?? ""
        self.amount = Int(truncating: entity.amount ?? 0)
        self.date = entity.date ?? Date()
        self.category = SpendingCategory.from(rawValue: entity.category)
        self.expectedPayback = Int(entity.expectedPayback)
        self.paybackReceived = entity.paybackReceived
    }
}
