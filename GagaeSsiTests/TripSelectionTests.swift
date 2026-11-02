//
//  TripSelectionTests.swift
//  GagaeSsi
//
//  소비 입력에서 고를 수 있는 여행은 '오늘'이 아니라 '소비 날짜'로 거른다 (#30).
//  기간이 끝난 미정산 여행이 평소 소비 입력에 계속 뜨면 안 되지만, 그 여행 기간의
//  소비를 며칠 뒤에 입력할 때는 떠야 한다.
//

import XCTest
@testable import GagaeSsi

final class TripSelectionTests: XCTestCase {
    var sut: CoreDataManager!
    private let cal = Calendar.current

    override func setUpWithError() throws {
        sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        _ = sut.createBudgetConfig(from: BudgetConfigModel(
            salary: 3_000_000, payday: safePayday, fixedCosts: [],
            carryOverMode: .full, debtPlanEnabled: true))
        makeDay(0)
    }
    override func tearDownWithError() throws { sut = nil }

    // MARK: - Helpers (SpendViewModelTests와 같은 패턴)

    func day(_ offset: Int) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: Date())!)
    }
    private var safePayday: Int {
        ((cal.component(.day, from: Date()) + 13 - 1) % 28) + 1
    }
    func makeDay(_ offset: Int) {
        guard sut.fetchDailyBudgetModel(date: day(offset)) == nil else { return }
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 100_000, date: day(offset),
                                                   carryOverSources: [], spendingRecords: []))
    }
    @discardableResult
    func makeTrip(_ title: String = "여행", from: Int, to: Int, participants: Int = 4) -> TripModel {
        let trip = TripModel(title: title, startDate: day(from), endDate: day(to),
                             defaultParticipants: participants)
        XCTAssertTrue(sut.createTrip(trip))
        return trip
    }

    // MARK: - 목록 규칙 (순수)

    func test_소비_날짜가_기간_안인_미정산_여행만_고를_수_있다() {
        let ended = TripModel(title: "지난 여행", startDate: day(-10), endDate: day(-7))
        let ongoing = TripModel(title: "지금 여행", startDate: day(-1), endDate: day(1))
        let trips = [ended, ongoing]

        XCTAssertEqual(TripModel.selectable(from: trips, on: day(0), keeping: nil).map(\.id), [ongoing.id])
        XCTAssertEqual(TripModel.selectable(from: trips, on: day(-8), keeping: nil).map(\.id), [ended.id],
                       "여행 다녀와서 며칠 뒤 그 기간 소비를 입력할 때는 지난 여행도 떠야 한다")
        XCTAssertTrue(TripModel.selectable(from: trips, on: day(-20), keeping: nil).isEmpty)
    }

    func test_정산_완료_여행은_기간_안이어도_고를_수_없다() {
        let settled = TripModel(title: "정산 끝", startDate: day(-1), endDate: day(1), status: .settled)
        XCTAssertTrue(TripModel.selectable(from: [settled], on: day(0), keeping: nil).isEmpty)
    }

    func test_편집_중인_기록에_묶인_여행은_기간이나_정산과_무관하게_남는다() {
        let ended = TripModel(title: "지난 여행", startDate: day(-10), endDate: day(-7))
        let settled = TripModel(title: "정산 끝", startDate: day(-30), endDate: day(-28), status: .settled)

        XCTAssertEqual(TripModel.selectable(from: [ended, settled], on: day(0), keeping: ended.id).map(\.id),
                       [ended.id])
        XCTAssertEqual(TripModel.selectable(from: [ended, settled], on: day(0), keeping: settled.id).map(\.id),
                       [settled.id])
    }

    func test_기간이_끝난_미정산_여행은_정산_대기다() {
        let ended = TripModel(title: "지난 여행", startDate: day(-10), endDate: day(-1))
        let lastDay = TripModel(title: "오늘 끝", startDate: day(-2), endDate: day(0))
        let settled = TripModel(title: "정산 끝", startDate: day(-10), endDate: day(-1), status: .settled)

        XCTAssertTrue(ended.isAwaitingSettlement(asOf: day(0)))
        XCTAssertFalse(lastDay.isAwaitingSettlement(asOf: day(0)), "마지막 날까지는 기간 중이다")
        XCTAssertFalse(settled.isAwaitingSettlement(asOf: day(0)))
    }

    // MARK: - 소비 입력 화면

    func test_기간이_지난_여행은_오늘_소비의_여행_목록에_안_나온다() {
        makeTrip("지난 여행", from: -10, to: -7)

        let vm = SpendViewModel(manager: sut)
        vm.loadActiveTrips()
        XCTAssertTrue(vm.activeTrips.isEmpty, "목록이 비면 SpendView는 여행 항목 자체를 그리지 않는다")
        XCTAssertNil(vm.tempTripId)
    }

    func test_소비_날짜를_여행_기간으로_옮기면_그_여행이_나온다() {
        let trip = makeTrip("지난 여행", from: -10, to: -7)

        let vm = SpendViewModel(manager: sut)
        vm.loadActiveTrips()
        vm.tempDate = day(-8)
        vm.loadActiveTrips()   // SpendView의 onChange(of: tempDate)가 하는 일

        XCTAssertEqual(vm.activeTrips.map(\.id), [trip.id])
        XCTAssertEqual(vm.tempTripId, trip.id, "기간 안 날짜면 그 여행 하나를 미리 고른다")
    }

    func test_날짜를_기간_밖으로_옮기면_고른_여행이_풀린다() {
        let trip = makeTrip("지금 여행", from: -1, to: 1)

        let vm = SpendViewModel(manager: sut)
        vm.loadActiveTrips()
        XCTAssertEqual(vm.tempTripId, trip.id)

        vm.tempDate = day(-5)
        vm.loadActiveTrips()
        XCTAssertNil(vm.tempTripId, "화면에 없는 여행에 묶인 채 저장되면 안 된다")

        vm.tempDate = day(0)
        vm.loadActiveTrips()
        XCTAssertEqual(vm.tempTripId, trip.id, "사용자가 '여행 아님'을 고른 게 아니므로 다시 기간 안이면 다시 고른다")
    }

    func test_편집_중인_기록에_묶인_여행은_기간이_지나도_계속_보인다() {
        let trip = makeTrip("지난 여행", from: -10, to: -7)
        makeDay(-8)
        let record = SpendingRecordModel(title: "숙소", amount: 40_000, date: day(-8),
                                         tripId: trip.id, participants: 4, paidByMe: true)
        XCTAssertTrue(sut.createSpendingRecord(record))

        let vm = SpendViewModel(manager: sut)
        vm.beginEdit(record)
        vm.tempDate = day(0)   // 기간 밖으로 날짜를 옮겨도
        vm.loadActiveTrips()

        XCTAssertEqual(vm.activeTrips.map(\.id), [trip.id])
        XCTAssertEqual(vm.tempTripId, trip.id, "원래 묶인 여행은 날짜를 옮겼다고 조용히 풀지 않는다")
    }
}

