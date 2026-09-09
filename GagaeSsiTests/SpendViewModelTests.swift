//
//  SpendViewModelTests.swift
//  GagaeSsi
//
//  Task 7 코드 리뷰에서 나온 Critical 버그 3건의 회귀 테스트.
//  "폼은 화면에 실제로 보여준 값만 덮어쓴다 — 숨겨진 필드가 저장된 데이터를 조용히
//  바꾸면 안 된다"는 규칙을 지킨다.
//

import XCTest
@testable import GagaeSsi

final class SpendViewModelTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        setupConfig()
        makeDay(0)
    }
    override func tearDownWithError() throws { sut = nil }

    // MARK: - Helpers (TripTests와 동일한 패턴)

    func day(_ offset: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: Date())!)
    }
    /// 테스트 구간에 급여일이 걸리면 부채 흡수가 끼어들어 실행일에 따라 단정이 깨진다
    private var safePayday: Int {
        ((cal.component(.day, from: Date()) + 13 - 1) % 28) + 1
    }
    private func setupConfig() {
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: safePayday, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true))
    }
    func makeDay(_ offset: Int, available: Int = 100_000) {
        guard sut.fetchDailyBudgetModel(date: day(offset)) == nil else { return }
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: available, date: day(offset),
                                                   carryOverSources: [], spendingRecords: []))
    }
    /// 목표를 이미 채운 지갑을 만든다 (TripTests와 같은 방식)
    @discardableResult
    func seedWallet(_ amount: Int, title: String = "지갑") -> UUID {
        makeDay(-5)
        let wish = WishItemModel(title: title, targetAmount: amount, dailySaving: amount,
                                 status: .saving, activatedAt: day(-5))
        _ = sut.createWishItem(wish)
        _ = sut.activateWish(id: wish.id, dailySaving: amount)
        sut.processDailyBudgets(upTo: day(0))
        return wish.id
    }
    @discardableResult
    func makeTrip(_ title: String = "여행", from: Int = 0, to: Int = 2, participants: Int = 3,
                  wishItemId: UUID? = nil) -> TripModel {
        let trip = TripModel(title: title, startDate: day(from), endDate: day(to),
                             defaultParticipants: participants, wishItemId: wishItemId)
        XCTAssertTrue(sut.createTrip(trip))
        return trip
    }

    // MARK: - Fix 1: 여행을 바꾸면 이전 여행의 자동 선택 지갑을 놓아준다

    func test_다른_여행을_고르면_이전_여행_지갑은_놓아준다() {
        let walletA = seedWallet(100_000, title: "A지갑")
        let walletB = seedWallet(100_000, title: "B지갑")
        let tripA = makeTrip("A여행", wishItemId: walletA)
        let tripB = makeTrip("B여행", wishItemId: walletB)

        let vm = SpendViewModel(manager: sut)
        vm.tempAmount = 10_000
        vm.loadSpendableWishes()
        vm.loadActiveTrips()

        vm.selectTrip(tripA.id)
        XCTAssertEqual(vm.tempWishItemId, walletA, "A를 고르면 A 지갑이 자동 선택돼야 한다")

        vm.selectTrip(tripB.id)
        XCTAssertNotEqual(vm.tempWishItemId, walletA,
                           "B를 골랐는데 A 지갑이 남아있으면 B 여행 소비가 A 지갑에서 빠져나간다")
    }

    // MARK: - Fix 2: 여행이 지워진 분담 기록을 편집해도 인원·결제자는 그대로다

    func test_여행_삭제된_분담_기록을_편집해도_인원과_결제자는_유지된다() {
        // deleteTrip은 trip 연결만 끊고 participants/paidByMe는 그대로 둔다 — 그 상태를 재현
        let record = SpendingRecordModel(title: "저녁", amount: 90_000, date: day(0),
                                         tripId: nil, participants: 3, paidByMe: false)
        XCTAssertTrue(sut.createSpendingRecord(record))

        let vm = SpendViewModel(manager: sut)
        vm.beginEdit(record)
        // 폼에서 실제로 바꾸는 건 제목뿐 — 인원·결제자 컨트롤은 화면에 나타나지도 않는다
        vm.tempTitle = "저녁 (수정)"

        var succeeded = false
        vm.saveSpending(eventBus: AppEventBus()) { success in succeeded = success }
        XCTAssertTrue(succeeded)

        let saved = sut.fetchSpendingRecords(date: day(0)).first { $0.id == record.id }
        XCTAssertEqual(saved?.participants, 3, "보이지도 않던 인원 컨트롤이 저장 때 1로 되돌리면 안 된다")
        XCTAssertEqual(saved?.paidByMe, false, "보이지도 않던 결제자 컨트롤이 저장 때 true로 되돌리면 안 된다")
    }

    // MARK: - Fix 3: 지갑이 연결된 기록에서 "여행 아님"을 눌러도 지갑은 안 풀린다

    func test_지갑_연결된_기록에서_여행_아님을_눌러도_지갑은_유지된다() {
        let walletId = seedWallet(100_000, title: "지갑")
        let record = SpendingRecordModel(title: "커피", amount: 5_000, date: day(0),
                                         tripId: nil, participants: 1, paidByMe: true)
        XCTAssertTrue(sut.createSpendingRecord(record))
        XCTAssertTrue(sut.linkSpendingToWish(recordId: record.id, wishItemId: walletId))

        let saved = sut.fetchSpendingRecords(date: day(0)).first { $0.id == record.id }!
        XCTAssertEqual(saved.wishItemId, walletId)

        let vm = SpendViewModel(manager: sut)
        vm.beginEdit(saved)
        XCTAssertEqual(vm.tempWishItemId, walletId)

        vm.selectTrip(nil)   // 이미 "여행 아님"인 상태에서 그 행을 다시 누르는 시나리오
        XCTAssertEqual(vm.tempWishItemId, walletId,
                       "저장돼 있던 지갑 연결이 '여행 아님'을 눌렀다고 풀리면 안 된다")
    }

    // MARK: - Fix 5: 모르는 여행 id는 선택되지 않는다

    func test_존재하지_않는_여행_id는_선택되지_않는다() {
        let vm = SpendViewModel(manager: sut)
        vm.loadActiveTrips()
        XCTAssertNil(vm.tempTripId)

        vm.selectTrip(UUID())
        XCTAssertNil(vm.tempTripId, "activeTrips에 없는 id는 커밋되면 안 된다")
    }
}
