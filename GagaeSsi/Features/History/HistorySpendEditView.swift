//
//  HistorySpendEditView.swift
//  GagaeSsi
//
//  내역에서 과거 소비 수정 (저장 시 이월 체인 재계산 트리거)
//

import SwiftUI

/// 내역 편집 시트가 폼 값을 기록에 얹는 규칙.
///
/// **폼은 화면에 실제로 보여준 값만 덮어쓴다 — 숨겨진 필드가 저장된 데이터를 조용히
/// 바꾸면 안 된다.** `CoreDataManager.deleteTrip`은 `trip` 연결만 끊고 `participants`/
/// `paidByMe`는 그대로 두므로, `tripId == nil && participants == 3` 같은 상태가 정상일 수
/// 있다. 여행을 고르지 않았다고 인원·결제자를 1/true로 되돌리면 그 기록을 제목만 고쳐도
/// `budgetAmount`가 조용히 3배로 뛰고 그날 이후 이월 체인이 통째로 틀어진다.
///
/// 폼이 다루지 않는 필드(지갑 연결, 환급 수령 여부, id)는 원본에서 그대로 가져온다 —
/// 화면에 보여주지 않은 값을 저장 때 기본값으로 되돌리면 사용자가 모르는 사이 데이터가 바뀐다.
struct SpendingEditDraft {
    var title: String
    var amount: Int
    var category: SpendingCategory
    var date: Date
    var tripId: UUID?
    var participants: Int
    var paidByMe: Bool
    var hasPayback: Bool
    var payback: Int

    func applied(to record: SpendingRecordModel) -> SpendingRecordModel {
        var result = record
        result.title = title.isEmpty ? category.rawValue : title
        result.amount = amount
        result.category = category
        // date-only 피커라 시각 성분은 원래 기록의 것을 유지하려면 날짜만 교체
        let cal = Calendar.current
        let timeComps = cal.dateComponents([.hour, .minute, .second], from: record.date)
        result.date = cal.date(bySettingHour: timeComps.hour ?? 0, minute: timeComps.minute ?? 0,
                               second: timeComps.second ?? 0, of: cal.startOfDay(for: date)) ?? date
        result.tripId = tripId
        // 화면에 보여준 값을 그대로 쓴다 — tripId == nil이라고 1/true로 강제하지 않는다
        result.participants = max(1, participants)
        result.paidByMe = paidByMe
        // 공용 소비는 정산이 환급 역할을 하므로 환급 필드를 비운다 — 단, 이미 받은 환급은
        // 예외다. `receivePayback`이 이미 CarryOverSource 크레딧을 올려놨는데 여기서 0으로
        // 지우면 그 크레딧을 설명할 근거가 사라져 장부가 조용히 어긋난다.
        if record.paybackReceived {
            result.expectedPayback = record.expectedPayback
        } else {
            result.expectedPayback = (hasPayback && !result.isShared) ? payback : 0
        }
        // id, wishItemId, paybackReceived는 폼이 다루지 않으므로 record 값 그대로 유지된다
        return result
    }
}

struct HistorySpendEditView: View {
    let record: SpendingRecordModel
    /// 저장 완료 콜백
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amountText = ""
    @State private var amount = 0
    @State private var category: SpendingCategory = .other
    @State private var date = Date()
    @State private var hasPayback = false
    @State private var paybackText = ""
    @State private var payback = 0
    @FocusState private var amountFocused: Bool

    // 여행
    @State private var tripId: UUID?
    @State private var participants = 1
    @State private var paidByMe = true
    @State private var trips: [TripModel] = []

    private var selectedTrip: TripModel? { trips.first { $0.id == tripId } }
    /// 정산 완료 여행의 소비는 여행·인원·결제자·금액을 못 바꾼다
    private var isTripLocked: Bool { selectedTrip?.isSettled == true }
    private var draft: SpendingEditDraft {
        SpendingEditDraft(title: title, amount: amount, category: category, date: date,
                          tripId: tripId, participants: participants, paidByMe: paidByMe,
                          hasPayback: hasPayback, payback: payback)
    }
    /// 지금 입력값 미리보기 — 내 몫·분담 여부 판정용
    private var preview: SpendingRecordModel { draft.applied(to: record) }
    private var isShared: Bool { preview.isShared }

