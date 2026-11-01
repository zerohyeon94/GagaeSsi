//
//  TripListView.swift
//  GagaeSsi
//
//  여행 목록 — 진행 중 / 정산 완료
//

import SwiftUI

struct TripListView: View {
    @Environment(AppEventBus.self) private var eventBus
    @State private var trips: [TripModel] = []
    @State private var summaries: [UUID: TripSettlementModel] = [:]
    @State private var showAdd = false

    /// 기간 중이거나 아직 시작 전인 여행
    private var active: [TripModel] { trips.filter { !$0.isSettled && !$0.isAwaitingSettlement() } }
    /// 기간은 끝났는데 아직 정산하지 않은 여행 — 진행 중과 섞이지 않게 따로 묶는다 (#30)
    private var awaiting: [TripModel] { trips.filter { $0.isAwaitingSettlement() } }
    private var settled: [TripModel] { trips.filter { $0.isSettled } }

    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: GagaeSpacing.lg) {
                    infoCard.padding(.top, GagaeSpacing.md)
                    if trips.isEmpty {
                        GagaeCard {
                            GagaeEmptyStateView(icon: "🧳", title: "여행이 없어요",
                                                subtitle: "여행을 만들고 소비를 묶으면\n내 몫만 예산에서 빠지고 나중에 정산할 수 있어요")
                        }
                    } else {
                        section("진행 중", active)
                        section("정산 대기", awaiting)
                        section("정산 완료", settled)
                    }
                }
                .padding(.horizontal, GagaeSpacing.md)
                .padding(.bottom, GagaeSpacing.xl)
            }
        }
        .navigationTitle("여행")
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
        .onChange(of: eventBus.spendingAddedTrigger) { _, _ in load() }
        .sheet(isPresented: $showAdd) {
            TripEditView(mode: .add) {
                eventBus.notifySpendingAdded()
                load()
            }
        }
    }

    private var infoCard: some View {
        HStack(spacing: GagaeSpacing.md) {
            Image(systemName: "lightbulb.fill").font(.system(size: 20)).foregroundStyle(.gagaePoint)
            Text("같이 쓴 돈은 내 몫만 예산에서 빠져요.\n내가 대신 낸 돈은 정산 때 돌아와요.")
                .font(.gagaeSubheadline).foregroundStyle(.gagaeTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(GagaeSpacing.md).background(Color.gagaePoint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
    }

    @ViewBuilder
    private func section(_ title: String, _ list: [TripModel]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text(title).font(.gagaeHeadline).foregroundStyle(.gagaeText)
                ForEach(list) { trip in
                    NavigationLink { TripDetailView(tripId: trip.id) } label: { row(trip) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ trip: TripModel) -> some View {
        let s = summaries[trip.id]
        return GagaeCard {
            HStack(spacing: GagaeSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(trip.title).font(.gagaeHeadline).foregroundStyle(.gagaeText)
                        if trip.wishItemId != nil {
                            Text("🎁").font(.system(size: 13))
                        }
                    }
                    Text("\(FormatterUtils.shortDateRange(trip.startDate, trip.endDate)) · \(trip.defaultParticipants)명")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                    if trip.isSettled, let at = trip.settledAt {
                        Text("\(FormatterUtils.formattedDate(at)) 정산 · +\(FormatterUtils.currencyString(from: trip.settledAmount)) 돌아옴")
                            .font(.gagaeCaption).foregroundStyle(.gagaeGood)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("내 몫").font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                    Text(FormatterUtils.currencyString(from: s?.myShareTotal ?? 0))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.gagaeText)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.gagaeTextTertiary)
            }
        }
    }

    private func load() {
        trips = CoreDataManager.shared.fetchTrips()
        summaries = Dictionary(uniqueKeysWithValues: trips.map {
            ($0.id, CoreDataManager.shared.tripSettlement(for: $0.id))
        })
    }
}
