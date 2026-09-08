//
//  TripSettlementTests.swift
//  GagaeSsi
//
//  여행 소비의 내 몫·예산 반영액·정산액은 저장하지 않고 계산한다.
//  여행이 아닌 소비는 셋 다 금액과 같아야 기존 동작이 바뀌지 않는다.
//

import XCTest
@testable import GagaeSsi

final class TripSettlementTests: XCTestCase {

    private func record(_ amount: Int, participants: Int = 1, paidByMe: Bool = true,
                        wishItemId: UUID? = nil) -> SpendingRecordModel {
        SpendingRecordModel(title: "지출", amount: amount, date: Date(),
                            wishItemId: wishItemId, tripId: UUID(),
                            participants: participants, paidByMe: paidByMe)
    }

    // MARK: - 파생값

    func test_여행이_아닌_소비는_내몫_예산반영_모두_금액과_같고_정산액은_0이다() {
        let r = SpendingRecordModel(title: "커피", amount: 4_500, date: Date())
        XCTAssertFalse(r.isShared)
        XCTAssertEqual(r.myShare, 4_500)
        XCTAssertEqual(r.budgetAmount, 4_500)
        XCTAssertEqual(r.receivable, 0)
    }

    func test_내가_낸_공용_소비는_전액이_예산에서_빠지고_남의_몫이_정산액이다() {
        let r = record(90_000, participants: 3, paidByMe: true)
        XCTAssertEqual(r.myShare, 30_000)
        XCTAssertEqual(r.budgetAmount, 90_000)
        XCTAssertEqual(r.receivable, 60_000)
    }

    func test_친구가_낸_공용_소비는_내_몫만_예산에서_빠지고_정산액은_0이다() {
        let r = record(300_000, participants: 3, paidByMe: false)
        XCTAssertEqual(r.myShare, 100_000)
        XCTAssertEqual(r.budgetAmount, 100_000)
        XCTAssertEqual(r.receivable, 0)
    }

    func test_나눗셈은_내림이고_나머지는_남의_몫에_붙는다() {
        let r = record(100_000, participants: 3, paidByMe: true)
        XCTAssertEqual(r.myShare, 33_333)
        XCTAssertEqual(r.receivable, 66_667)
    }

    func test_인원을_1로_내리면_공용이_아니다() {
        let r = record(50_000, participants: 1, paidByMe: false)
        XCTAssertFalse(r.isShared)
        XCTAssertEqual(r.myShare, 50_000)
        XCTAssertEqual(r.receivable, 0)
    }

    func test_인원_0은_1로_보정된다() {
        let r = SpendingRecordModel(title: "지출", amount: 10_000, date: Date(), participants: 0)
        XCTAssertEqual(r.participants, 1)
        XCTAssertEqual(r.myShare, 10_000)
    }
}
