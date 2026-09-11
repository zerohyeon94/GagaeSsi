//
//  SpendingEditDraftTests.swift
//  GagaeSsi
//
//  내역 편집 시트의 폼→기록 규칙(SpendingEditDraft)을 CoreData 없이 순수하게 검증한다.
//  "폼은 화면에 실제로 보여준 값만 덮어쓴다" 규칙이 Task 7과 같은 방식으로 깨지지 않는지가 핵심.
//

import XCTest
@testable import GagaeSsi

final class SpendingEditDraftTests: XCTestCase {

    // MARK: - Task 7 회귀: 여행이 지워진 분담 기록을 편집해도 인원·결제자는 유지된다

    func test_여행_삭제된_분담_기록을_편집해도_인원과_결제자는_유지된다() {
        // deleteTrip은 trip 연결만 끊고 participants/paidByMe는 그대로 둔다 — 그 상태를 재현
        let record = SpendingRecordModel(title: "저녁", amount: 90_000, date: Date(),
                                         tripId: nil, participants: 3, paidByMe: false)

        // loadRecord()가 record.tripId/participants/paidByMe를 그대로 실어오고,
        // 화면에서 실제로 바꾸는 건 제목뿐인 상황을 재현한다
        let draft = SpendingEditDraft(title: "저녁 (수정)", amount: record.amount, category: record.category,
                                      date: record.date, tripId: record.tripId,
                                      participants: record.participants, paidByMe: record.paidByMe,
                                      hasPayback: record.expectedPayback > 0, payback: record.expectedPayback)

        let result = draft.applied(to: record)
        XCTAssertEqual(result.participants, 3, "보이지도 않던 인원 컨트롤이 저장 때 1로 되돌리면 안 된다")
        XCTAssertEqual(result.paidByMe, false, "보이지도 않던 결제자 컨트롤이 저장 때 true로 되돌리면 안 된다")

        // 버그 버전(tripId == nil ? 1 : participants)이었다면 participants가 1로 무너져
        // budgetAmount가 amount 전체(90_000)가 됐을 것 — 항목별 버림 나머지까지 정확히 확인한다
        XCTAssertEqual(result.budgetAmount, record.amount / 3,
                       "인원이 조용히 1로 되돌아갔다면 budgetAmount가 amount 전체가 됐을 것이다")
        XCTAssertNotEqual(result.budgetAmount, record.amount)
    }

    // MARK: - 폼이 다루지 않는 필드는 원본 그대로

    func test_지갑연결과_환급수령여부와_id는_편집해도_그대로다() {
        let wishId = UUID()
        let recordId = UUID()
        let record = SpendingRecordModel(id: recordId, title: "커피", amount: 5_000, date: Date(),
                                         expectedPayback: 1_000, paybackReceived: true, wishItemId: wishId)

        let draft = SpendingEditDraft(title: "커피 (수정)", amount: 6_000, category: record.category,
                                      date: record.date, tripId: nil, participants: 1, paidByMe: true,
                                      hasPayback: false, payback: 0)
        let result = draft.applied(to: record)

        XCTAssertEqual(result.id, recordId)
        XCTAssertEqual(result.wishItemId, wishId, "폼이 다루지 않는 지갑 연결이 저장 때 풀리면 안 된다")
        XCTAssertTrue(result.paybackReceived, "폼이 다루지 않는 환급 수령 여부가 저장 때 되돌아가면 안 된다")
    }

    // MARK: - date-only 피커는 원래 기록의 시각을 보존한다

    func test_날짜만_바꿔도_원래_기록의_시각은_유지된다() {
        var originalComps = DateComponents()
        originalComps.year = 2026; originalComps.month = 9; originalComps.day = 1
        originalComps.hour = 14; originalComps.minute = 37; originalComps.second = 21
        let original = Calendar.current.date(from: originalComps)!
        let record = SpendingRecordModel(title: "점심", amount: 10_000, date: original)

        var newDayComps = DateComponents()
        newDayComps.year = 2026; newDayComps.month = 9; newDayComps.day = 5
        let newDay = Calendar.current.date(from: newDayComps)!

        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                      date: newDay, tripId: nil, participants: 1, paidByMe: true,
                                      hasPayback: false, payback: 0)
        let result = draft.applied(to: record)

