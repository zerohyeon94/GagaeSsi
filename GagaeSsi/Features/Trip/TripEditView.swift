//
//  TripEditView.swift
//  GagaeSsi
//
//  여행 추가/편집 시트 — 제목·기간·인원·지갑 연결
//

import SwiftUI

struct TripEditView: View {
    enum Mode {
        case add
        case edit(TripModel)
        var title: String { switch self { case .add: return "여행 추가"; case .edit: return "여행 수정" } }
    }

    let mode: Mode
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var endDate = Calendar.current.startOfDay(for: Date())
    @State private var participants = 2
    @State private var wishItemId: UUID?
    @State private var wallets: [WishItemModel] = []
    @FocusState private var focused: Bool

    private var isValid: Bool { !title.isEmpty && endDate >= startDate && participants >= 1 }
    private var selectedWallet: WishItemModel? { wallets.first { $0.id == wishItemId } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            Label("여행 이름", systemImage: "suitcase.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            TextField("예: 제주 여행, 부산 친구들", text: $title)
                                .font(.gagaeBody).focused($focused)
                                .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                                .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary).tint(.gagaePinkDark)
                            DatePicker("종료일", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary).tint(.gagaePinkDark)

                            HStack {
                                Label("인원", systemImage: "person.2.fill")
                                    .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                                Spacer()
                                Stepper(value: $participants, in: 1...20) {
                                    Text("\(participants)명").font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                                }.fixedSize()
                            }
                            Text("소비를 적을 때 인원 기본값이에요. 항목마다 바꿀 수 있어요.")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)

                            GagaeDivider()

                            // 지갑 연결
                            Label("모아둔 위시 지갑", systemImage: "gift.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            Picker("지갑", selection: $wishItemId) {
                                Text("연결 안 함").tag(UUID?.none)
                                ForEach(wallets) { w in
                                    Text("\(w.title) · 남은 \(FormatterUtils.currencyString(from: w.balance))")
                                        .tag(UUID?.some(w.id))
                                }
                            }
                            .pickerStyle(.menu).tint(.gagaePinkDark)
                            if let w = selectedWallet {
                                Text("이 여행에서 내가 내는 소비는 \(w.title) 지갑(남은 \(FormatterUtils.currencyString(from: w.balance)))에서 먼저 빠지고, 정산으로 돌아온 돈도 지갑으로 와요.")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeGood)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("연결하지 않으면 평소처럼 하루 예산에서 빠져요.")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "저장하기", isEnabled: isValid) { save() }
                        .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark)
                }
            }
            .onAppear { load() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func load() {
        var list = CoreDataManager.shared.fetchSpendableWishItems()
        if case .edit(let t) = mode {
            title = t.title
            startDate = t.startDate
            endDate = t.endDate
            participants = t.defaultParticipants
            wishItemId = t.wishItemId
            // 연결된 지갑은 잔액이 0이 됐어도 후보로 남겨야 한다
            if let id = t.wishItemId, !list.contains(where: { $0.id == id }),
               let linked = CoreDataManager.shared.fetchWishItems().first(where: { $0.id == id }) {
                list.append(linked)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true }
        }
        wallets = list
    }

    private func save() {
        guard isValid else { return }
        let ok: Bool
        switch mode {
        case .add:
            ok = CoreDataManager.shared.createTrip(TripModel(
                title: title, startDate: startDate, endDate: endDate,
                defaultParticipants: participants, wishItemId: wishItemId))
        case .edit(let t):
            // updateTrip은 편집 필드만 받는다 — TripModel을 통째로 덮으면 정산 상태
            // (status·settledAmount·settlementEntryId)가 폼 기본값으로 조용히 되돌아간다.
            ok = CoreDataManager.shared.updateTrip(
                id: t.id, title: title, startDate: startDate, endDate: endDate,
                defaultParticipants: participants, wishItemId: wishItemId)
        }
        if ok { onSave(); dismiss() }
    }
}
