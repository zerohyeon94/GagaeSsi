//
//  TripSettlementTests.swift
//  GagaeSsi
//
//  여행 소비의 내 몫·예산 반영액·정산액은 저장하지 않고 계산한다.
//  여행이 아닌 소비는 셋 다 금액과 같아야 기존 동작이 바뀌지 않는다.
//

import XCTest
import CoreData
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

    func test_인원은_저장_한계를_넘지_않게_잘린다() {
        let r = SpendingRecordModel(title: "지출", amount: 10_000, date: Date(), participants: 100_000)
        XCTAssertEqual(r.participants, 999)
    }

    // MARK: - 편집 회귀

    /// 폼이 다루지 않는 필드는 편집으로 덮이면 안 된다.
    /// (인원·결제자는 아직 UI가 없지만, 데이터 계층은 이미 두 컬럼을 쓴다)
    ///
    /// `SpendViewModel`은 `CoreDataManager.shared`를 직접 참조해서 in-memory
    /// 테스트 스토어로 갈아끼울 수 없다. 그래서 여기서는 `beginEdit` + `saveSpending`이
    /// 실제로 하는 일 — 편집 대상 기록으로 model을 시작하고, 폼이 다루는 필드(제목)만
    /// 바꾼 뒤 `updateSpendingRecord`를 호출하는 흐름 — 을 데이터 계층 한 단계 아래서
    /// 그대로 재현해 같은 불변조건을 검증한다.
    /// `beginEdit`이 실제로 `model = record`를 대입하는지는 코드 검토로 확인했다
    /// (SpendViewModel.swift의 beginEdit 첫 줄).
    func test_폼이_다루지_않는_필드는_수정으로_덮이지_않는다() {
        let sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        let day = Calendar.current.startOfDay(for: Date())
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 100_000, date: day,
                                                   carryOverSources: [], spendingRecords: []))
        let record = SpendingRecordModel(title: "저녁", amount: 90_000, date: day,
                                         participants: 3, paidByMe: false)
        XCTAssertTrue(sut.createSpendingRecord(record))

        // beginEdit: 편집 대상 기록을 그대로 싣고 시작
        var model = sut.fetchSpendingRecords(date: day)[0]
        // saveSpending: 폼이 다루는 필드만 갱신 (여기선 제목만 바꾼다)
        model.title = "저녁 회식"
        XCTAssertTrue(sut.updateSpendingRecord(model))

        let saved = sut.fetchSpendingRecords(date: day)[0]
        XCTAssertEqual(saved.title, "저녁 회식")
        XCTAssertEqual(saved.participants, 3, "인원이 기본값으로 덮이면 안 된다")
        XCTAssertFalse(saved.paidByMe, "결제자가 기본값으로 덮이면 안 된다")
    }

    // MARK: - 삭제 규칙

    /// Trip.spendingRecords는 deletionRule="Nullify"다. 여행을 지워도 소비 기록 자체는
    /// 남아야 한다 (Cascade로 바뀌면 실제 소비 내역이 통째로 사라진다).
    /// 아직 createTrip API가 없으므로(Task 5) 마이그레이션 테스트들과 같은 방식으로
    /// NSEntityDescription을 통해 직접 삽입한다.
    func test_여행을_지워도_소비_기록은_지워지지_않는다() {
        let sut = CoreDataManager(inMemory: true)
        sut.resetAllData()
        let day = Calendar.current.startOfDay(for: Date())
        _ = sut.createDailyBudget(DailyBudgetModel(availableAmount: 100_000, date: day,
                                                   carryOverSources: [], spendingRecords: []))
        let record = SpendingRecordModel(title: "숙소", amount: 120_000, date: day)
        XCTAssertTrue(sut.createSpendingRecord(record))

        let context = sut.context
        let trip = NSEntityDescription.insertNewObject(forEntityName: "Trip", into: context)
        trip.setValue(UUID(), forKey: "id")
        trip.setValue("제주", forKey: "title")
        trip.setValue(Date(), forKey: "startDate")
        trip.setValue(Date(), forKey: "endDate")
        trip.setValue(Int16(3), forKey: "defaultParticipants")
        trip.setValue("진행중", forKey: "status")
        trip.setValue(Date(), forKey: "createdAt")

        guard let entity = sut.fetchSpendingRecordEntity(id: record.id) else {
            XCTFail("방금 만든 소비 기록을 찾지 못함")
            return
        }
        entity.setValue(trip, forKey: "trip")
        XCTAssertTrue(sut.saveContext())

        context.delete(trip)
        XCTAssertTrue(sut.saveContext())

        let afterDelete = sut.fetchSpendingRecords(date: day)
        XCTAssertEqual(afterDelete.count, 1, "여행을 지워도 소비 기록은 남아야 한다")
        XCTAssertNil(afterDelete[0].tripId, "지워진 여행과의 연결은 nil이 되어야 한다")
    }

    // MARK: - 정산 집계

    /// 3명, 내가 점심 10만·저녁 20만·아침 15만을 다 냈다 → 인당 15만, 30만 돌려받는다
    func test_내가_다_낸_여행은_인당_금액과_받을_돈이_나온다() {
        let s = TripSettlementModel.compute(records: [
            record(100_000, participants: 3), record(200_000, participants: 3), record(150_000, participants: 3),
        ])
        XCTAssertEqual(s.totalPaid, 450_000)
        XCTAssertEqual(s.sharedTotal, 450_000)
        XCTAssertEqual(s.myShareTotal, 150_000)
        XCTAssertEqual(s.paidByMeTotal, 450_000)
        XCTAssertEqual(s.receivable, 300_000)
        XCTAssertEqual(s.perPerson, 150_000)
    }

    func test_친구가_낸_숙소는_내_몫만_집계되고_받을_돈은_없다() {
        let s = TripSettlementModel.compute(records: [record(300_000, participants: 3, paidByMe: false)])
        XCTAssertEqual(s.totalPaid, 300_000)
        XCTAssertEqual(s.myShareTotal, 100_000)
        XCTAssertEqual(s.paidByMeTotal, 0)
        XCTAssertEqual(s.receivable, 0)
    }

    func test_항목별_인원이_섞이면_항목별_몫의_합이고_인당_금액은_없다() {
        let s = TripSettlementModel.compute(records: [
            record(300_000, participants: 3, paidByMe: false),   // 숙소 3명 → 내 몫 10만
            record(80_000, participants: 2, paidByMe: true),     // 저녁 2명 → 내 몫 4만, 4만 돌아옴
            record(3_000, participants: 1),                      // 기념품 → 내 몫 3천
        ])
        XCTAssertEqual(s.myShareTotal, 143_000)
        XCTAssertEqual(s.sharedTotal, 380_000)
        XCTAssertEqual(s.receivable, 40_000)
        XCTAssertNil(s.perPerson)
    }

    func test_지갑에서_빠진_돈과_예산에서_빠진_돈이_갈린다() {
        let wallet = UUID()
        let s = TripSettlementModel.compute(records: [
            record(90_000, participants: 3, paidByMe: true, wishItemId: wallet),   // 지갑에서 9만
            record(60_000, participants: 3, paidByMe: false, wishItemId: wallet),  // 지갑에서 내 몫 2만
            record(30_000, participants: 3, paidByMe: true),                       // 예산에서 3만
        ])
        XCTAssertEqual(s.fromWallet, 110_000)
        XCTAssertEqual(s.fromBudget, 30_000)
    }

    func test_소비가_없으면_전부_0이다() {
        let s = TripSettlementModel.compute(records: [])
        XCTAssertEqual(s, TripSettlementModel(totalPaid: 0, sharedTotal: 0, myShareTotal: 0,
                                              paidByMeTotal: 0, receivable: 0,
                                              fromWallet: 0, fromBudget: 0, uniformParticipants: nil))
    }

    // MARK: - TripModel

    func test_여행_기간_포함_판정은_시작일과_종료일을_포함한다() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 2, to: start)!
        let trip = TripModel(title: "제주", startDate: start, endDate: end, defaultParticipants: 3)
        XCTAssertTrue(trip.contains(start))
        XCTAssertTrue(trip.contains(cal.date(byAdding: .hour, value: 30, to: start)!))
        XCTAssertTrue(trip.contains(end))
        XCTAssertFalse(trip.contains(cal.date(byAdding: .day, value: -1, to: start)!))
        XCTAssertFalse(trip.contains(cal.date(byAdding: .day, value: 3, to: start)!))
    }
}
