//
//  SetupViewModel.swift
//  GagaeSsi
//
//  초기 설정 ViewModel (@Observable 버전)
//

import SwiftUI
import Observation

@Observable
final class SetupViewModel {
    // MARK: - Properties
    var model: BudgetConfigModel
    
    // 임시 입력값 (화면과 연결)
    var tempSalary: Int = 0
    var tempSalaryText: String = ""
    var tempPayday: Int = 25
    
    // 고정비 추가용
    var newFixedCostTitle: String = ""
    var newFixedCostAmount: Int = 0
    var newFixedCostAmountText: String = ""
    
    // Alert 상태
    var showAddFixedCostAlert: Bool = false
    var showErrorAlert: Bool = false
    var errorMessage: String = ""
    
    // MARK: - Computed
    var isValid: Bool {
        tempSalary > 0 && tempPayday > 0 && tempPayday <= 31
    }
    
    var totalFixedCost: Int {
        model.fixedCosts.map { $0.amount }.reduce(0, +)
    }
    
    // MARK: - Init
    init() {
        self.model = BudgetConfigModel(salary: 0, payday: 25, fixedCosts: [])
    }
    
    // MARK: - Public Methods
    
    /// 월급 텍스트 업데이트
    func updateSalaryFromText(_ text: String) {
        if let result = FormatterUtils.formatCurrencyInput(text) {
            tempSalary = result.plainNumber
            tempSalaryText = result.formatted
        }
    }
    
    /// 고정비 금액 텍스트 업데이트
    func updateFixedCostAmountFromText(_ text: String) {
        if let result = FormatterUtils.formatCurrencyInput(text) {
            newFixedCostAmount = result.plainNumber
            newFixedCostAmountText = result.formatted
        }
    }
    
    /// 월급 정보 확정 (다음 단계로 이동 전)
    func confirmSalaryInfo() {
        model.salary = tempSalary
        model.payday = tempPayday
    }
    
    /// 고정비 추가
    func addFixedCost() {
        guard !newFixedCostTitle.isEmpty, newFixedCostAmount > 0 else {
            errorMessage = "항목명과 금액을 입력해주세요"
            showErrorAlert = true
            return
        }
        
        let newItem = FixedCostModel(
            id: UUID(),
            title: newFixedCostTitle,
            amount: newFixedCostAmount
        )
        model.fixedCosts.append(newItem)
        
        // 입력 필드 초기화
        clearFixedCostInput()
    }
    
    /// 고정비 삭제
    func removeFixedCost(at offsets: IndexSet) {
        model.fixedCosts.remove(atOffsets: offsets)
    }
    
    /// 고정비 입력 필드 초기화
    func clearFixedCostInput() {
        newFixedCostTitle = ""
        newFixedCostAmount = 0
        newFixedCostAmountText = ""
    }
    
    /// 예산 설정 저장
    func saveBudgetConfig(completion: @escaping (Bool) -> Void) {
        let success = CoreDataManager.shared.createBudgetConfig(from: model)
        completion(success)
    }
}
