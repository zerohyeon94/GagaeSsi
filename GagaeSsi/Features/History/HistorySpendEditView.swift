//
//  HistorySpendEditView.swift
//  GagaeSsi
//
//  내역에서 과거 소비 수정 (저장 시 이월 체인 재계산 트리거)
//
//  폼→기록 규칙(`SpendingEditDraft`)은 `Models/SpendingEditDraft.swift`에 있다 — 소비 입력
//  탭(SpendViewModel)의 편집 모드도 같은 타입을 거친다. **폼은 보여준 값은 반드시 쓰고,
//  보여주지 않은 값은 절대 건드리지 않는다.**
//

import SwiftUI

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
    /// 공용 소비인지 — `SpendingRecordModel.isShared`와 같은 규칙(participants > 1)을
    /// 화면 상태에서 직접 판정한다. `preview.isShared`로 우회하면 `draft.applied(to:)`
    /// 하나(Calendar 연산 3회 + 구조체 복사 2회)를 이 값 하나 보자고 매번 돌리게 된다.
    private var isShared: Bool { participants > 1 }

    /// 여행을 바꿔 예전 여행의 지갑 연결을 놓아줘야 하는지. `record.tripId`가 가리키던
    /// (원래) 여행의 지갑과 `record.wishItemId`가 같을 때만 — 여행과 무관하게 고른 지갑까지
    /// 건드리면 안 된다.
    private var clearsWallet: Bool {
        guard tripId != record.tripId, let wishId = record.wishItemId else { return false }
        let oldTripWallet = trips.first { $0.id == record.tripId }?.wishItemId
        return wishId == oldTripWallet
    }
    private var draft: SpendingEditDraft {
        SpendingEditDraft(title: title, amount: amount, category: category, date: date,
                          tripId: tripId, participants: participants, paidByMe: paidByMe,
                          hasPayback: hasPayback, payback: payback, clearsWallet: clearsWallet)
    }
    /// 지금 입력값 미리보기 — 내 몫·분담 여부 판정용
    private var preview: SpendingRecordModel { draft.applied(to: record) }

    /// 지갑이 연결돼 있고(그리고 이번 저장으로 풀리는 게 아니고) 새 금액이 지갑 잔액을
    /// 넘으면 그 한도. `SpendView`는 이 경우 저장 버튼 자체를 막는다 — 여기도 같은 기준을 쓴다.
    private var wishLimit: Int? {
        guard !clearsWallet, let wishId = record.wishItemId else { return nil }
        return CoreDataManager.shared.wishSpendableLimit(for: wishId, excluding: record.id)
    }
    private var wishExceeded: Bool {
        guard let limit = wishLimit else { return false }
        return preview.budgetAmount > limit
    }

    private var isValid: Bool { amount > 0 && !wishExceeded }

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
                            // 금액 잠금·초과 안내는 금액 필드 바로 옆에 둔다 — 분담 블록 안에
                            // 묻어두면(예전 위치) 스크롤해야 보인다.
                            if isTripLocked {
                                Text("정산 완료 여행이라 금액을 바꿀 수 없어요")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                            } else if wishExceeded {
                                Text("지갑에 \(FormatterUtils.currencyString(from: wishLimit ?? 0))만 남았어요. 금액을 줄여야 저장할 수 있어요.")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeDanger)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // 날짜
                            DatePicker("날짜", selection: $date, displayedComponents: .date)
                                .font(.gagaeFootnote).foregroundStyle(.gagaeTextSecondary).tint(.gagaePinkDark)

                            // 여행 (진행 중 여행이 있거나 이미 묶여 있을 때만)
                            if !trips.isEmpty {
                                tripField
                            }
                            // 연결됐던 여행을 찾을 수 없는(삭제된) 경우 — 피커가 안 보여도 알려준다
                            if tripId != nil && selectedTrip == nil {
                                Text("연결됐던 여행을 찾을 수 없어요. 저장하면 여행 연결이 풀려요")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if clearsWallet {
                                Text("여행을 바꿔서 지갑 연결은 풀렸어요 — 이 소비는 예산에서 빠져요")
                                    .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
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
                                    Text(record.paybackReceived ? "✅ 환급 완료" : "💳 환급·페이백 예정")
                                        .font(.gagaeCalloutMedium).foregroundStyle(.gagaeText)
                                }
                                .tint(.gagaePinkDark)
                                .disabled(record.paybackReceived)
                                if record.paybackReceived {
                                    Text("이미 받은 환급이라 금액은 바꿀 수 없어요")
                                        .font(.gagaeCaption).foregroundStyle(.gagaeTextTertiary)
                                }
                                if hasPayback {
                                    HStack(spacing: GagaeSpacing.sm) {
                                        Text("₩").font(.gagaeCalloutMedium).foregroundStyle(.gagaePinkDark)
                                        TextField("환급 예정 금액", text: $paybackText)
                                            .keyboardType(.numberPad)
                                            .onChange(of: paybackText) { _, v in
                                                if let r = FormatterUtils.formatCurrencyInput(v) { payback = r.plainNumber; paybackText = r.formatted }
                                            }
                                            .disabled(record.paybackReceived)
                                    }
                                    .padding(GagaeSpacing.md).background(Color.gagaeSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: GagaeRadius.md))
                                }
                            } else if hasPayback && payback > 0 && !record.paybackReceived {
                                // 공용으로 바뀌어 환급 필드가 숨겨졌는데 저장하면 실제로 지워지는 경우만 안내한다.
                                // 이미 받은 환급(record.paybackReceived)은 저장해도 지우지 않으므로 안내하지 않는다.
                                // hasPayback도 같이 봐야 한다 — 사용자가 토글을 이미 꺼놨으면(payback 값은
                                // 남아있어도) "지워져요"라고 알릴 게 없다.
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

    /// 여행을 고르거나(id) 푼다(nil). 피커의 selection Binding에서만 호출된다(아래 `tripField`) —
    /// `onChange(of: tripId)`를 쓰지 않는 이유는, `loadRecord()`가 `onAppear`에서 `tripId`를
    /// 직접 대입하는 것도 `onChange`엔 "변화"로 잡히기 때문이다(Task 7에서 실제로 재현된 버그:
    /// `tripField`가 `if !trips.isEmpty`로 첫 렌더에는 없다가 나중에 나타나 우연히 안 걸렸을
    /// 뿐, 레이아웃이 바뀌면 다시 터진다). 이 메서드는 사용자가 실제로 행을 탭했을 때만
    /// 호출되므로 그 문제 자체가 없다.
    private func selectTrip(_ newValue: UUID?) {
        tripId = newValue
        // 여행을 고르면 인원 기본값과 결제자를 채운다. "여행 아님"으로 풀 때는
        // participants/paidByMe를 건드리지 않는다 — 여행이 지워져(deleteTrip) 이미
        // 분담 상태였던 기록을 여기서 1/true로 되돌리면, 화면엔 안 보이던 값이 저장 때
        // 조용히 바뀐다. 분담 블록이 그 값을 그대로 보여주므로 사용자가 직접 고칠 수 있다.
        if let t = trips.first(where: { $0.id == newValue }) {
            participants = max(1, t.defaultParticipants)
            paidByMe = true
        }
    }

    private func save() {
        guard isValid else { return }
        let d = draft
        if CoreDataManager.shared.updateSpendingRecord(d.applied(to: record)) {
            // `updateSpendingRecord`는 `wishItemId`를 읽지 않으므로 지갑 연결 해제는 따로 한다
            if d.clearsWallet {
                CoreDataManager.shared.unlinkSpendingFromWish(recordId: record.id)
            }
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
            // selection을 커스텀 Binding으로 감싸 `selectTrip(_:)`을 통해서만 바뀌게 한다 —
            // 실제 사용자 선택 때만 인원·결제자 기본값을 채우기 위해서다 (위 selectTrip 주석 참고)
            Picker("여행", selection: Binding(get: { tripId }, set: { selectTrip($0) })) {
                Text("여행 아님").tag(UUID?.none)
                ForEach(trips) { t in
                    Text(t.isSettled ? "\(t.title) (정산 완료)" : t.title).tag(UUID?.some(t.id))
                }
            }
            .pickerStyle(.menu).tint(.gagaePinkDark)
            .disabled(isTripLocked)
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
                    let p = preview
                    let share = FormatterUtils.currencyString(from: p.myShare)
                    Text(paidByMe
                         ? "내 몫 \(share) · 정산 때 \(FormatterUtils.currencyString(from: p.receivable)) 돌아와요"
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
