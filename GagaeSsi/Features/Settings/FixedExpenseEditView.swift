//
//  FixedExpenseEditView.swift
//  GagaeSsi
//
//  고정비 추가/편집 화면
//

import SwiftUI

struct FixedExpenseEditView: View {
    // MARK: - Mode
    enum Mode {
        case add
        case edit(FixedCostModel)
        
        var title: String {
            switch self {
            case .add: return "고정비 추가"
            case .edit: return "고정비 수정"
            }
        }
    }
    
    // MARK: - Properties
    let mode: Mode
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var amount: Int = 0
    
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // MARK: - Computed
    private var isValid: Bool {
        !title.isEmpty && amount > 0
    }
    
    private var existingId: UUID? {
        if case .edit(let model) = mode {
            return model.id
        }
        return nil
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                Section("고정비 정보") {
                    TextField("항목명 (예: 월세)", text: $title)
                    
                    TextField("금액", text: $amountText)
                        .keyboardType(.numberPad)
                        .onChange(of: amountText) { _, newValue in
                            if let result = FormatterUtils.formatCurrencyInput(newValue) {
                                amount = result.plainNumber
                                amountText = result.formatted
                            }
                        }
                }
                
                Section {
                    Button {
                        save()
                    } label: {
                        Text("저장")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                    }
                    .listRowBackground(isValid ? Color.blue : Color.gray)
                    .disabled(!isValid)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingData()
            }
            .alert("오류", isPresented: $showErrorAlert) {
                Button("확인") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Methods
    private func loadExistingData() {
        if case .edit(let model) = mode {
            title = model.title
            amount = model.amount
            amountText = FormatterUtils.inputAmountString(from: model.amount)
        }
    }
    
    private func save() {
        guard isValid else {
            errorMessage = "항목명과 금액을 입력해주세요"
            showErrorAlert = true
            return
        }
        
        let success: Bool
        
        switch mode {
        case .add:
            let newModel = FixedCostModel(id: UUID(), title: title, amount: amount)
            success = CoreDataManager.shared.createFixedCost(newModel)
            
        case .edit(let existing):
            let updatedModel = FixedCostModel(id: existing.id, title: title, amount: amount)
            success = CoreDataManager.shared.updateFixedCost(updatedModel)
        }
        
        if success {
            onSave()
            dismiss()
        } else {
            errorMessage = "저장에 실패했습니다"
            showErrorAlert = true
        }
    }
}

// MARK: - Preview
#Preview("Add Mode") {
    FixedExpenseEditView(mode: .add) { }
}

#Preview("Edit Mode") {
    FixedExpenseEditView(
        mode: .edit(FixedCostModel(id: UUID(), title: "월세", amount: 500000))
    ) { }
}
