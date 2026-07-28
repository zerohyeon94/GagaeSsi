//
//  FixedExpenseListView.swift
//  GagaeSsi
//
//  고정비 목록 화면
//

import SwiftUI

struct FixedExpenseListView: View {
    // MARK: - Properties
    @Environment(AppEventBus.self) private var eventBus
    @State private var fixedCosts: [FixedCostModel] = []
    @State private var showAddSheet = false
    @State private var editingItem: FixedCostModel?
    @State private var confirmingItem: FixedCostModel?
    /// 변동 고정비의 이번 달 확정 금액 (costId -> 확정액). 없으면 미확정.
    @State private var confirmedThisMonth: [UUID: Int] = [:]

    // MARK: - Computed
    private var totalAmount: Int {
        fixedCosts.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    // 합계 카드
                    totalCard
                        .padding(.top, GagaeSpacing.md)

                    // 목록 섹션
                    listSection

                    Spacer(minLength: GagaeSpacing.xl)
                }
                .padding(.horizontal, GagaeSpacing.md)
            }
        }
        .navigationTitle("고정비 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.gagaePinkDark)
                }
            }
        }
        .onAppear { loadFixedCosts() }
        .sheet(isPresented: $showAddSheet) {
            FixedExpenseEditView(mode: .add) { afterChange() }
        }
        .sheet(item: $editingItem) { item in
            FixedExpenseEditView(mode: .edit(item)) { afterChange() }
        }
        .sheet(item: $confirmingItem) { item in
            MonthlyAmountConfirmView(item: item,
                                     currentAmount: confirmedThisMonth[item.id]) { afterChange() }
        }
    }
}

// MARK: - Subviews
extension FixedExpenseListView {

    /// 합계 카드
    private var totalCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GagaeRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.50, blue: 0.65), Color(red: 0.95, green: 0.40, blue: 0.60)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .gagaeCardShadow()

            HStack {
                VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                    Text("월 고정 지출")
                        .font(.gagaeSubheadline)
                        .foregroundStyle(.white.opacity(0.85))

                    Text(FormatterUtils.currencyString(from: totalAmount))
                        .font(.gagaeAmountMedium)
                        .foregroundStyle(.white)

                    Text("항목 \(fixedCosts.count)개")
                        .font(.gagaeCaption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text("📌")
                    .font(.system(size: 44))
            }
            .padding(GagaeSpacing.lg)
        }
        .frame(height: 110)
    }

    /// 고정비 목록
    private var listSection: some View {
        VStack(spacing: GagaeSpacing.sm) {
            HStack {
                Text("고정비 목록")
                    .font(.gagaeHeadline)
                    .foregroundStyle(.gagaeText)

                Spacer()

                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("추가")
                            .font(.gagaeCaptionMedium)
                    }
                    .foregroundStyle(.gagaePinkDark)
                    .padding(.horizontal, GagaeSpacing.sm)
                    .padding(.vertical, GagaeSpacing.xs)
                    .background(.gagaePinkLight)
                    .clipShape(Capsule())
                }
            }

            if fixedCosts.isEmpty {
                GagaeCard {
                    GagaeEmptyStateView(
                        icon: "📋",
                        title: "고정비가 없어요",
                        subtitle: "월세, 보험료, 구독료 등\n매달 나가는 금액을 추가해보세요"
                    )
                }
            } else {
                GagaeCard(padding: 0) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(fixedCosts.enumerated()), id: \.element.id) { index, item in
                            fixedCostRow(item: item)

                            if index < fixedCosts.count - 1 {
                                GagaeDivider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
            }
        }
    }

    private func fixedCostRow(item: FixedCostModel) -> some View {
        HStack(spacing: GagaeSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.gagaePinkLight)
                    .frame(width: 38, height: 38)

                Text(fixedCostIcon(for: item.title))
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.gagaeCalloutMedium)
                        .foregroundStyle(.gagaeText)
                    if item.isVariable {
                        Text("변동")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.gagaePinkDark)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gagaePinkLight)
                            .clipShape(Capsule())
                    }
                }
                if item.isVariable {
                    variableSubtitle(item)
                } else {
                    Text("매달 고정")
                        .font(.gagaeCaption)
                        .foregroundStyle(.gagaeTextTertiary)
                }
            }

            Spacer()

            if item.isVariable {
                Button {
                    confirmingItem = item
                } label: {
                    Text(confirmedThisMonth[item.id] == nil ? "확정 입력" : "수정")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(confirmedThisMonth[item.id] == nil ? .white : .gagaePinkDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(confirmedThisMonth[item.id] == nil ? AnyShapeStyle(Color.gagaePinkDark) : AnyShapeStyle(Color.gagaePinkLight))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text(FormatterUtils.currencyString(from: item.amount))
                    .font(.gagaeCalloutMedium)
                    .foregroundStyle(.gagaeDanger)
            }

            Button {
                _ = CoreDataManager.shared.deleteFixedCost(id: item.id)
                afterChange()
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.gagaeTextTertiary)
            }
        }
        .padding(.horizontal, GagaeSpacing.md)
        .padding(.vertical, GagaeSpacing.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            editingItem = item
        }
    }

    /// 변동 고정비 부제: 지출일 + 이번 달 확정 상태
    @ViewBuilder
    private func variableSubtitle(_ item: FixedCostModel) -> some View {
        if let confirmed = confirmedThisMonth[item.id] {
            Text("매월 \(item.dueDay)일 · 이번 달 확정 \(FormatterUtils.currencyString(from: confirmed))")
                .font(.gagaeCaption)
                .foregroundStyle(.gagaeGood)
        } else {
            Text("매월 \(item.dueDay)일 · 이번 달 미확정 (예상 \(FormatterUtils.currencyString(from: item.amount)))")
                .font(.gagaeCaption)
                .foregroundStyle(.gagaeTextTertiary)
        }
    }

    private func fixedCostIcon(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("월세") || lower.contains("전세") || lower.contains("집") { return "🏠" }
        if lower.contains("보험") { return "🛡️" }
        if lower.contains("통신") || lower.contains("핸드폰") || lower.contains("핸폰") { return "📱" }
        if lower.contains("구독") || lower.contains("넷플") || lower.contains("유튜브") { return "📺" }
        if lower.contains("교통") || lower.contains("교통비") { return "🚌" }
        if lower.contains("헬스") || lower.contains("체육관") || lower.contains("피트니스") { return "💪" }
        if lower.contains("학원") || lower.contains("교육") { return "📚" }
        if lower.contains("주차") { return "🅿️" }
        return "📌"
    }
}

