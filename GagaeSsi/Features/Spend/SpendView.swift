//
//  SpendView.swift
//  GagaeSsi
//
//  소비 기록 화면 (Claude Design 적용)
//

import SwiftUI

struct SpendView: View {
    // MARK: - Properties
    @State private var viewModel = SpendViewModel()
    @Environment(AppEventBus.self) private var eventBus
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var justSaved = false
    @State private var showShortfall = false
    @State private var shortfallCover = 0
    @State private var shortfallPool = 0
    @State private var showAssetTransfer = false

    enum Field { case title, amount, payback }

    // MARK: - Body
    var body: some View {
        ZStack {
            GagaeBackground()

            ScrollView {
                VStack(spacing: 14) {
                    inputCard
                        .padding(.top, 8)

                    saveButton

                    spendingListSection
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("소비 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.gagaePinkGradientTop, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAssetTransfer = true
                } label: {
                    HStack(spacing: 4) {
                        Text("📈").font(.system(size: 13))
                        Text("저축·투자")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.gagaePinkDark)
                }
            }
        }
        .sheet(isPresented: $showAssetTransfer) {
            AssetTransferView()
        }
        .onAppear {
            let today = Calendar.current.startOfDay(for: Date())
            viewModel.fetchSpending(on: today)
            viewModel.loadSuggestions()
            viewModel.loadSpendableWishes()
            viewModel.loadActiveTrips()
        }
        .onChange(of: viewModel.tempDate) { _, _ in viewModel.autoSelectTrip() }
        .onChange(of: viewModel.tempParticipants) { _, _ in viewModel.revalidateAutoWallet() }
        .onChange(of: viewModel.tempPaidByMe) { _, _ in viewModel.revalidateAutoWallet() }
        .alert("오류", isPresented: $viewModel.showErrorAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .confirmationDialog("모아둔 이월금 사용", isPresented: $showShortfall, titleVisibility: .visible) {
            Button("\(FormatterUtils.currencyString(from: shortfallCover)) 충당") {
                viewModel.coverShortfall(amount: shortfallCover, eventBus: eventBus)
            }
            Button("그대로 두기", role: .cancel) { }
        } message: {
            Text("오늘 예산이 \(FormatterUtils.currencyString(from: shortfallCover)) 부족해요.\n모아둔 이월금 \(FormatterUtils.currencyString(from: shortfallPool)) 중 \(FormatterUtils.currencyString(from: shortfallCover))을 가져와 채울까요?")
        }
        .onTapGesture { focusedField = nil }
    }
}

// MARK: - Input Card
extension SpendView {

    private var inputCard: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gagaePinkLight)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: viewModel.isEditing ? "pencil.line" : "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.gagaePinkDark)
                    )
                Text(viewModel.isEditing ? "지출 수정 중" : "오늘 쓴 거 기록해요")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                if viewModel.isEditing {
                    Button {
                        focusedField = nil
                        withAnimation { viewModel.cancelEdit() }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("취소")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.gagaeTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gagaeSurfaceAlt)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Rectangle().fill(Color.gagaeDivider).frame(height: 0.5)
                .padding(.horizontal, 16)

            VStack(spacing: 18) {
                categoryField
                contentField
                amountField
                    .disabled(viewModel.isTripLocked)
                // 금액 잠금 안내는 금액 필드 바로 옆에 둔다 — 분담 블록 안(예전 위치)은
                // 스크롤해야 보인다. 지갑 초과 안내는 지갑 섹션 쪽에 이미 있다(wishWalletField).
                if viewModel.isTripLocked {
                    Text("정산 완료 여행이라 금액을 바꿀 수 없어요")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
                if !viewModel.isSharedSpending { paybackField }
                dateField
                if !viewModel.activeTrips.isEmpty { tripField }
                // 연결됐던 여행을 찾을 수 없는(삭제된) 경우 — 피커가 안 보여도 알려준다
                if viewModel.tempTripId != nil && viewModel.selectedTrip == nil {
                    Text("연결됐던 여행을 찾을 수 없어요. 저장하면 여행 연결이 풀려요")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // 분담 블록은 여행 선택과 무관하게 뜬다 — 여행이 지워져도(deleteTrip) 분담은
                // 그대로 남으므로, activeTrips가 비어 있어도 분담 값이 있으면 보여줘야 한다.
                if viewModel.tempTripId != nil || viewModel.tempParticipants > 1 { tripShareFields }
                if !viewModel.spendableWishes.isEmpty {
                    wishWalletField
                        .disabled(viewModel.isTripLocked)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .background(Color.gagaeCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .gagaeCardShadow()
    }

    private func fieldLabel(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Text(icon).font(.system(size: 13))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.gagaeTextSecondary)
        }
    }

    /// ① 카테고리
    private var categoryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("🏷", "카테고리")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(SpendingCategory.allCases, id: \.self) { category in
                        categoryChip(category)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.bottom, 2)
            }
        }
    }

