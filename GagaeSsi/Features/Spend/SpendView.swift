//
//  SpendView.swift
//  GagaeSsi
//
//  Created by 조영현 on 2/3/26.
//

import SwiftUI

struct SpendView: View {
    @State private var viewModel = SpendViewModel()
    @FocusState private var focusedField: Field?
    
    enum Field { case title, amount }
    
    var body: some View {
        VStack(spacing: 0) {
            // 입력 폼
            VStack(spacing: 16) {
                TextField("내용 (예: 커피)", text: $viewModel.tempTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .title)
                
                TextField("금액", text: $viewModel.tempAmountText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .amount)
                    .onChange(of: viewModel.tempAmountText) { _, newValue in
                        viewModel.updateAmountFromText(newValue)
                    }
                
                DatePicker("날짜", selection: $viewModel.tempDate, displayedComponents: .date)
            }
            .padding(20)
            
            // 저장 버튼
            Button {
                focusedField = nil
                viewModel.saveSpending { _ in }
            } label: {
                Text("저장")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(viewModel.isValid ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!viewModel.isValid)
            .padding(.horizontal, 20)
            
            // 목록
            List(viewModel.spendingRecords) { record in
                HStack {
                    Text(record.title)
                    Spacer()
                    Text(FormatterUtils.currencyString(from: record.amount))
                        .foregroundStyle(.blue)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("소비 기록")
        .onAppear {
            viewModel.fetchSpending(on: Date())
        }
        .alert("성공", isPresented: $viewModel.showSuccessAlert) {
            Button("확인") { viewModel.clearForm() }
        } message: {
            Text("저장되었습니다")
        }
        .alert("오류", isPresented: $viewModel.showErrorAlert) {
            Button("확인") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

#Preview {
    SpendView()
}