// MARK: - Methods
extension FixedExpenseListView {
    /// 추가/수정/확정/삭제 후 공통 처리: 목록 갱신 + 예산 재계산 트리거 + 지출일 알림 갱신
    private func afterChange() {
        loadFixedCosts()
        eventBus.notifyFixedExpenseChanged()
        CoreDataManager.shared.refreshVariableCostReminders()
    }

    private func loadFixedCosts() {
        fixedCosts = CoreDataManager.shared.fetchFixedCosts()

        // 변동 고정비의 이번 달 확정 상태 로드
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        guard let year = comps.year, let month = comps.month else { return }
        var status: [UUID: Int] = [:]
        for cost in fixedCosts where cost.isVariable {
            if let entry = CoreDataManager.shared.fetchMonthlyEntry(fixedCostId: cost.id, year: year, month: month) {
                status[cost.id] = entry.amount
            }
        }
        confirmedThisMonth = status
    }
}

// MARK: - 이번 달 확정 금액 입력 시트
private struct MonthlyAmountConfirmView: View {
    let item: FixedCostModel
    let currentAmount: Int?
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var amount: Int = 0
    @FocusState private var focused: Bool

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월"
        return f.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            HStack {
                                Text("💳 \(item.title)")
                                    .font(.gagaeHeadline)
                                    .foregroundStyle(.gagaeText)
                                Spacer()
                            }
                            Text("\(monthLabel) 실제 결제 금액을 입력하면\n오늘부터 하루 예산에 반영돼요.")
                                .font(.gagaeFootnote)
                                .foregroundStyle(.gagaeTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            GagaeDivider()

                            Label("\(monthLabel) 확정 금액", systemImage: "wonsign.circle.fill")
                                .font(.gagaeFootnote)
                                .foregroundStyle(.gagaeTextSecondary)

                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $amountText)
                                    .font(.gagaeTitle3)
                                    .keyboardType(.numberPad)
                                    .focused($focused)
                                    .onChange(of: amountText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) {
                                            amount = r.plainNumber
                                            amountText = r.formatted
                                        }
                                    }
                            }
                            .padding(GagaeSpacing.md)
                            .background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                            .overlay(RoundedRectangle(cornerRadius: GagaeRadius.md)
                                .stroke(focused ? Color.gagaePinkDark : Color.gagaeDivider, lineWidth: focused ? 2 : 0.5))

                            Text("예상 금액: \(FormatterUtils.currencyString(from: item.amount))")
                                .font(.gagaeCaption)
                                .foregroundStyle(.gagaeTextTertiary)
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "확정하기", isEnabled: amount > 0) {
                        _ = CoreDataManager.shared.confirmMonthlyAmount(
                            fixedCostId: item.id,
                            year: Calendar.current.component(.year, from: Date()),
                            month: Calendar.current.component(.month, from: Date()),
                            amount: amount)
                        onConfirm()
                        dismiss()
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle("이번 달 확정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear {
                if let c = currentAmount {
                    amount = c
                    amountText = FormatterUtils.inputAmountString(from: c)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FixedExpenseListView()
    }
    .environment(AppEventBus())
}