    private var isValid: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.gagaeBackground.ignoresSafeArea()
                ScrollView {
                    GagaeCard {
                        VStack(alignment: .leading, spacing: GagaeSpacing.md) {
                            // 카테고리
                            Label("카테고리", systemImage: "square.grid.2x2.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 7) {
                                    ForEach(SpendingCategory.allCases, id: \.self) { c in
                                        Button { category = c } label: {
                                            Text("\(c.emoji) \(c.rawValue)")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundStyle(category == c ? .white : .gagaeTextSecondary)
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(category == c ? c.color : Color.gagaeSurface)
                                                .clipShape(Capsule())
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }

                            // 항목명
                            Label("내용", systemImage: "tag.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            TextField("내용", text: $title)
                                .font(.gagaeBody).padding(GagaeSpacing.md)
                                .background(Color.gagaeSurface).clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            // 금액
                            Label("금액", systemImage: "wonsign.circle.fill")
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
                            HStack(spacing: GagaeSpacing.sm) {
                                Text("₩").font(.gagaeTitle3).foregroundStyle(.gagaePinkDark)
                                TextField("0", text: $amountText)
                                    .font(.gagaeTitle3).keyboardType(.numberPad).focused($amountFocused)
                                    .onChange(of: amountText) { _, v in
                                        if let r = FormatterUtils.formatCurrencyInput(v) { amount = r.plainNumber; amountText = r.formatted }
                                    }
                                    .disabled(isTripLocked)
                            }
                            .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                            .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))

                            // 날짜
                            DatePicker("날짜", selection: $date, displayedComponents: .date)
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary).tint(.gagaePinkDark)

                            // 여행 (진행 중 여행이 있거나 이미 묶여 있을 때만)
                            if !trips.isEmpty {
                                tripField
                            }
                            // 분담 블록은 여행 선택과 무관하게 뜬다 — `deleteTrip`은 소비의
                            // participants/paidByMe는 그대로 두고 여행 연결만 끊으므로, trips가
                            // 비어 있어도(모든 여행이 없어져도) 분담 값이 남아있으면 보여줘야 한다.
                            if tripId != nil || participants > 1 {
                                tripShareFields
                            }

                            // 환급 예정 — 공용 소비는 정산이 환급 역할을 하므로 숨긴다 (이중 반영 방지)
                            if !isShared {
                                Toggle(isOn: $hasPayback.animation()) {
                                    Text("💳 환급·페이백 예정")
                                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                                }.tint(.gagaePinkDark)
                                if hasPayback {
                                    HStack(spacing: GagaeSpacing.sm) {
                                        Text("₩").font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                                        TextField("환급 예정 금액", text: $paybackText)
                                            .keyboardType(.numberPad)
                                            .onChange(of: paybackText) { _, v in
                                                if let r = FormatterUtils.formatCurrencyInput(v) { payback = r.plainNumber; paybackText = r.formatted }
                                            }
                                    }
                                    .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                                }
                            } else if payback > 0 && !record.paybackReceived {
                                // 공용으로 바뀌어 환급 필드가 숨겨졌는데 저장하면 실제로 지워지는 경우만 안내한다.
                                // 이미 받은 환급(record.paybackReceived)은 저장해도 지우지 않으므로 안내하지 않는다.
                                Text("환급 예정 \(FormatterUtils.currencyString(from: payback))은 정산이 대신해요 — 저장하면 지워져요")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Text("바꾸면 이후 날짜의 사용 가능 금액과 이월금이 다시 계산돼요.")
                                .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)

                    GagaePrimaryButton(title: "저장하기", isEnabled: isValid) { save() }
                        .padding(.horizontal, GagaeSpacing.md).padding(.top, GagaeSpacing.md)
                }
            }
            .navigationTitle("소비 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("취소") { dismiss() }.foregroundStyle(.gagaePinkDark) }
            }
            .onAppear { loadRecord() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func loadRecord() {
        title = record.title
        amount = record.amount
        amountText = FormatterUtils.inputAmountString(from: record.amount)
        category = record.category
        date = record.date
        payback = record.expectedPayback
        paybackText = record.expectedPayback > 0 ? FormatterUtils.inputAmountString(from: record.expectedPayback) : ""
        hasPayback = record.expectedPayback > 0

        tripId = record.tripId
        participants = record.participants
        paidByMe = record.paidByMe
        var active = CoreDataManager.shared.fetchActiveTrips()
        // 편집 중인 기록이 정산 완료 여행에 묶여 있으면 그 여행도 보여야 한다 (잠긴 채로)
        if let id = record.tripId, !active.contains(where: { $0.id == id }),
           let linked = CoreDataManager.shared.fetchTrip(id: id) {
            active.append(linked)
        }
        trips = active
    }

    private func save() {
        guard isValid else { return }
        if CoreDataManager.shared.updateSpendingRecord(draft.applied(to: record)) {
            onSaved()
            dismiss()
        }
    }
}

// MARK: - 여행 필드
extension HistorySpendEditView {
    /// 여행 선택 — "여행 아님" + 진행 중(및 이 기록이 묶인 정산 완료) 여행 목록
    private var tripField: some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            Label("여행", systemImage: "suitcase.fill")
                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary)
            Picker("여행", selection: $tripId) {
                Text("여행 아님").tag(UUID?.none)
                ForEach(trips) { t in
                    Text(t.isSettled ? "\(t.title) (정산 완료)" : t.title).tag(UUID?.some(t.id))
                }
            }
            .pickerStyle(.menu).tint(.gagaePinkDark)
            .disabled(isTripLocked)
            .onChange(of: tripId) { _, newValue in
                // 여행을 고르면 인원 기본값과 결제자를 채운다. "여행 아님"으로 풀 때는
                // participants/paidByMe를 건드리지 않는다 — 여행이 지워져(deleteTrip) 이미
                // 분담 상태였던 기록을 여기서 1/true로 되돌리면, 화면엔 안 보이던 값이 저장 때
                // 조용히 바뀐다. 분담 블록이 그 값을 그대로 보여주므로 사용자가 직접 고칠 수 있다.
                if let t = trips.first(where: { $0.id == newValue }) {
                    participants = max(1, t.defaultParticipants)
                    paidByMe = true
                }
            }
        }
    }

    /// 인원 · 누가 냈나 · 미리보기.
    /// `tripId != nil || participants > 1`일 때만 호출된다 — 여행 없이도 분담 소비는 있을 수 있다.
    private var tripShareFields: some View {
        VStack(alignment: .leading, spacing: GagaeSpacing.sm) {
            HStack {
                Text("나누는 인원")
                    .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                Spacer()
                // 999명까지 허용한다 — 범위를 좁히면 999명짜리 여행에서 온 값을 조정할 수 없다.
                Stepper(value: $participants, in: 1...999) {
                    Text(participants == 1 ? "내 개인 소비" : "\(participants)명")
                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                }
                .fixedSize()
                .disabled(isTripLocked)
            }

            if participants > 1 {
                Picker("누가 냈나", selection: $paidByMe) {
                    Text("내가 냈어요").tag(true)
                    Text("다른 사람이 냈어요").tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(isTripLocked)

                if amount > 0 {
                    let share = FormatterUtils.currencyString(from: preview.myShare)
                    Text(paidByMe
                         ? "내 몫 \(share) · 정산 때 \(FormatterUtils.currencyString(from: preview.receivable)) 돌아와요"
                         : "내 몫 \(share)만큼만 그날 예산에서 빠져요")
                        .font(.gagaeCaption).foregroundStyle(.gagaeGood)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isTripLocked {
                Text("정산이 끝난 여행이라 여행·인원·결제자·금액은 바꿀 수 없어요. 바꾸려면 여행 상세에서 정산을 먼저 다시 열어주세요.")
                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(GagaeSpacing.md).background(Color.gagaeSurface)
        .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
    }
}
