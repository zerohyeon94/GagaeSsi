//
//  EditBudgetView.swift
//  GagaeSsi
//
//  예산 편집 화면
//

import SwiftUI

struct EditBudgetView: View {
    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEventBus.self) private var eventBus
    
    @State private var salary: String = ""
    @State private var salaryAmount: Int = 0
    @State private var payday: Int = 25
    
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Body
    var body: some View {
        Form {
            Section("월급") {
                TextField("월급 (예: 3,000,000)", text: $salary)
                    .keyboardType(.numberPad)
                    .onChange(of: salary) { _, newValue in
                        if let result = FormatterUtils.formatCurrencyInput(newValue) {
                            salaryAmount = result.plainNumber
                            salary = result.formatted
                        }
                    }
            }
            
            Section("급여일") {
                Picker("급여일", selection: $payday) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)일").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }
            
            Section {
                Button {
                    saveBudget()
                } label: {
                    Text("저장")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .listRowBackground(salaryAmount > 0 ? Color.blue : Color.gray)
                .disabled(salaryAmount <= 0)
            }
        }
        .navigationTitle("월급 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentBudget()
        }
        .alert("저장 완료", isPresented: $showSuccessAlert) {
            Button("확인") {
                dismiss()
            }
        } message: {
            Text("예산 설정이 저장되었습니다")
        }
        .alert("오류", isPresented: $showErrorAlert) {
            Button("확인") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Methods
    private func loadCurrentBudget() {
        if let config = CoreDataManager.shared.fetchBudgetConfig() {
            salaryAmount = config.salary
            salary = FormatterUtils.inputAmountString(from: config.salary)
            payday = config.payday
        }
    }
    
    private func saveBudget() {
        guard salaryAmount > 0 else {
            errorMessage = "월급을 입력해주세요"
            showErrorAlert = true
            return
        }
        
        // 기존 설정이 있으면 업데이트, 없으면 생성
        if let existingConfig = CoreDataManager.shared.fetchBudgetConfig() {
            let updatedConfig = BudgetConfigModel(
                salary: salaryAmount,
                payday: payday,
                fixedCosts: existingConfig.fixedCosts
            )
            let success = CoreDataManager.shared.updateBudgetConfig(updatedConfig)
            if success {
                eventBus.notifyBudgetChanged()
                showSuccessAlert = true
            } else {
                errorMessage = "저장에 실패했습니다"
                showErrorAlert = true
            }
        } else {
            let newConfig = BudgetConfigModel(
                salary: salaryAmount,
                payday: payday,
                fixedCosts: []
            )
            let success = CoreDataManager.shared.createBudgetConfig(from: newConfig)
            if success {
                eventBus.notifyBudgetChanged()
                showSuccessAlert = true
            } else {
                errorMessage = "저장에 실패했습니다"
                showErrorAlert = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        EditBudgetView()
    }
    .environment(AppEventBus())
}
