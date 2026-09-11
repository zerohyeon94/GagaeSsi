//
//  WishListView.swift
//  GagaeSsi
//
//  위시리스트 저금 화면
//

import SwiftUI

struct WishListView: View {
    var onClose: (() -> Void)? = nil

    @Environment(AppEventBus.self) private var eventBus
    @State private var viewModel = WishListViewModel()
    @State private var showAdd = false
    @State private var editingItem: WishItemModel?
    @State private var activatingItem: WishItemModel?

    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    if viewModel.items.isEmpty {
                        emptyState.padding(.top, GagaeSpacing.xxl)
                    } else {
                        if let active = viewModel.activeItem {
                            sectionTitle("저금 중 🐷")
                            activeCard(active)
                        }
                        if !viewModel.purchasableItems.isEmpty {
                            sectionTitle("구매 가능 🎉")
                            ForEach(viewModel.purchasableItems) { purchasableCard($0) }
                        }
                        if !viewModel.waitingItems.isEmpty {
                            sectionTitle("위시 목록")
                            ForEach(viewModel.waitingItems) { waitingRow($0) }
                        }
                        if !viewModel.completedItems.isEmpty {
                            sectionTitle("구매 완료")
                            ForEach(viewModel.completedItems) { completedRow($0) }
                        }
                    }
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.vertical, GagaeSpacing.md)
            }
        }
        .navigationTitle("위시리스트")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { onClose() }.foregroundStyle(.gagaePinkDark)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(.gagaePinkDark)
                }
            }
        }
        .onAppear { viewModel.load() }
        .sheet(isPresented: $showAdd) {
            WishEditView(mode: .add) { title, target, kind in
                _ = viewModel.addWish(title: title, targetAmount: target, kind: kind)
            }
        }
        .sheet(item: $editingItem) { item in
            WishEditView(mode: .edit(item)) { title, target, kind in
                viewModel.updateWish(id: item.id, title: title, targetAmount: target, kind: kind)
            }
        }
        .sheet(item: $activatingItem) { item in
            WishActivateView(item: item, canActivate: !viewModel.hasActiveSaving) { dailySaving in
                viewModel.activate(id: item.id, dailySaving: dailySaving, eventBus: eventBus)
            }
        }
    }
}

// MARK: - Sections
private extension WishListView {
    func sectionTitle(_ t: String) -> some View {
        HStack {
            Text(t).font(.gagaeHeadline).foregroundStyle(.gagaeText)
            Spacer()
        }
    }

    var emptyState: some View {
        GagaeCard {
            GagaeEmptyStateView(
                icon: "🎁",
                title: "위시리스트가 비어 있어요",
                subtitle: "사고 싶은 것(희망)과 꼭 사야 하는 것(필수)을\n등록하고 하루 저금으로 모아보세요"
            )
        }
    }

