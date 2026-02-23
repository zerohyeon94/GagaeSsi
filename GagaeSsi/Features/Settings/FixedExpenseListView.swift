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
            FixedExpenseEditView(mode: .add) {
                loadFixedCosts()
                eventBus.notifyFixedExpenseChanged()
            }
        }
        .sheet(item: $editingItem) { item in
            FixedExpenseEditView(mode: .edit(item)) {
                loadFixedCosts()
                eventBus.notifyFixedExpenseChanged()
            }
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

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.gagaeCalloutMedium)
                    .foregroundStyle(.gagaeText)
                Text("매달 고정")
                    .font(.gagaeCaption)
                    .foregroundStyle(.gagaeTextTertiary)
            }

            Spacer()

            Text(FormatterUtils.currencyString(from: item.amount))
                .font(.gagaeCalloutMedium)
                .foregroundStyle(.gagaeDanger)

            Button {
                _ = CoreDataManager.shared.deleteFixedCost(id: item.id)
                loadFixedCosts()
                eventBus.notifyFixedExpenseChanged()
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
    private func loadFixedCosts() {
        fixedCosts = CoreDataManager.shared.fetchFixedCosts()
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FixedExpenseListView()
    }
    .environment(AppEventBus())
}