    private func categoryChip(_ category: SpendingCategory) -> some View {
        let isSelected = viewModel.tempCategory == category
        return Button {
            viewModel.tempCategory = category
        } label: {
            HStack(spacing: 5) {
                Text(category.emoji).font(.system(size: 14))
                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .gagaeTextSecondary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(isSelected ? category.color : Color.gagaeSurfaceAlt)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? .clear : Color.gagaeDivider, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: viewModel.tempCategory)
    }

    /// ② 내용
    private var contentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("📝", "내용")
            TextField("예: 점심 식사, 카페라떼", text: $viewModel.tempTitle)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.gagaeText)
                .focused($focusedField, equals: .title)
                .frame(height: 46)
                .padding(.horizontal, 14)
                .background(Color.gagaeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focusedField == .title ? Color.gagaePinkDark : Color.gagaeDivider,
                                lineWidth: focusedField == .title ? 1.8 : 1.5)
                )

            // 자동완성 추천 칩 (내용 입력 포커스 시)
            if focusedField == .title && !viewModel.titleSuggestions.isEmpty {
                suggestionChips
            }
        }
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(viewModel.titleSuggestions) { s in
                    Button {
                        viewModel.applySuggestion(s)
                        focusedField = .amount
                    } label: {
                        HStack(spacing: 5) {
                            Text("\(s.category.emoji) \(s.title)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.gagaeText)
                            Text(FormatterUtils.currencyString(from: s.lastAmount))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.gagaeTextTertiary)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color.gagaePinkLight)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// ③ 금액
    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("₩", "금액")
            HStack(spacing: 0) {
                Text("₩")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaePinkDark)
                    .frame(width: 46, height: 46)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(focusedField == .amount ? Color.gagaePinkLight : Color.gagaeDivider)
                            .frame(width: 1.5)
                    }

                TextField("0", text: $viewModel.tempAmountText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .amount)
                    .padding(.horizontal, 14)
                    .onChange(of: viewModel.tempAmountText) { _, newValue in
                        viewModel.updateAmountFromText(newValue)
                    }

                if viewModel.tempAmount > 0 {
                    Text("원")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                        .padding(.trailing, 14)
                }
            }
            .frame(height: 46)
            .background(Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == .amount ? Color.gagaePinkDark : Color.gagaeDivider,
                            lineWidth: focusedField == .amount ? 1.8 : 1.5)
            )
        }
    }

    /// ③-2 환급/페이백 예정 (선택). 이미 받은 환급(`isPaybackLocked`)은 편집 화면에서
    /// 고칠 수 없다 — `receivePayback`이 이미 올려놓은 CarryOverSource 크레딧의 근거이므로,
    /// 여기서 건드리게 두면 장부가 조용히 어긋난다.
    private var paybackField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $viewModel.tempHasPayback.animation()) {
                HStack(spacing: 6) {
                    Text(viewModel.isPaybackLocked ? "✅" : "💳").font(.system(size: 15))
                    Text(viewModel.isPaybackLocked ? "환급·페이백 완료" : "환급·페이백 예정")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.gagaeText)
                }
            }
            .tint(.gagaePinkDark)
            .disabled(viewModel.isPaybackLocked)

            if viewModel.isPaybackLocked {
                Text("이미 받은 환급이라 금액은 바꿀 수 없어요")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
            }

            if viewModel.tempHasPayback {
                HStack(spacing: 0) {
                    Text("₩")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                        .frame(width: 42, height: 44)
                    TextField("나중에 돌려받을 금액", text: $viewModel.tempExpectedPaybackText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .payback)
                        .padding(.horizontal, 6)
                        .onChange(of: viewModel.tempExpectedPaybackText) { _, v in
                            if let r = FormatterUtils.formatCurrencyInput(v) {
                                viewModel.tempExpectedPayback = r.plainNumber
                                viewModel.tempExpectedPaybackText = r.formatted
                            }
                        }
                        .disabled(viewModel.isPaybackLocked)
                }
                .frame(height: 44)
                .background(Color.gagaeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == .payback ? Color.gagaePinkDark : Color.gagaeDivider,
                            lineWidth: focusedField == .payback ? 1.8 : 1.5))

                if viewModel.tempExpectedPayback > 0 && viewModel.tempAmount > 0 {
                    Text("순 지출 \(FormatterUtils.currencyString(from: viewModel.tempAmount - viewModel.tempExpectedPayback)) · 지출은 전액으로 잡히고 받을 때 예산에 돌아와요")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
            }
        }
    }

    /// ⑥ 여행 — 같이 쓴 돈이면 인원과 결제자를 표시한다. 내 몫은 여행이 계산한다
    private var tripField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("🧳", "여행")

            VStack(spacing: 0) {
                // "여행 아님"은 잠긴 상태에서도 항상 눌러야 한다 — 이게 유일한 탈출구다.
                // 정산 완료 여행이 add 모드엔 취소 버튼이 없어, 이 행마저 잠기면 저장하거나
                // 화면을 나가는 것 말고는 빠져나갈 길이 없다.
                walletRow(title: "여행 아님", detail: "평소 소비예요",
                          selected: viewModel.tempTripId == nil) {
                    viewModel.selectTrip(nil)
                }
                ForEach(viewModel.activeTrips) { trip in
                    Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 14)
                    walletRow(title: trip.isSettled ? "\(trip.title) (정산 완료)" : trip.title,
                              detail: "\(FormatterUtils.shortDateRange(trip.startDate, trip.endDate)) · \(trip.defaultParticipants)명",
                              selected: viewModel.tempTripId == trip.id) {
                        viewModel.selectTrip(trip.id)
                    }
                    .disabled(viewModel.isTripLocked)
                }
            }
            .background(Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gagaeDivider, lineWidth: 1.5)
            )
        }
    }

    /// 인원 · 누가 냈나 · 미리보기.
    /// 여행을 고르지 않아도(`tempTripId == nil`) 인원이 1보다 크면 뜬다 — `deleteTrip`은 소비의
    /// 분담(participants·paidByMe)은 그대로 두고 여행 연결만 끊으므로, 여행 없이도 분담 소비는
    /// 존재할 수 있다. 숨기면 이 화면이 그 값을 못 보여주고, 못 보여준 값을 저장이 뭉갤 위험이 생긴다.
    private var tripShareFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("나누는 인원")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                // 여행 defaultParticipants는 최대 999명까지 허용한다 — 범위를 좁히면
                // 999명짜리 여행에서 온 값을 아래로도 위로도 조정할 수 없는 값이 생긴다.
                Stepper(value: $viewModel.tempParticipants, in: 1...999) {
                    Text(viewModel.tempParticipants == 1 ? "내 개인 소비" : "\(viewModel.tempParticipants)명")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                }
                .fixedSize()
                .disabled(viewModel.isTripLocked)
            }

            if viewModel.tempParticipants > 1 {
                Picker("누가 냈나", selection: $viewModel.tempPaidByMe) {
                    Text("내가 냈어요").tag(true)
                    Text("다른 사람이 냈어요").tag(false)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isTripLocked)

                if !viewModel.tripPreviewText.isEmpty {
                    Text(viewModel.tripPreviewText)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeGood)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if viewModel.willClearPaybackOnSave {
                Text("환급 예정 \(FormatterUtils.currencyString(from: viewModel.tempExpectedPayback))은 정산이 대신해요 — 저장하면 지워져요")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.isTripLocked {
                Text("정산이 끝난 여행이라 여행·인원·결제자·금액·지갑은 바꿀 수 없어요. 바꾸려면 여행 상세에서 정산을 먼저 다시 열어주세요.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.gagaeTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.gagaeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// ⑤ 모아둔 위시 지갑에서 쓰기 — 고르면 그날 예산에서 빠지지 않는다
    private var wishWalletField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("🎁", "모아둔 위시에서 쓰기")

            VStack(spacing: 0) {
                walletRow(title: "예산에서 쓰기", detail: "평소처럼 오늘 예산에서 빠져요",
                          selected: viewModel.tempWishItemId == nil) {
                    viewModel.pickWallet(nil)
                }
                ForEach(viewModel.spendableWishes) { wish in
                    Rectangle().fill(Color.gagaeDivider).frame(height: 0.5).padding(.leading, 14)
                    walletRow(title: wish.title,
                              detail: "남은 \(FormatterUtils.currencyString(from: wish.balance))",
                              selected: viewModel.tempWishItemId == wish.id) {
                        viewModel.pickWallet(wish.id)
                    }
                }
            }
            .background(Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gagaeDivider, lineWidth: 1.5)
            )

            if viewModel.tempWishItemId != nil {
                if viewModel.wishCoversAmount {
                    Text("모아둔 돈에서 빠져요. 오늘 쓸 수 있는 금액은 그대로예요.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeGood)
                } else {
                    Text("지갑에 \(FormatterUtils.currencyString(from: viewModel.selectedWishLimit))만 남았어요. 금액을 줄이거나 예산에서 쓰기를 골라주세요.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeDanger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func walletRow(title: String, detail: String, selected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? Color.gagaePinkDark : Color.gagaeDivider)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: selected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(.gagaeText)
                    Text(detail)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// ④ 날짜
    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("📅", "날짜")
            HStack {
                DatePicker("", selection: $viewModel.tempDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(.gagaePinkDark)
                Spacer()
                if Calendar.current.isDateInToday(viewModel.tempDate) {
                    Text("오늘")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaePinkDark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gagaePinkLight)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .frame(height: 46)
            .padding(.horizontal, 14)
            .background(Color.gagaeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gagaeDivider, lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Save Button
extension SpendView {
    private var saveButton: some View {
        Button {
            focusedField = nil
            viewModel.saveSpending(eventBus: eventBus) { success in
                if success {
                    let today = Calendar.current.startOfDay(for: Date())
                    viewModel.fetchSpending(on: today)
                    viewModel.loadSuggestions()
                    // 오늘 예산이 음수 + 모아둔 이월금이 있으면 부족액 충당 제안
                    if let (cover, pool) = viewModel.shortfallCoverage() {
                        shortfallCover = cover; shortfallPool = pool; showShortfall = true
                    }
                    viewModel.clearForm()
                    withAnimation { justSaved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        withAnimation { justSaved = false }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if justSaved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("저장 완료!")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    ZStack {
                        Circle().stroke(.white.opacity(0.6), lineWidth: 2).frame(width: 26, height: 26)
                        Image(systemName: viewModel.isEditing ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    }
                    Text(viewModel.isEditing ? "수정 완료" : "저장하기")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                justSaved
                    ? LinearGradient(colors: [.gagaeGood, .gagaeGood], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [.gagaePinkDark, .gagaePink], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .gagaeShadow(color: (justSaved ? Color.gagaeGood : Color.gagaePinkDark).opacity(0.32), radius: 14, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isValid && !justSaved)
        .opacity((viewModel.isValid || justSaved) ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.25), value: justSaved)
    }
}

// MARK: - Today's List
extension SpendView {
    private var spendingListSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("오늘 지출 목록")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                Spacer()
                if !viewModel.spendingRecords.isEmpty {
                    Text("총 -" + FormatterUtils.currencyString(from: viewModel.totalSpentToday))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.gagaeDanger)
                }
            }
            .padding(.horizontal, 2)

            if viewModel.spendingRecords.isEmpty {
                VStack(spacing: 8) {
                    Text("🐷").font(.system(size: 32))
                    Text("아직 기록된 지출이 없어요")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.gagaeCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .gagaeCardShadow()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.spendingRecords.enumerated()), id: \.element.id) { index, record in
                        spendingRow(record: record)
                        if index < viewModel.spendingRecords.count - 1 {
                            Rectangle().fill(Color.gagaeDivider).frame(height: 0.5)
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(Color.gagaeCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .gagaeCardShadow()

                // 합계 요약
                HStack {
                    Text("\(viewModel.spendingRecords.count)건의 지출")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                    Spacer()
                    Text("총 지출")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextSecondary)
                    Text("-" + FormatterUtils.currencyString(from: viewModel.totalSpentToday))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.gagaeDanger)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func spendingRow(record: SpendingRecordModel) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(record.category.color.opacity(0.13))
                    .frame(width: 40, height: 40)
                Text(record.category.emoji).font(.system(size: 19))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title.isEmpty ? record.category.rawValue : record.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.gagaeText)
                    .lineLimit(1)
                if record.isShared {
                    Text("🧳 결제 \(FormatterUtils.currencyString(from: record.amount)) · \(record.participants)명 · \(record.paidByMe ? "내가 냄" : "친구가 냄")")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                } else if record.tripId != nil {
                    Text("🧳 여행 개인 소비")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
                if record.expectedPayback > 0 {
                    Text(record.paybackReceived
                         ? "✅ 환급 완료 \(FormatterUtils.currencyString(from: record.expectedPayback))"
                         : "💳 환급 예정 \(FormatterUtils.currencyString(from: record.expectedPayback))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(record.paybackReceived ? .gagaeGood : .gagaePinkDark)
                } else {
                    Text(FormatterUtils.relativeDate(record.date))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.gagaeTextTertiary)
                }
            }

            Spacer()

            Text("-" + FormatterUtils.currencyString(from: record.myShare))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.gagaeDanger)

            if record.expectedPayback > 0 && !record.paybackReceived {
                Button {
                    viewModel.receivePayback(recordId: record.id, eventBus: eventBus)
                } label: {
                    Text("환급받음")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.gagaeGood).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                focusedField = nil
                withAnimation { viewModel.beginEdit(record) }
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gagaePinkLight)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.gagaePinkDark)
                    )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.deleteSpending(id: record.id, eventBus: eventBus)
                let today = Calendar.current.startOfDay(for: Date())
                viewModel.fetchSpending(on: today)
            } label: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gagaePinkPale)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.gagaeDanger)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(viewModel.editingRecordId == record.id ? Color.gagaePinkLight.opacity(0.4) : Color.clear)
    }
}

// MARK: - SpendViewModel Extension
extension SpendViewModel {
    /// 오늘 내가 쓴 돈 — 공용 소비는 내 몫만
    var totalSpentToday: Int {
        spendingRecords.reduce(0) { $0 + $1.myShare }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SpendView()
    }
    .environment(AppEventBus())
}
