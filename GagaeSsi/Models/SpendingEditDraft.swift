//
//  SpendingEditDraft.swift
//  GagaeSsi
//
//  소비를 고치는 두 화면 — 소비 입력 탭(SpendView/SpendViewModel)의 편집 모드와 내역 편집
//  시트(HistorySpendEditView) — 가 폼 값을 SpendingRecordModel에 얹는 규칙. Task 8 코드
//  리뷰에서 두 화면이 이 규칙을 각자 구현하다 어긋난 것(환급 잠금·지갑 정리·저장 검증)이
//  드러나 한 곳으로 모았다. 이제 두 화면 모두 이 타입을 거쳐야만 저장한다.
//
//  **폼은 보여준 값은 반드시 쓰고, 보여주지 않은 값은 절대 건드리지 않는다.**
//  "숨겨진 필드가 저장 때 조용히 바뀌면 안 된다"는 규칙만으로는 한쪽만 지켜진다 — 화면에
//  버젓이 보이는 값이 저장 때 버려지는 버그(Task 8 리뷰에서 실제로 발견된 환급 필드)는
//  못 잡는다. 두 방향 모두 이 타입 하나로 지킨다.
//

import Foundation

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
    /// 여행이 바뀌어(다른 여행으로, 또는 "여행 아님"으로) 예전 여행에 물려있던 지갑 연결을
    /// 놓아줘야 하면 true.
    ///
    /// `applied(to:)`는 반환 모델의 `wishItemId`를 nil로 비워 미리보기·테스트가 일관되게
    /// 하지만, 그것만으로 CoreData 연결이 끊기지는 않는다 — `CoreDataManager.updateSpendingRecord`는
    /// `model.wishItemId`를 읽지 않는다(지갑 연결은 `linkSpendingToWish`/`unlinkSpendingFromWish`로
    /// 따로 관리된다). 그래서 이 플래그가 true면 호출부가 저장 뒤 `unlinkSpendingFromWish`를
    /// 직접 불러야 한다 — `Bool` 하나로 끝내는 대신 이렇게 나눈 이유는, 어느 지갑으로
    /// "옮길지"가 아니라 "이 지갑과의 연결을 놓아줄지"만 결정하면 되기 때문이다(옮겨 붙이는
    /// 동작은 이 폼에 지갑 피커가 없어 애초에 일어나지 않는다).
    var clearsWallet: Bool = false

    /// - Parameter record: 편집 대상 원본 기록. 폼이 다루지 않는 필드(환급 수령 여부, id,
    ///   `clearsWallet == false`일 때의 지갑 연결)는 여기서 그대로 가져온다.
    func applied(to record: SpendingRecordModel) -> SpendingRecordModel {
        var result = record

        // 항목명 — 비우면 카테고리명으로 대체 (기존 동작)
        result.title = title.isEmpty ? category.rawValue : title
        result.amount = amount
        result.category = category

        // date-only 피커라 시각 성분은 원래 기록의 것을 유지하려면 날짜만 교체
        let cal = Calendar.current
        let timeComps = cal.dateComponents([.hour, .minute, .second], from: record.date)
        result.date = cal.date(bySettingHour: timeComps.hour ?? 0, minute: timeComps.minute ?? 0,
                               second: timeComps.second ?? 0, of: cal.startOfDay(for: date)) ?? date

        // 화면에 보여준 값을 그대로 쓴다 — tripId == nil이라고 1/true로 강제하지 않는다.
        // `SpendingRecordModel.init`과 같은 완전한 클램프(1...999)를 쓴다 — `max(1, ...)`만
        // 쓰면 위쪽 한계가 빠져 Int16 저장 한계를 벗어난 값이 그대로 흘러간다.
        result.tripId = tripId
        result.participants = min(999, max(1, participants))
        result.paidByMe = paidByMe

        // 공용 소비는 정산이 환급 역할을 하므로 환급 필드를 비운다 — 단, 이미 받은 환급은
        // 예외다. `receivePayback`이 이미 CarryOverSource 크레딧을 올려놨는데 여기서 지우면
        // 그 크레딧을 설명할 근거가 사라져 장부가 조용히 어긋난다. 이미 받은 환급은 두 화면
        // 모두 토글·금액 필드를 잠가 편집 자체를 막으므로, hasPayback/payback이 무엇이든
        // 원본을 그대로 지킨다.
        if record.paybackReceived {
            result.expectedPayback = record.expectedPayback
        } else {
            result.expectedPayback = (hasPayback && !result.isShared) ? payback : 0
        }

        if clearsWallet {
            result.wishItemId = nil
        }
        // id, paybackReceived는 폼이 다루지 않으므로 record 값 그대로 유지된다.
        // wishItemId도 clearsWallet이 아니면 그대로 유지된다.
        return result
    }
}
