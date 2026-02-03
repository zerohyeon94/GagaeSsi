//
//  EditBudgetView.swift
//  GagaeSsi
//
//  Created by 조영현 on 2/3/26.
//

import SwiftUI

struct EditBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var salary: String = ""
    @State private var salaryAmount: Int = 0
    @State private var payday: Int = 25
    @State private var showSuccessAlert = false
    
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
                Button("저장") {
                    saveBudget()
                }
                .frame(maxWidth: .infinity)
                .disabled(salaryAmount <= 0)
            }
        }
        .navigationTitle("월급 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadCurrentBudget() }
        .alert("저장 완료", isPresented: $showSuccessAlert) {
            Button("확인") { dismiss() }
        }
    }
    
    private func loadCurrentBudget() {
        if let config = CoreDataManager.shared.fetchBudgetConfig() {
            salaryAmount = config.salary
            salary = FormatterUtils.inputAmountString(from: config.salary)
            payday = config.payday
        }
    }
    
    private func saveBudget() {
        AppEventBus.shared.notifyBudgetChanged()
        showSuccessAlert = true
    }
}

#Preview {
    EditBudgetView()
}
