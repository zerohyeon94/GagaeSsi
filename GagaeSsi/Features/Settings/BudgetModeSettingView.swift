//
//  BudgetModeSettingView.swift
//  GagaeSsi
//
//  예산 모드 선택·수정 (정기 수입 / 모아둔 돈으로 생활 / 하루 예산 직접 설정)
//

import SwiftUI

struct BudgetModeSettingView: View {
    @Environment(AppEventBus.self) private var eventBus
    @Environment(\.dismiss) private var dismiss

    @State private var mode: BudgetMode = .recurring
    @State private var config: BudgetConfigModel?

    // 총액 모드
    @State private var totalText = ""
    @State private var total = 0
    @State private var lumpSumEnd = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    // 하루 직접 설정 모드
    @State private var dailyText = ""
    @State private var daily = 0

    @FocusState private var focused: Bool

    private var isValid: Bool {
        switch mode {
        case .recurring: return true                     // 기존 월급·급여일 화면에서 관리
        case .lumpSum: return total > 0 && daysLeft > 0
        case .fixedDaily: return daily > 0
        }
    }
    private var daysLeft: Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                      to: cal.startOfDay(for: lumpSumEnd)).day ?? -1
        return max(0, days + 1)
    }
    private var previewDaily: Int {
        guard daysLeft > 0 else { return 0 }
        return total / daysLeft
    }

    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: GagaeSpacing.md) {
                    modeCards
                    switch mode {
                    case .recurring: recurringNote
                    case .lumpSum: lumpSumInput
                    case .fixedDaily: fixedDailyInput
                    }
                    changeNote
                    GagaePrimaryButton(title: "저장하기", isEnabled: isValid) { save() }
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("예산 방식")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onTapGesture { focused = false }
    }

    // MARK: - 모드 선택

    private var modeCards: some View {
        VStack(spacing: GagaeSpacing.sm) {
            ForEach(BudgetMode.allCases) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { mode = option }
                } label: {
                    HStack(spacing: 12) {
                        Text(option.emoji).font(.system(size: 22)).frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.gagaeText)
                            Text(option.summary)
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        if mode == option {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 19)).foregroundStyle(.gagaePinkDark)
                        }
                    }
                    .padding(14)
                    .background(Color.gagaeCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(mode == option ? Color.gagaePinkDark : Color.clear, lineWidth: 2))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 모드별 입력

    private var recurringNote: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                if let config {
                    HStack {
                        Text("현재 수입").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                        Spacer()
                        Text("월 \(FormatterUtils.currencyString(from: config.salary)) · 매월 \(config.payday)일")
                            .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    }
                }
                Text("금액과 받는 날은 ‘월급 & 급여일’에서 바꿔요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
            }
        }
    }

    private var lumpSumInput: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                    Text("지금 가진 돈").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    HStack(spacing: GagaeSpacing.sm) {
                        Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                        TextField("0", text: $totalText)
                            .font(.gagaeTitle3).keyboardType(.numberPad).focused($focused)
                            .onChange(of: totalText) { _, v in
                                if let r = FormatterUtils.formatCurrencyInput(v) {
                                    total = r.plainNumber; totalText = r.formatted
                                } else if v.isEmpty { total = 0 }
                            }
                    }
                    .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                    .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                }

                DatePicker("언제까지 버틸까요", selection: $lumpSumEnd,
                           in: Date()..., displayedComponents: .date)
                    .font(.gagaeCalloutMedium).tint(.gagaePinkDark)

                GagaeDivider()

                HStack {
                    Text("하루에 쓸 수 있는 돈").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text("\(FormatterUtils.currencyString(from: previewDaily)) · \(daysLeft)일")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                }

                Text("이 모드에는 고정비 개념이 없어요. 월세처럼 나갈 돈은 미리 빼고 넣어주세요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var fixedDailyInput: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("하루에 쓸 금액").font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                HStack(spacing: GagaeSpacing.sm) {
                    Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                    TextField("0", text: $dailyText)
                        .font(.gagaeTitle3).keyboardType(.numberPad).focused($focused)
                        .onChange(of: dailyText) { _, v in
                            if let r = FormatterUtils.formatCurrencyInput(v) {
                                daily = r.plainNumber; dailyText = r.formatted
                            } else if v.isEmpty { daily = 0 }
                        }
                }
                .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                Text("수입이나 고정비를 묻지 않고 이 금액만 매일 배정해요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
            }
        }
    }

    private var changeNote: some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("바꾸면 오늘부터 적용돼요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                Text("지난 기록과 이월·저금은 그대로 남아요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
            }
        }
    }

    // MARK: - Actions

    private func load() {
        guard let loaded = CoreDataManager.shared.fetchBudgetConfig() else { return }
        config = loaded
        mode = loaded.budgetMode
        total = loaded.totalAmount
        totalText = loaded.totalAmount > 0 ? FormatterUtils.inputAmountString(from: loaded.totalAmount) : ""
        if let end = loaded.lumpSumEnd, end > Date() { lumpSumEnd = end }
        daily = loaded.dailyAmount
        dailyText = loaded.dailyAmount > 0 ? FormatterUtils.inputAmountString(from: loaded.dailyAmount) : ""
    }

    private func save() {
        guard var updated = config else { return }
        updated.budgetMode = mode
        switch mode {
        case .recurring:
            break
        case .lumpSum:
            updated.totalAmount = total
            updated.lumpSumStart = Calendar.current.startOfDay(for: Date())
            updated.lumpSumEnd = Calendar.current.startOfDay(for: lumpSumEnd)
        case .fixedDaily:
            updated.dailyAmount = daily
        }

        guard CoreDataManager.shared.updateBudgetConfig(updated) else { return }
        // 오늘의 기본 예산만 새 방식으로 다시 계산 (과거 기록·이월은 보존)
        CoreDataManager.shared.recalculateTodayBaseBudget()
        eventBus.notifyBudgetChanged()
        eventBus.notifySpendingAdded()
        dismiss()
    }
}

#Preview {
    NavigationStack { BudgetModeSettingView() }
        .environment(AppEventBus())
}