        let resultComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                           from: result.date)
        XCTAssertEqual(resultComps.year, 2026)
        XCTAssertEqual(resultComps.month, 9)
        XCTAssertEqual(resultComps.day, 5, "날짜(연월일)는 피커가 고른 새 날짜여야 한다")
        XCTAssertEqual(resultComps.hour, 14, "시각은 원래 기록의 것이 유지돼야 한다")
        XCTAssertEqual(resultComps.minute, 37)
        XCTAssertEqual(resultComps.second, 21)
    }

    // MARK: - 환급 예정: 공용 전환 시 지우되, 이미 받은 환급은 지우지 않는다

    func test_공용으로_바꾸면_환급예정은_지워진다() {
        let record = SpendingRecordModel(title: "저녁", amount: 90_000, date: Date(),
                                         expectedPayback: 20_000, paybackReceived: false)
        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                      date: record.date, tripId: nil, participants: 3, paidByMe: true,
                                      hasPayback: true, payback: 20_000)
        XCTAssertEqual(draft.applied(to: record).expectedPayback, 0)
    }

    func test_이미_받은_환급은_공용으로_바꿔도_지워지지_않는다() {
        // receivePayback은 이미 CarryOverSource 크레딧을 올려놨다 — 여기서 0으로 지우면
        // 그 크레딧을 설명할 근거가 사라져 장부가 조용히 어긋난다
        let record = SpendingRecordModel(title: "저녁", amount: 90_000, date: Date(),
                                         expectedPayback: 20_000, paybackReceived: true)
        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                      date: record.date, tripId: nil, participants: 3, paidByMe: true,
                                      hasPayback: true, payback: 20_000)
        XCTAssertEqual(draft.applied(to: record).expectedPayback, 20_000,
                       "이미 받은 환급 크레딧의 근거인 expectedPayback을 조용히 지우면 안 된다")
    }

    func test_공용이_아니면_환급토글을_따른다() {
        let record = SpendingRecordModel(title: "커피", amount: 5_000, date: Date())
        let draftOn = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                        date: record.date, tripId: nil, participants: 1, paidByMe: true,
                                        hasPayback: true, payback: 1_000)
        XCTAssertEqual(draftOn.applied(to: record).expectedPayback, 1_000)

        let draftOff = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                         date: record.date, tripId: nil, participants: 1, paidByMe: true,
                                         hasPayback: false, payback: 1_000)
        XCTAssertEqual(draftOff.applied(to: record).expectedPayback, 0)
    }

    // MARK: - 인원 0은 1로 보정된다

    func test_인원_0은_1로_보정된다() {
        let record = SpendingRecordModel(title: "커피", amount: 5_000, date: Date())
        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                      date: record.date, tripId: nil, participants: 0, paidByMe: true,
                                      hasPayback: false, payback: 0)
        XCTAssertEqual(draft.applied(to: record).participants, 1)
    }

    // MARK: - 항목명 빈칸은 카테고리명으로 대체된다 (기존 동작)

    func test_항목명이_비어있으면_카테고리명을_쓴다() {
        let record = SpendingRecordModel(title: "저녁", amount: 5_000, date: Date(), category: .food)
        let draft = SpendingEditDraft(title: "", amount: record.amount, category: .food,
                                      date: record.date, tripId: nil, participants: 1, paidByMe: true,
                                      hasPayback: false, payback: 0)
        XCTAssertEqual(draft.applied(to: record).title, SpendingCategory.food.rawValue)
    }

    // MARK: - Fix 3 (리뷰): 화면이 보여준 값은 반드시 써야 한다 — 네 필드 모두 개별 확인
    //
    // 기존 테스트는 전부 tripId: nil, paidByMe/amount/category가 record와 같은 드래프트만
    // 만들었다. `result.<x> = record.<x>`(원본 값 그대로 되돌리는 뮤턴트)를 넣어도 그 값이
    // 안 바뀐 테스트는 통과한다 — 네 필드 모두 record와 다른 값을 하나씩 확인한다.

    func test_금액이_바뀌면_저장된다() {
        let record = SpendingRecordModel(title: "커피", amount: 5_000, date: Date())
        let draft = SpendingEditDraft(title: record.title, amount: 9_999, category: record.category,
                                      date: record.date, tripId: nil, participants: 1, paidByMe: true,
                                      hasPayback: false, payback: 0)
        XCTAssertEqual(draft.applied(to: record).amount, 9_999, "화면에 보여준 금액이 저장 때 원본으로 되돌아가면 안 된다")
    }

    func test_카테고리가_바뀌면_저장된다() {
        let record = SpendingRecordModel(title: "커피", amount: 5_000, date: Date(), category: .food)
        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: .transport,
                                      date: record.date, tripId: nil, participants: 1, paidByMe: true,
                                      hasPayback: false, payback: 0)
        XCTAssertEqual(draft.applied(to: record).category, .transport, "화면에 보여준 카테고리가 저장 때 원본으로 되돌아가면 안 된다")
    }

    func test_여행을_다른_여행으로_바꾸면_저장된다() {
        let tripA = UUID()
        let tripB = UUID()
        let record = SpendingRecordModel(title: "숙소", amount: 100_000, date: Date(), tripId: tripA)
        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                      date: record.date, tripId: tripB, participants: 1, paidByMe: true,
                                      hasPayback: false, payback: 0)
        XCTAssertEqual(draft.applied(to: record).tripId, tripB,
                       "내역 편집 시트의 핵심 기능(여행 재배정)이 저장 때 원본 여행으로 되돌아가면 안 된다")
    }

    func test_결제자가_바뀌면_저장된다() {
        let record = SpendingRecordModel(title: "저녁", amount: 30_000, date: Date(),
                                         participants: 3, paidByMe: false)
        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                      date: record.date, tripId: nil, participants: 3, paidByMe: true,
                                      hasPayback: false, payback: 0)
        XCTAssertEqual(draft.applied(to: record).paidByMe, true, "화면에 보여준 결제자가 저장 때 원본으로 되돌아가면 안 된다")
    }

    /// Fix 1: 이미 받은 환급은 폼이 무엇을 싣고 있든(토글·금액이 원본과 달라도) 건드리지 않는다.
    /// 두 화면 모두 이 경우 토글·금액 필드를 잠그지만, 그 잠금을 화면이 아니라 규칙 자체가
    /// 지켜야 한다 — 잠금을 우회하는 경로가 생겨도 장부가 어긋나지 않도록.
    func test_이미_받은_환급은_폼이_다른_값을_실어도_바뀌지_않는다() {
        let record = SpendingRecordModel(title: "저녁", amount: 90_000, date: Date(),
                                         expectedPayback: 20_000, paybackReceived: true)
        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                      date: record.date, tripId: nil, participants: 1, paidByMe: true,
                                      hasPayback: false, payback: 999_999)
        let result = draft.applied(to: record)
        XCTAssertEqual(result.expectedPayback, 20_000,
                       "이미 받은 환급의 근거 금액은 폼이 무엇을 싣고 있든 그대로 유지돼야 한다")
        XCTAssertTrue(result.paybackReceived)
    }

    // MARK: - Fix 4: 여행이 바뀌면 예전 여행에 물려있던 지갑 연결을 놓아준다

    func test_지갑을_놓아주면_wishItemId가_비워진다() {
        let wishId = UUID()
        let record = SpendingRecordModel(title: "숙소", amount: 100_000, date: Date(), wishItemId: wishId)
        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                      date: record.date, tripId: nil, participants: 1, paidByMe: true,
                                      hasPayback: false, payback: 0, clearsWallet: true)
        XCTAssertNil(draft.applied(to: record).wishItemId)
    }

    func test_clearsWallet가_false면_지갑연결은_그대로다() {
        let wishId = UUID()
        let record = SpendingRecordModel(title: "숙소", amount: 100_000, date: Date(), wishItemId: wishId)
        let draft = SpendingEditDraft(title: record.title, amount: record.amount, category: record.category,
                                      date: record.date, tripId: nil, participants: 1, paidByMe: true,
                                      hasPayback: false, payback: 0, clearsWallet: false)
        XCTAssertEqual(draft.applied(to: record).wishItemId, wishId)
    }
}