// MARK: - '여행 아님'으로 되돌릴 때 분담값 (#31)

extension TripSelectionTests {
    func test_새_소비에서_여행을_골랐다_풀면_개인_소비로_돌아간다() {
        let trip = makeTrip("지금 여행", from: -1, to: 1, participants: 4)
        let vm = SpendViewModel(manager: sut)
        vm.loadActiveTrips()
        vm.selectTrip(trip.id)
        XCTAssertEqual(vm.tempParticipants, 4)

        vm.selectTrip(nil)
        XCTAssertEqual(vm.tempParticipants, 1, "그대로 저장하면 평소 소비의 내 몫이 1/4로 잡힌다")
        XCTAssertTrue(vm.tempPaidByMe)
    }

    func test_인원을_직접_바꾼_뒤_여행을_풀면_그_값을_유지한다() {
        let trip = makeTrip("지금 여행", from: -1, to: 1, participants: 4)
        let vm = SpendViewModel(manager: sut)
        vm.loadActiveTrips()
        vm.selectTrip(trip.id)
        vm.tempParticipants = 3   // 사용자가 직접 넣은 값

        vm.selectTrip(nil)
        XCTAssertEqual(vm.tempParticipants, 3)
    }

    func test_결제자를_직접_바꾼_뒤_여행을_풀면_그_값을_유지한다() {
        let trip = makeTrip("지금 여행", from: -1, to: 1, participants: 4)
        let vm = SpendViewModel(manager: sut)
        vm.loadActiveTrips()
        vm.selectTrip(trip.id)
        vm.tempPaidByMe = false

        vm.selectTrip(nil)
        XCTAssertEqual(vm.tempParticipants, 4)
        XCTAssertFalse(vm.tempPaidByMe)
    }