    // 저금 중 카드
    func activeCard(_ item: WishItemModel) -> some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                HStack {
                    Text("\(item.kind.emoji) \(item.title)")
                        .font(.gagaeHeadline).foregroundStyle(.gagaeText)
                    Spacer()
                    if let d = item.daysLeft {
                        Text(d == 0 ? "완료" : "D-\(d)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.gagaePinkDark).clipShape(Capsule())
                    }
                }

                gauge(item)

                HStack {
                    Text("\(FormatterUtils.currencyString(from: item.savedAmount)) / \(FormatterUtils.currencyString(from: item.targetAmount))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text("오늘 −\(FormatterUtils.currencyString(from: item.dailySaving)) 저금 중")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                }

                HStack(spacing: GagaeSpacing.sm) {
                    Button {
                        viewModel.deactivate(id: item.id, eventBus: eventBus)
                    } label: {
                        Text("저금 해지").font(.gagaeCaptionMedium).foregroundStyle(.gagaeTextSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(Color.gagaeSurface).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
                Text("해지하면 모은 금액이 오늘 잔액으로 환급돼요")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
            }
        }
    }

    // 구매 가능 카드
    func purchasableCard(_ item: WishItemModel) -> some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                HStack {
                    Text("\(item.kind.emoji) \(item.title)")
                        .font(.gagaeHeadline).foregroundStyle(.gagaeText)
                    Spacer()
                    Text("목표 달성 🎉").font(.gagaeCaptionMedium).foregroundStyle(.gagaeGood)
                }
                gauge(item)

                if item.hasSpending {
                    // 지갑으로 쓰기 시작했으면 게이지보다 남은 돈이 중요하다
                    HStack {
                        Text("남은 돈")
                            .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                        Spacer()
                        Text(FormatterUtils.currencyString(from: item.balance))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.gagaePinkDark)
                    }
                    // 내가 모은 돈만 센다 — 정산으로 돌아온 돈은 아래 줄에서 따로 말한다
                    Text("모은 \(FormatterUtils.currencyString(from: item.goalContribution)) 중 \(FormatterUtils.currencyString(from: item.spentAmount)) 썼어요")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                } else {
                    Text("모은 금액 \(FormatterUtils.currencyString(from: item.goalContribution))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    Text("기록 탭에서 소비를 적을 때 이 위시를 고르면 여기서 빠져요")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 정산 회수는 쓴 적이 있든 없든 보여야 한다.
                // 정산 직후 지갑은 아직 쓴 적이 없는 게 보통이라, `hasSpending` 안에 두면
                // 사용자가 가장 확인하고 싶은 순간에 오히려 안 보인다.
                if item.returnedAmount > 0 {
                    Text("🧳 여행 정산으로 \(FormatterUtils.currencyString(from: item.returnedAmount)) 돌아왔어요")
                        .font(.gagaeCaption).foregroundStyle(.gagaeGood)
                }

                GagaePrimaryButton(title: "구매 완료", isEnabled: true) {
                    viewModel.complete(id: item.id, eventBus: eventBus)
                }
            }
        }
    }

    // 대기 행
    func waitingRow(_ item: WishItemModel) -> some View {
        GagaeCard {
            HStack(spacing: GagaeSpacing.md) {
                Text(item.kind.emoji).font(.system(size: 24))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(item.title).font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                        kindBadge(item.kind)
                    }
                    Text("목표 \(FormatterUtils.currencyString(from: item.targetAmount))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                }
                Spacer()
                Menu {
                    Button("저금 시작") { activatingItem = item }
                    Button("수정") { editingItem = item }
                    Button("삭제", role: .destructive) { viewModel.delete(id: item.id, eventBus: eventBus) }
                } label: {
                    Image(systemName: "ellipsis.circle.fill").font(.system(size: 22)).foregroundStyle(.gagaeTextTertiary)
                }
                Button {
                    activatingItem = item
                } label: {
                    Text("저금 시작").font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.gagaePinkDark).clipShape(Capsule())
                }.buttonStyle(.plain)
            }
        }
    }

    // 완료 행
    func completedRow(_ item: WishItemModel) -> some View {
        GagaeCard {
            HStack(spacing: GagaeSpacing.md) {
                Text("✅").font(.system(size: 20))
                Text("\(item.kind.emoji) \(item.title)").font(.gagaeCallout).foregroundStyle(.gagaeTextSecondary)
                Spacer()
                Text(FormatterUtils.currencyString(from: item.targetAmount))
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                Button {
                    viewModel.delete(id: item.id, eventBus: eventBus)
                } label: {
                    Image(systemName: "trash.circle.fill").font(.system(size: 20)).foregroundStyle(.gagaeTextTertiary)
                }.buttonStyle(.plain)
            }
        }
    }

    func gauge(_ item: WishItemModel) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gagaeDivider.opacity(0.5)).frame(height: 10)
                Capsule().fill(LinearGradient(colors: [.gagaePinkDark, .gagaePink],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geo.size.width * item.progress), height: 10)
            }
        }
        .frame(height: 10)
    }

    func kindBadge(_ kind: WishKind) -> some View {
        Text(kind.label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(kind == .need ? Color.gagaeDanger : Color.gagaePinkDark)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background((kind == .need ? Color.gagaeDanger : Color.gagaePinkDark).opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Preview
#Preview {
    NavigationStack { WishListView() }
        .environment(AppEventBus())
}
