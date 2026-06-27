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

    @FocusState private var isSalaryFocused: Bool

    @State private var showPaydayPicker = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private var isValid: Bool { salaryAmount > 0 }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    // 안내 카드
                    infoCard
                        .padding(.top, GagaeSpacing.md)

                    // 월급 입력
                    salarySection

                    // 급여일 선택
                    paydaySection

                    // 저장 버튼
                    GagaePrimaryButton(title: "저장하기", isEnabled: isValid) {
                        saveBudget()
                    }
                    .padding(.top, GagaeSpacing.sm)
                    .padding(.bottom, GagaeSpacing.xl)
                }
                .padding(.horizontal, GagaeSpacing.md)
            }
        }
        .navigationTitle("월급 & 급여일")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .sheet(isPresented: $showPaydayPicker) {
            paydayPickerSheet
        }
        .onAppear {
            loadCurrentBudget()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSalaryFocused = true
            }
        }
        .onTapGesture {
            isSalaryFocused = false
        }
        .alert("저장 완료", isPresented: $showSuccessAlert) {
            Button("확인") { dismiss() }
        } message: {
            Text("예산 설정이 업데이트됐어요 🐷")
        }
        .alert("오류", isPresented: $showErrorAlert) {
            Button("확인") { }
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - Subviews
extension EditBudgetView {

    private var infoCard: some View {
        HStack(spacing: GagaeSpacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 20))
                .foregroundStyle(.gagaePoint)

            Text("월급과 급여일을 기준으로\n일일 예산이 자동 계산돼요.")
                .font(.gagaeSubheadline)
                .foregroundStyle(.gagaeTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(GagaeSpacing.md)
        .background(Color.gagaePoint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
    }

    private var salarySection: some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            Label("월급", systemImage: "wonsign.circle.fill")
                .font(.gagaeCalloutMedium)
                .foregroundStyle(.gagaePinkDark)

            HStack(spacing: GagaeSpacing.sm) {
                Text("₩")
                    .font(.gagaeTitle3)
                    .foregroundStyle(.gagaePinkDark)

                TextField("예: 3,000,000", text: $salary)
                    .font(.gagaeTitle3)
                    .keyboardType(.numberPad)
                    .focused($isSalaryFocused)
                    .onChange(of: salary) { _, newValue in
                        if let result = FormatterUtils.formatCurrencyInput(newValue) {
                            salaryAmount = result.plainNumber
                            salary = result.formatted
                        }
                    }
            }
            .padding(GagaeSpacing.md)
            .background(Color.gagaeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: GagaeRadius.md)
                    .stroke(
                        isSalaryFocused ? Color.gagaePinkDark : Color.gagaeDivider,
                        lineWidth: isSalaryFocused ? 2 : 0.5
                    )
            )
            .gagaeShadow()
        }
    }

    private var paydaySection: some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            Label("급여일", systemImage: "calendar.circle.fill")
                .font(.gagaeCalloutMedium)
                .foregroundStyle(.gagaePinkDark)

            Button {
                isSalaryFocused = false
                showPaydayPicker = true
            } label: {
                GagaeCard {
                    HStack(spacing: 4) {
                        Text("매월")
                            .font(.gagaeCallout)
                            .foregroundStyle(.gagaeTextSecondary)

                        Spacer()

                        HStack(spacing: 3) {
                            Text("\(payday)일")
                                .font(.gagaeCalloutMedium)
                                .foregroundStyle(.gagaePinkDark)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.gagaePinkDark)
                        }

                        Text("에 월급을 받아요")
                            .font(.gagaeCallout)
                            .foregroundStyle(.gagaeTextSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var paydayPickerSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") { showPaydayPicker = false }
                    .font(.gagaeCallout)
                    .foregroundStyle(.gagaeTextSecondary)
                Spacer()
                Text("급여일 선택")
                    .font(.gagaeCalloutMedium)
                    .foregroundStyle(.gagaeText)
                Spacer()
                Button("완료") { showPaydayPicker = false }
                    .font(.gagaeCalloutMedium)
                    .foregroundStyle(.gagaePinkDark)
            }
            .padding(.horizontal, GagaeSpacing.md)
            .padding(.vertical, GagaeSpacing.md)

            Divider()

            Picker("급여일", selection: $payday) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)일").tag(day)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Methods
extension EditBudgetView {
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
            let newConfig = BudgetConfigModel(salary: salaryAmount, payday: payday, fixedCosts: [])
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
