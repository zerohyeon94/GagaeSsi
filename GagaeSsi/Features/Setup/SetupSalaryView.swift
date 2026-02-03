//
//  SetupSalaryView.swift
//  GagaeSsi
//
//  초기 설정 - 월급 입력 화면 (SetupSalaryViewController 대체)
//

import SwiftUI

struct SetupSalaryView: View {
    // MARK: - Properties
    @State private var viewModel = SetupViewModel()
    @FocusState private var focusedField: Field?
    
    enum Field {
        case salary
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerSection
                .padding(.top, 40)
            
            // 입력 폼
            inputForm
                .padding(.top, 40)
                .padding(.horizontal, 20)
            
            Spacer()
            
            // 다음 버튼
            nextButton
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
        .navigationTitle("예산 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 화면 진입 시 키보드 포커스
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .salary
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}

// MARK: - Subviews
extension SetupSalaryView {
    /// 헤더 섹션
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "wonsign.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("월급 정보를 입력해주세요")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("매월 예산을 자동으로 계산하는 데 사용됩니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    /// 입력 폼
    private var inputForm: some View {
        VStack(spacing: 24) {
            // 월급 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("월급")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                TextField("예: 3,000,000", text: $viewModel.tempSalaryText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .salary)
                    .onChange(of: viewModel.tempSalaryText) { _, newValue in
                        viewModel.updateSalaryFromText(newValue)
                    }
            }
            
            // 급여일 선택
            VStack(alignment: .leading, spacing: 8) {
                Text("급여일")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack {
                    Text("매월")
                        .foregroundStyle(.secondary)
                    
                    Picker("급여일", selection: $viewModel.tempPayday) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.blue)
                    
                    Text("일")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    /// 다음 버튼
    private var nextButton: some View {
        NavigationLink {
            SetupFixedCostView(viewModel: viewModel)
        } label: {
            Text("다음")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.isValid ? Color.blue : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!viewModel.isValid)
        .simultaneousGesture(TapGesture().onEnded {
            // 다음 화면으로 이동하기 전에 월급 정보 확정
            viewModel.confirmSalaryInfo()
        })
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SetupSalaryView()
    }
    .environment(AppState())
    .environment(AppEventBus())
}
