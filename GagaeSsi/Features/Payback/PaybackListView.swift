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
