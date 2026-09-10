//
//  TripDetailView.swift
//  GagaeSsi
//
//  여행 상세 — 총 지출 / 내 몫 / 내가 낸 돈 / 받을 돈, 소비 목록, 정산
//

import SwiftUI

struct TripDetailView: View {
    let tripId: UUID

    @Environment(AppEventBus.self) private var eventBus
    @Environment(\.dismiss) private var dismiss
    @State private var trip: TripModel?
    @State private var records: [SpendingRecordModel] = []
    @State private var settlement = TripSettlementModel.compute(records: [])
    @State private var walletTitle: String?
    @State private var showEdit = false
    @State private var showSettle = false
    @State private var showDeleteConfirm = false
    @State private var showReopenFailed = false
    @State private var editingRecord: SpendingRecordModel?

    private let cal = Calendar.current

    var body: some View {
        ZStack {
            Color.gagaeBackground.ignoresSafeArea()
            if let trip {
                ScrollView {
                    VStack(spacing: GagaeSpacing.lg) {
                        if trip.isSettled { settledCard(trip) } else { summaryCard }
                        recordsSection(trip)
                        if !trip.isSettled {
                            GagaePrimaryButton(title: "정산하기", isEnabled: !records.isEmpty) { showSettle = true }
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md)
                    .padding(.top, GagaeSpacing.md)
                    .padding(.bottom, GagaeSpacing.xl)
                }
            }
        }
        .navigationTitle(trip?.title ?? "여행")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaeBackground, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("여행 수정") { showEdit = true }
                    Button("여행 삭제", role: .destructive) { showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.system(size: 18)).foregroundStyle(.gagaePinkDark)
                }
            }
        }
        .onAppear { load() }
        .onChange(of: eventBus.spendingAddedTrigger) { _, _ in load() }
        .sheet(isPresented: $showEdit) {
            if let trip { TripEditView(mode: .edit(trip)) { load() } }
        }
        .sheet(isPresented: $showSettle) {
            if let trip {
                TripSettleSheet(trip: trip, settlement: settlement, walletTitle: walletTitle) { amount in
                    if CoreDataManager.shared.settleTrip(id: trip.id, actualAmount: amount) {
                        eventBus.notifySpendingAdded()   // 예산·지갑 크레딧 → 홈 갱신
                        load()
                    }
                }
            }
        }
        .sheet(item: $editingRecord) { record in
            HistorySpendEditView(record: record) {
                eventBus.notifySpendingAdded()
                load()
            }
        }
        .confirmationDialog("여행을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if CoreDataManager.shared.deleteTrip(id: tripId) {
                    eventBus.notifySpendingAdded()
                    dismiss()
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("소비 기록은 그대로 남고 여행 연결만 풀려요. 이미 정산한 돈은 돌려받지 않아요.")
        }
        .alert("되돌릴 수 없어요", isPresented: $showReopenFailed) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("지갑으로 돌아온 정산금을 이미 다른 소비에 써서 정산을 다시 열 수 없어요.")
        }
    }

    // MARK: - 요약

    private var summaryCard: some View {
        GagaeCard {
            VStack(spacing: GagaeSpacing.md) {
                HStack(spacing: GagaeSpacing.sm) {
                    cell("총 지출", settlement.totalPaid, .gagaeText)
                    cell("내 몫", settlement.myShareTotal, .gagaeText)
                }
                HStack(spacing: GagaeSpacing.sm) {
                    cell("내가 낸 돈", settlement.paidByMeTotal, .gagaeText)
                    cell(settlement.receivable > 0 ? "받을 돈" : "받을 돈 없음", settlement.receivable,
                         settlement.receivable > 0 ? .gagaeGood : .gagaeTextTertiary)
                }
                if walletTitle != nil {
                    Text("🎁 지갑에서 \(FormatterUtils.currencyString(from: settlement.fromWallet)) · 예산에서 \(FormatterUtils.currencyString(from: settlement.fromBudget))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                }
            }
        }
    }

    private func cell(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
            Text(FormatterUtils.currencyString(from: value))
                .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(color)
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GagaeSpacing.sm)
        .background(Color.gagaeSurface)
        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
    }

    private func settledCard(_ trip: TripModel) -> some View {
        GagaeCard {
            VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                Text("✅ 정산 완료").font(.gagaeHeadline).foregroundStyle(.gagaeGood)
                if let per = settlement.perPersonSpending, let n = settlement.uniformParticipants {
                    Text("인당 \(FormatterUtils.currencyString(from: per)) (\(n)명)")
                        .font(.gagaeSubheadline).foregroundStyle(.gagaeText)
                } else {
                    Text("내 몫 \(FormatterUtils.currencyString(from: settlement.myShareTotal))")
                        .font(.gagaeSubheadline).foregroundStyle(.gagaeText)
                }
                Text("받은 돈 \(FormatterUtils.currencyString(from: trip.settledAmount)) · \(walletTitle.map { "🎁 \($0) 지갑으로 돌아감" } ?? "오늘 예산으로 들어옴")")
                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let at = trip.settledAt {
                    Text(FormatterUtils.formattedDate(at)).font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                }
                GagaeSecondaryButton(title: "정산 다시 열기") {
                    if CoreDataManager.shared.reopenTrip(id: trip.id) {
                        eventBus.notifySpendingAdded()
                        load()
                    } else {
                        showReopenFailed = true
                    }
                }
            }
        }
    }

    // MARK: - 소비 목록

    private func recordsSection(_ trip: TripModel) -> some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            Text("소비 \(records.count)건").font(.gagaeHeadline).foregroundStyle(.gagaeText)
            if records.isEmpty {
                GagaeCard {
                    GagaeEmptyStateView(icon: "🧳", title: "아직 묶인 소비가 없어요",
                                        subtitle: "기록 탭에서 소비를 적을 때 이 여행을 고르면 여기 모여요")
                }
            } else {
                ForEach(groupedByDay, id: \.day) { group in
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
                            Text(FormatterUtils.formattedDate(group.day))
                                .font(.gagaeCaptionMedium).foregroundStyle(.gagaeTextSecondary)
                            ForEach(group.records) { r in
                                recordRow(r, locked: trip.isSettled)
                                if r.id != group.records.last?.id { GagaeDivider() }
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedByDay: [(day: Date, records: [SpendingRecordModel])] {
        let dict = Dictionary(grouping: records) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted().map { (day: $0, records: dict[$0] ?? []) }
    }

    private func recordRow(_ r: SpendingRecordModel, locked: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(r.category.color.opacity(0.13)).frame(width: 34, height: 34)
                Text(r.category.emoji).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(r.title.isEmpty ? r.category.rawValue : r.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.gagaeText).lineLimit(1)
                HStack(spacing: 4) {
                    if r.isShared {
                        chip("\(r.participants)명")
                        chip(r.paidByMe ? "내가 냄" : "친구가 냄")
                    } else {
                        chip("개인")
                    }
                    if r.wishItemId != nil { chip("🎁 지갑") }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(FormatterUtils.currencyString(from: r.amount))
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.gagaeText)
                if r.isShared {
                    Text("내 몫 \(FormatterUtils.currencyString(from: r.myShare))")
                        .font(.gagaeCaption).foregroundStyle(.gagaeTextSecondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !locked { editingRecord = r } }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.gagaeTextSecondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.gagaeSurfaceAlt).clipShape(Capsule())
    }

    // MARK: - Load

    private func load() {
        trip = CoreDataManager.shared.fetchTrip(id: tripId)
        records = CoreDataManager.shared.fetchSpendingRecords(tripId: tripId)
        settlement = TripSettlementModel.compute(records: records)
        walletTitle = trip?.wishItemId.flatMap { id in
            CoreDataManager.shared.fetchWishItems().first { $0.id == id }?.title
        }
    }
}
