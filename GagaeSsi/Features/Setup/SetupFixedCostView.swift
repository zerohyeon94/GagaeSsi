//
//  SetupFixedCostView.swift
//  GagaeSsi
//
//  초기 설정 - 고정비 입력 화면 (SetupFixedCostViewController 대체)
//

import SwiftUI

struct SetupFixedCostView: View {
    // MARK: - Properties
    @Bindable var viewModel: SetupViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAddSheet = false
    @State private var showSaveErrorAlert = false
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerSection
                .padding(.top, 20)
            
            // 고정비 추가 버튼
            addButton
                .padding(.top, 20)
                .padding(.horizontal, 20)
            
            // 고정비 목록
            fixedCostList
                .padding(.top, 16)
            
            Spacer()
            
            // 하단 버튼들
            bottomButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
        .navigationTitle("고정비 설정")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSheet) {
            AddFixedCostSheet(viewModel: viewModel)
        }
        .alert("저장 실패", isPresented: $showSaveErrorAlert) {
            Button("확인") { }
        } message: {
            Text("예산 설정 저장에 실패했습니다. 다시 시도해주세요.")
        }
    }
}

// MARK: - Subviews
extension SetupFixedCostView {
    /// 헤더 섹션
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("고정비를 추가해주세요")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("매달 고정으로 나가는 비용을 등록하면\n더 정확한 일일 예산을 계산할 수 있어요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    /// 고정비 추가 버튼
    private var addButton: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("고정비 추가")
            }
            .font(.system(size: 16, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// 고정비 목록
    private var fixedCostList: some View {
        Group {
            if viewModel.model.fixedCosts.isEmpty {
                // 빈 상태
                VStack(spacing: 12) {
                    Spacer()
                    
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    
                    Text("등록된 고정비가 없습니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("고정비 없이 진행하려면 '건너뛰기'를 누르세요")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // 목록
                List {
                    ForEach(viewModel.model.fixedCosts) { item in
                        HStack {
                            Text(item.title)
                                .font(.system(size: 16))
                            
                            Spacer()
                            
                            Text(FormatterUtils.currencyString(from: item.amount))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: viewModel.removeFixedCost)
                    
                    // 합계
                    HStack {
                        Text("합계")
                            .font(.system(size: 16, weight: .bold))
                        
                        Spacer()
                        
                        Text(FormatterUtils.currencyString(from: viewModel.totalFixedCost))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
    }
    
    /// 하단 버튼들
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // 건너뛰기 버튼
            Button {
                saveAndContinue()
            } label: {
                Text("건너뛰기")
                    .font(.system(size: 16))
                    .foregroundStyle(.blue)
            }
            
            Spacer()
            
            // 저장하고 시작하기 버튼
            Button {
                saveAndContinue()
            } label: {
                Text("저장하고 시작하기")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    
    // MARK: - Methods
    private func saveAndContinue() {
        viewModel.saveBudgetConfig { success in
            if success {
                // 설정 완료 → 메인 화면으로 전환
                appState.completeSetup()
            } else {
                showSaveErrorAlert = true
            }
        }
    }
}

// MARK: - Add Fixed Cost Sheet
struct AddFixedCostSheet: View {
    @Bindable var viewModel: SetupViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, amount
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("고정비 정보") {
                    TextField("항목명 (예: 월세, 보험료)", text: $viewModel.newFixedCostTitle)
                        .focused($focusedField, equals: .title)
                    
                    TextField("금액", text: $viewModel.newFixedCostAmountText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .amount)
                        .onChange(of: viewModel.newFixedCostAmountText) { _, newValue in
                            viewModel.updateFixedCostAmountFromText(newValue)
                        }
                }
                
                Section {
                    Button {
                        viewModel.addFixedCost()
                        dismiss()
                    } label: {
                        Text("추가")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                    }
                    .listRowBackground(isValid ? Color.blue : Color.gray)
                    .disabled(!isValid)
                }
            }
            .navigationTitle("고정비 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") {
                        viewModel.clearFixedCostInput()
                        dismiss()
                    }
                }
            }
            .onAppear {
                focusedField = .title
            }
        }
        .presentationDetents([.medium])
    }
    
    private var isValid: Bool {
        !viewModel.newFixedCostTitle.isEmpty && viewModel.newFixedCostAmount > 0
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SetupFixedCostView(viewModel: SetupViewModel())
    }
    .environment(AppState())
    .environment(AppEventBus())
}