    func test_날짜를_옮겨_여행이_풀려도_자동으로_채운_인원은_돌아간다() {
        _ = makeTrip("지금 여행", from: -1, to: 1, participants: 4)
        let vm = SpendViewModel(manager: sut)
        vm.loadActiveTrips()
        XCTAssertEqual(vm.tempParticipants, 4, "기간 안이라 자동 선택되며 인원이 채워진다")

        vm.tempDate = day(-5)
        vm.loadActiveTrips()
        XCTAssertNil(vm.tempTripId)
        XCTAssertEqual(vm.tempParticipants, 1)
    }

    func test_여행이_삭제된_분담_기록을_편집하다_여행_아님을_눌러도_분담은_유지된다() {
        let record = SpendingRecordModel(title: "저녁", amount: 80_000, date: day(0),
                                         tripId: nil, participants: 4, paidByMe: true)
        XCTAssertTrue(sut.createSpendingRecord(record))

        let vm = SpendViewModel(manager: sut)
        vm.beginEdit(record)
        vm.selectTrip(nil)
        XCTAssertEqual(vm.tempParticipants, 4)
    }

    func test_여행에_묶인_기록을_편집하다_여행_아님을_눌러도_불러온_분담은_유지된다() {
        let trip = makeTrip("지금 여행", from: -1, to: 1, participants: 4)
        let record = SpendingRecordModel(title: "숙소", amount: 80_000, date: day(0),
                                         tripId: trip.id, participants: 4, paidByMe: true)
        XCTAssertTrue(sut.createSpendingRecord(record))

        let vm = SpendViewModel(manager: sut)
        vm.beginEdit(record)
        vm.selectTrip(nil)
        XCTAssertNil(vm.tempTripId)
        XCTAssertEqual(vm.tempParticipants, 4, "기록에서 불러온 값은 사용자 소유 — 분담 블록이 그대로 보여준다")
    }

    func test_자동_채움_값_판정() {
        let fill = TripShareAutofill(participants: 4, paidByMe: true)
        XCTAssertTrue(fill.released(participants: 4, paidByMe: true) == (1, true))
        XCTAssertTrue(fill.released(participants: 3, paidByMe: true) == (3, true))
        XCTAssertTrue(fill.released(participants: 4, paidByMe: false) == (4, false))
    }
}

// MARK: - 소비 입력은 고르기만, 여행은 여행 화면에서 (#32)

extension TripSelectionTests {
    func test_이_소비의_인원이_여행_기본과_다를_때만_안내한다() {
        let trip = TripModel(title: "제주", startDate: day(0), endDate: day(2), defaultParticipants: 4)
        XCTAssertNil(trip.shareOverrideNote(participants: 4))
        XCTAssertEqual(trip.shareOverrideNote(participants: 3), "이 소비만 3명이에요 · 여행 기본 인원은 4명")
        XCTAssertEqual(trip.shareOverrideNote(participants: 1), "이 소비는 나 혼자 쓴 거예요 · 여행 기본 인원은 4명")
    }

    func test_기간을_줄이면_밖으로_밀려난_소비를_세지만_연결은_유지한다() {
        let trip = makeTrip("제주", from: -4, to: 0)
        for offset in [-4, -1] {
            makeDay(offset)
            XCTAssertTrue(sut.createSpendingRecord(SpendingRecordModel(
                title: "소비", amount: 10_000, date: day(offset), tripId: trip.id, participants: 4, paidByMe: true)))
        }

        XCTAssertTrue(sut.updateTrip(id: trip.id, title: trip.title, startDate: day(-2), endDate: day(0),
                                     defaultParticipants: 4, wishItemId: nil))
        let shrunk = sut.fetchTrip(id: trip.id)!
        let records = sut.fetchSpendingRecords(tripId: trip.id)

        XCTAssertEqual(records.count, 2, "기간을 줄였다고 연결을 자동으로 풀면 정산 금액이 조용히 바뀐다")
        XCTAssertEqual(shrunk.outsidePeriodCount(of: records.map(\.date)), 1)
    }
}
