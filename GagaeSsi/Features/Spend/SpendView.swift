//
//  SpendView.swift
//  GagaeSsi
//
//  소비 기록 화면 (SpendViewController 대체)
//

import SwiftUI

struct SpendView: View {
    // MARK: - Properties
    @State private var viewModel = SpendViewModel()
    @Environment(AppEventBus.self) private var eventBus
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, amount
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // 입력 폼
            inputForm
                .padding(.top, 20)
                .padding(.horizontal, 20)
            
            // 저장 버튼
            saveButton
                .padding(.top, 16)
                .padding(.horizontal, 20)
            
            // 오늘 지출 목록
            spendingList
                .padding(.top, 20)
            
            Spacer()
        }
        .navigationTitle("소비 기록")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let today = Calendar.current.startOfDay(for: Date())
            viewModel.fetchSpending(on: today)
        }
        .alert("성공", isPresented: $viewModel.showSuccessAlert) {
            Button("확인") {
                viewModel.clearForm()
            }
        } message: {
            Text("지출 내역이 저장되었습니다")
        }
        .alert("오류", isPresented: $viewModel.showErrorAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}

// MARK: - Subviews
extension SpendView {
    /// 입력 폼
    private var inputForm: some View {
        VStack(spacing: 16) {
            // 내용 입력
            TextField("내용 (예: 커피)", text: $viewModel.tempTitle)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .title)
            
            // 금액 입력
            TextField("금액 (예: 5,000)", text: $viewModel.tempAmountText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .amount)
                .onChange(of: viewModel.tempAmountText) { _, newValue in
                    viewModel.updateAmountFromText(newValue)
                }
            
            // 날짜 선택
            DatePicker(
                "날짜",
                selection: $viewModel.tempDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
        }
    }
    
    /// 저장 버튼
    private var saveButton: some View {
        Button {
            focusedField = nil
            viewModel.saveSpending(eventBus: eventBus) { success in
                if success {
                    let today = Calendar.current.startOfDay(for: Date())
                    viewModel.fetchSpending(on: today)
                }
            }
        } label: {
            Text("저장")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(viewModel.isValid ? Color.blue : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .disabled(!viewModel.isValid)
    }
    
    /// 오늘 지출 목록
    private var spendingList: some View {
        List {
            if viewModel.spendingRecords.isEmpty {
                Text("오늘 기록된 지출이 없습니다")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.spendingRecords) { record in
                    HStack {
                        Text(record.title)
                            .font(.system(size: 16))
                        
                        Spacer()
                        
                        Text(FormatterUtils.currencyString(from: record.amount))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SpendView()
    }
    .environment(AppEventBus())
}
