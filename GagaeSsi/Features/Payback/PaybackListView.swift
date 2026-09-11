//
//  PaybackListView.swift
//  GagaeSsi
//
//  페이백 관리 (미확정·기간형 환급 생명주기)
//

import SwiftUI

struct PaybackListView: View {
    @Environment(AppEventBus.self) private var eventBus
    @State private var items: [PaybackModel] = []
    @State private var showAdd = false
    @State private var editingItem: PaybackModel?
    @State private var receivingItem: PaybackModel?

    private var estimated: [PaybackModel] { items.filter { $0.status == .estimated } }
    private var confirmed: [PaybackModel] { items.filter { $0.status == .confirmed } }
    private var done: [PaybackModel] { items.filter { $0.status == .received || $0.status == .cancelled } }

    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    infoCard.padding(.top, GagaeSpacing.md)
                    if items.isEmpty {
                        GagaeCard {
                            GagaeEmptyStateView(icon: "💳", title: "페이백이 없어요",
                                                subtitle: "K-패스·카드 캐시백처럼 나중에\n돌려받을 환급을 등록해 추적해보세요")
                        }
                    } else {
                        section("미확정", estimated)
                        section("확정 대기", confirmed)
                        section("완료", done)
                    }
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.bottom, GagaeSpacing.xl)
            }
        }
        .navigationTitle("페이백 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(.gagaePinkDark)
                }
            }
        }
        .onAppear { load() }
        .sheet(isPresented: $showAdd) { PaybackEditView(mode: .add) { load() } }
        .sheet(item: $editingItem) { item in PaybackEditView(mode: .edit(item)) { load() } }
        .sheet(item: $receivingItem) { item in
            PaybackReceiveView(payback: item) { amount in
                _ = CoreDataManager.shared.markPaybackReceived(id: item.id, amount: amount)
                eventBus.notifySpendingAdded()   // 오늘 예산 크레딧 → 홈 갱신
                load()
            }
        }
    }

    private var infoCard: some View {
        HStack(spacing: GagaeSpacing.md) {
            Image(systemName: "lightbulb.fill").font(.system(size: 20)).foregroundStyle(.gagaePoint)
            Text("예상 → 확정 → 수령으로 관리해요.\n오늘 예산에는 실제 수령한 금액만 반영돼요.")
                .font(.gagaeSubheadline).foregroundStyle(.gagaeTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(GagaeSpacing.md).background(Color.gagaePoint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
    }

    @ViewBuilder
    private func section(_ title: String, _ list: [PaybackModel]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text(title).font(.gagaeHeadline).foregroundStyle(.gagaeText)
                ForEach(list) { row($0) }
            }
        }
    }

    /// 예정일이 지났는데 아직 수령하지 않았는지
    private func isOverdue(_ item: PaybackModel) -> Bool {
        guard item.status == .estimated || item.status == .confirmed,
              let expected = item.expectedDate else { return false }
        return Calendar.current.startOfDay(for: expected) <= Calendar.current.startOfDay(for: Date())
    }

    /// 자동으로 묶인 소비 합계 — 사용자가 한 달치를 직접 더하지 않아도 되게 한다
    @ViewBuilder
    private func linkedSummary(_ item: PaybackModel) -> some View {
        let linked = CoreDataManager.shared.linkedSpendingTotal(for: item)
        if linked.count > 0, let category = item.linkedCategory {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("\(category.emoji) \(category.rawValue) \(linked.count)건")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text(FormatterUtils.currencyString(from: linked.total))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaeText)
                }
                if let expected = item.estimatedRefund(fromLinkedTotal: linked.total) {
                    HStack(spacing: 4) {
                        Text("환급률 \(item.refundRatePercent)% → 예상 \(FormatterUtils.currencyString(from: expected))")
                            .font(.gagaeCaption).foregroundStyle(.gagaePinkDark)
                        Spacer()
                        if expected != item.estimatedAmount {
                            Button {
                                applyEstimate(item, amount: expected)
                            } label: {
                                Text("예상액에 반영")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.gagaePinkDark).clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func applyEstimate(_ item: PaybackModel, amount: Int) {
        var updated = item
        updated.estimatedAmount = amount
        if updated.status == .estimated || updated.status == .confirmed {
            _ = CoreDataManager.shared.updatePayback(updated)
            load()
        }
    }

    private func row(_ item: PaybackModel) -> some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.xs) {
                HStack(spacing: 6) {
                    Text("\(item.status.emoji) \(item.title)")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                    Text(item.type.label)
                        .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.gagaePinkDark)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gagaePinkLight).clipShape(Capsule())
                    Spacer()
                    Text(FormatterUtils.currencyString(from: item.currentAmount))
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeGood)
                }
                if let ps = item.periodStart, let pe = item.periodEnd {
                    Text("기간 \(dateStr(ps)) ~ \(dateStr(pe))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                }

                // 예정일이 지났는데 아직 못 받았으면 알려준다 — 잊고 넘어가기 쉬운 돈이다
                if isOverdue(item) {
                    HStack(spacing: 4) {
                        Text("⏰").font(.system(size: 11))
                        Text("예정일이 지났어요. 입금됐는지 확인해보세요.")
                            .font(.gagaeCaption).foregroundStyle(.gagaeWarning)
                    }
                }

                if item.canLinkSpending {
                    linkedSummary(item)
                }
                HStack(spacing: GagaeSpacing.sm) {
                    if item.status != .received && item.status != .cancelled {
                        Button { receivingItem = item } label: {
                            Text("수령 처리").font(.gagaeCaptionMedium).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(Color.gagaePinkDark).clipShape(Capsule())
                        }.buttonStyle(.plain)
                    } else if let rd = item.receivedDate {
                        Text("수령 \(dateStr(rd))").font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                        Spacer()
                    }
                    Menu {
                        Button("수정") { editingItem = item }
                        if item.status != .cancelled && item.status != .received {
                            Button("취소 처리") { cancel(item) }
                        }
                        Button("삭제", role: .destructive) {
                            _ = CoreDataManager.shared.deletePayback(id: item.id); load()
                        }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.gagaeTextTertiary).frame(width: 30, height: 30)
                    }
                }
            }
        }
    }

    private func cancel(_ item: PaybackModel) {
        var m = item; m.status = .cancelled
        _ = CoreDataManager.shared.updatePayback(m); load()
    }
    private func dateStr(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M.d"
        return f.string(from: d)
    }
    private func load() { items = CoreDataManager.shared.fetchPaybacks() }
}

#Preview {
    NavigationStack { PaybackListView() }.environment(AppEventBus())
}
