# 여행 — 같이 쓴 돈을 묶고, 내 몫만 예산에서 빼고, 나중에 정산하기

- **작성일**: 2026-09-08
- **상태**: 설계 (구현 전)
- **브랜치**: develop
- **관련 문서**: [위시 지갑](2026-08-28-wish-wallet-design.md), [페이백](2026-07-30-payback-design.md), [할부](2026-07-30-installment-design.md), [하루 사용 가능 금액 계산 규칙](../../2026-07-08-daily-budget-calculation-rules.md)
- **관련 코드**: `Core/CoreDataManager.swift`, `Models/BudgetModels.swift`, `Models/WishModels.swift`, `Features/Spend/`, `Features/History/`, `Features/Stats/`, `Features/Settings/`

---

## 1. 배경 / 문제

여행을 가면 돈이 두 가지 방식으로 움직인다.

- **친구가 결제**하고 나는 나중에 내 몫을 보낸다 (숙소 30만을 친구가 내고 내 몫은 10만)
- **내가 결제**하고 나중에 N빵으로 돌려받는다 (점심 10만·저녁 20만·아침 15만을 내가 내고, 정산 때 인당 15만으로 나눔)

지금 구조에서는 둘 다 어색하다. 친구가 낸 숙소는 기록할 방법이 없고, 내가 낸 45만은 전액 내 소비로 잡혀
그 이틀이 크게 초과한 날이 된다. 페이백 필드(`expectedPayback`)로 흉내 낼 수는 있지만
내 몫은 **정산 시점에야 알 수 있어서** 소비를 적을 때 환급 예정액을 넣을 수 없다.

또 여행 자금은 위시로 미리 모아두는 경우가 많다. 그 지갑에서 쓴 소비와 친구에게 받을 정산금이
서로 맞물려야 한다.

## 2. 컨셉

**정산 단위는 소비 건이 아니라 "여행"이다.** 소비를 적을 때는 누가 냈는지와 몇 명이 나누는지만 표시하고,
내 몫·예산 반영액·정산액은 여행이 계산한다.

원칙 두 줄:

- **예산은 실제로 내 돈이 나간 만큼.** 내가 낸 건 전액, 친구가 낸 건 내 몫만 — 소비한 날에.
- **통계는 내가 소비한 몫.** 8만을 결제했어도 내가 먹은 건 2만이다.

내가 대신 낸 남의 몫은 정산 때 돌아온다. 여행에 위시 지갑이 연결돼 있으면 지갑으로, 아니면 그날 예산으로.

## 3. 확정된 설계 결정

| 결정 | 선택 | 근거 |
|---|---|---|
| 구조 | `Trip` 엔티티 + `SpendingRecord`에 관계·필드 추가 | 소비는 소비로 남겨 내역·통계·CSV가 그대로 동작. 위시 지갑과 같은 패턴 |
| 친구가 낸 소비의 예산 반영 시점 | **소비한 날**, 내 몫만 | 송금일로 미루면 여행 중 화면이 실제 소비와 어긋난다 |
| 내가 낸 소비의 예산 반영 | **전액** 차감, 정산 때 남의 몫 회수 | 실제 잔고와 일치. 페이백과 같은 태도 |
| 내 몫 입력 | 입력하지 않는다 — `amount ÷ participants`로 계산 | 정산 전에는 알 수 없는 값이다 |
| 인원 | 여행 기본 인원 + **항목별 수정 가능** | "숙소는 3명, 저녁은 2명"이 실제로 생긴다. 멤버 이름·개인별 채권은 범위 밖 |
| 통계·내역 합계 | `myShare` 기준 | 내가 소비한 돈. 결제 대행분은 소비가 아니다 |
| 위시 지갑 | 여행에 지갑을 연결. 내가 내는 소비는 지갑에서 먼저, 정산 회수도 지갑으로 | 여행 자금을 위시로 모아 가는 사용 방식에 맞춘다 |
| 지갑 부분 커버 | 없음 — `budgetAmount ≤ 잔액`일 때만 연결 | 위시 지갑 설계의 "잔액 한도" 규칙 유지 |
| 정산 | 여행당 한 번. 실제 수령액 덮어쓰기 가능 | 페이백 확정액과 같은 태도 |
| 소비 날짜 | 여행 기간 밖이어도 묶을 수 있음 | 항공권은 두 달 전에 산다. 기간은 기본값·표시용 |
| 숙소를 여러 날에 나눠 잡기 | **v1 제외** | 전액 이월이라 마지막 날 잔액이 같다. 일별 화면이 거슬리면 그때 토글 추가 |

## 4. 데이터 모델 (CoreData `GagaeSsi 12`)

배포된 11은 in-place 수정하지 않는다 — **새 버전 `GagaeSsi 12`를 만든다.**

```
Trip (신규)
  id UUID · title String · startDate Date · endDate Date
  defaultParticipants Int16 · status String("진행중"/"정산완료")
  settledAt Date? · settledAmount Int32 · settlementEntryId UUID? · createdAt Date
  → wishItem       (optional, maxCount 1, Nullify)   연결된 지갑
  → spendingRecords (toMany, Nullify)

SpendingRecord (추가)
  participants Int16  (기본 1 — 공용 아님)
  paidByMe Boolean    (기본 true)
  → trip (optional, maxCount 1, Nullify)

WishSavingEntry (추가)
  source String?      (nil = 평소 저금, "tripSettlement" = 여행 정산 회수)
```

전부 optional이거나 기본값이 있어 lightweight migration으로 열린다. `resetAllData`에 `Trip` 추가.

**모델**

- `TripModel` — 엔티티 필드 + `init(entity:)`. `isSettled`, `contains(date:)`.
- `SpendingRecordModel` 추가: `tripId: UUID?`, `participants: Int`, `paidByMe: Bool` + 파생값(아래).
- `WishSavingEntryModel.source: WishSavingSource?`.

## 5. 계산 규칙

모두 `SpendingRecordModel`의 파생값이다. 저장하지 않는다.

```swift
/// 내가 소비한 몫. 공용이면 인원으로 나눈다 (원 단위 내림).
var myShare: Int       { participants > 1 ? amount / participants : amount }
/// 그날 예산(또는 지갑)에서 빠지는 돈. 내가 냈으면 전액, 남이 냈으면 내 몫.
var budgetAmount: Int  { paidByMe ? amount : myShare }
/// 정산 때 돌아오는 남의 몫. 남이 낸 소비는 0.
var receivable: Int    { paidByMe ? amount - myShare : 0 }
```

| 용도 | 값 |
|---|---|
| 하루 예산 차감 · 초과 판정 (`DailyBudgetModel.budgetedSpending`) | `budgetAmount` |
| 위시 지갑 잔액 (`wishSpentAmount`) | `budgetAmount` |
| 내역 일별·월 합계, 통계 월 합계·카테고리·일별·전월 비교, 카테고리 분석, CSV | `myShare` (CSV는 전액·내 몫 두 열) |
| 여행 정산 화면 | `amount` 전액 + 위 셋 |

여행이 아닌 소비는 `participants = 1, paidByMe = true`이므로 셋이 모두 `amount`와 같다 — **기존 동작 무변경.**

**정산 집계** — 순수 계산, `Models/TripModels.swift`:

```swift
struct TripSettlementModel {
    let totalPaid: Int      // 여행 소비 전액 합 (내가 낸 것 + 남이 낸 것)
    let sharedTotal: Int    // participants > 1 인 소비의 전액 합
    let myShareTotal: Int   // Σ myShare — 통계와 같은 값
    let paidByMeTotal: Int  // 내가 실제 낸 돈
    let receivable: Int     // Σ receivable — 정산 때 돌아올 남의 몫
    let fromWallet: Int     // 지갑에 연결된 소비의 budgetAmount 합
    let fromBudget: Int     // 나머지 budgetAmount 합
    static func compute(records: [SpendingRecordModel]) -> TripSettlementModel
}
```

사용자 예시(3명, 내가 10+20+15 = 45만 결제)로 검산: `sharedTotal 45만 · myShareTotal 15만 · paidByMeTotal 45만 · receivable 30만`.

**예산 흐름 요약**

| 상황 | 소비한 날 | 정산일 |
|---|---|---|
| 내가 낸 공용 소비 45만 (3명) | −45만 | +30만 (남의 몫) |
| 친구가 낸 숙소 30만 (3명) | −10만 (내 몫) | 변화 없음 — 송금은 이미 잡힌 10만을 실제로 내는 것 |
| 여행 중 내 개인 소비 3만 | −3만 | 변화 없음 |

정산까지 마치면 예산 누적 차감 = 실제로 내 통장에서 나간 돈. 정산 전에는 대신 낸 만큼 더 마이너스로 보이는데, 그게 실제 잔고다.

## 6. 예산 엔진 변경

바뀌는 곳은 한 줄이다. `DailyBudgetModel.budgetedSpending`이 예산 차감과 초과 판정(`OverspendAnalyzer`)의 단일 기준점이므로 여기만 바꾸면 이월 체인·부채 전환·급여일 흡수가 따라온다.

```swift
// 전
spendingRecords.filter { $0.wishItemId == nil }.map(\.amount).reduce(0, +)
// 후
spendingRecords.filter { $0.wishItemId == nil }.map(\.budgetAmount).reduce(0, +)
```

같은 이유로 `CoreDataManager.wishSpentAmount(for:)`·`wishSpendableLimit`·`linkSpendingToWish`의 잔액 비교도 `budgetAmount` 기준으로.

내역·통계의 `.amount` 합산(`HistoryViewModel.load`, `StatsViewModel` 월 합계·카테고리·일별·전월, `CategorySpendingAnalyzer`, `SpendingCSVExporter`)은 `.myShare`로 바꾼다. 기계적 치환이며 회귀 테스트로 기존 값 불변을 확인한다.

**재계산 트리거**: `participants`·`paidByMe` 변경은 `budgetAmount`를 바꾸므로 `updateSpendingRecord`가 이미 부르는 `recalculateCarryOverChain(from: date)`로 커버된다. `deleteTrip`은 연결됐던 소비 중 가장 이른 날짜부터 한 번 재계산한다 (위시 삭제와 동일). 여행 삭제는 소비의 `participants`·`paidByMe`를 건드리지 않으므로 사실상 예산은 불변이지만, 규칙의 일관성을 위해 부른다.

## 7. 데이터 계층 API (`CoreDataManager` 여행 섹션)

```swift
// 여행 CRUD
func fetchTrips() -> [TripModel]                 // 진행 중 먼저, 이어서 정산 완료 (각각 최근순)
func createTrip(_ model: TripModel) -> Bool
func updateTrip(_ model: TripModel) -> Bool
func deleteTrip(id: UUID) -> Bool                // 소비는 남기고 연결만 끊음(Nullify) + 재계산
func trip(containing date: Date) -> TripModel?   // 진행 중 여행 중 기간에 포함되는 것. 2개 이상이면 nil

// 소비 ↔ 여행
func fetchSpendingRecords(tripId: UUID) -> [SpendingRecordModel]
// createSpendingRecord / updateSpendingRecord: tripId·participants·paidByMe 저장

// 정산
func tripSettlement(for tripId: UUID) -> TripSettlementModel
@discardableResult
func settleTrip(id: UUID, actualAmount: Int) -> Bool
@discardableResult
func reopenTrip(id: UUID) -> Bool
```

**`settleTrip(id:actualAmount:)`**
1. `actualAmount`(기본값 `receivable`, 사용자가 덮어쓸 수 있음)를 크레딧으로 발행
   - 여행에 지갑 연결 + 그 위시가 아직 존재 → `WishSavingEntry(amount: actualAmount, date: 오늘, source: .tripSettlement)` — 지갑 잔액 회복
   - 아니면 → 오늘 `DailyBudget`에 `CarryOverSource(reason: .tripSettlement)` — 페이백 수령(`.refund`)과 같은 통로. `CarryOverReason`에 케이스 추가, `countsTowardAllowance`는 `.refund`와 동일하게
2. `status = 정산완료`, `settledAt = 오늘`, `settledAmount = actualAmount`
3. `actualAmount == 0`이면 크레딧 없이 상태만 전환
4. 이미 정산 완료면 `false`

**`reopenTrip(id:)`**
1. 정산 때 만든 엔트리를 `settlementEntryId`로 찾아 삭제 — 지갑이면 `WishSavingEntry`, 예산이면 `CarryOverSource`. (같은 날 두 여행을 정산해도 섞이지 않게 id로 찾는다)
2. 지갑 크레딧을 이미 다른 소비가 써서 `잔액 < settledAmount`면 **거부**(`false`) — 위시 지갑 "잔액 한도" 규칙과 같은 태도
3. 예산 크레딧이면 삭제 후 `settledAt`부터 이월 재계산
4. `status = 진행중`, `settledAt = nil`, `settledAmount = 0`

**지갑 자동 연결** (소비 저장 시, ViewModel 책임): 여행에 지갑이 있고 `budgetAmount ≤ wishSpendableLimit`이면 `tempWishItemId`를 그 위시로 미리 채운다. 사용자가 "예산에서 쓰기"로 바꾸면 그대로 둔다. 데이터 계층은 기존 `linkSpendingToWish`를 그대로 쓴다.

## 8. 화면

새 화면은 `Features/Trip/`에 View + ViewModel 쌍으로. 기존 패턴(설정 진입 → 목록 → 시트, 소비 입력 필드, 내역 배지)을 따른다.

**① 설정 › 🧳 여행** (`TripListView`) — 할부·페이백 옆에 진입점
- 섹션: **진행 중** / **정산 완료**
- 행: 제목 · 기간(9.12–9.14) · N명 · **내 몫 합계** · 지갑 연결 시 🎁. 정산 완료 행엔 "9.20 정산 · +300,000 돌아옴"
- 우상단 + → ②

**② 여행 추가/편집 시트** (`TripEditView`)
- 제목, 시작일·종료일, 인원(기본 2), **지갑 연결**(잔액 있는 위시 중 선택, 기본 "연결 안 함")
- 지갑을 고르면 "이 여행에서 내가 내는 소비는 제주 여행 지갑(남은 800,000원)에서 먼저 빠져요"

**③ 여행 상세** (`TripDetailView`)
- 요약 카드 4칸: **총 지출**(전액) / **내 몫** / **내가 낸 돈** / **받을 돈**(0이면 "받을 돈 없음"). 지갑 연결 시 아래에 "지갑에서 X · 예산에서 Y"
- 소비 목록: 날짜별 묶음. 행 = 항목 · 전액 · `3명` `친구가 냄` 칩 · 내 몫. 탭하면 기존 `HistorySpendEditView`로 — 새 편집 화면을 만들지 않는다
- 하단 **정산하기** → ④
- 정산 완료 상태: 요약 카드 대신 정산 결과("인당 150,000 · 받은 돈 300,000 · 지갑으로 돌아감") + "정산 다시 열기"(거부 시 "지갑에서 이미 쓴 돈이 있어 되돌릴 수 없어요")

**④ 정산 시트** (`TripSettleSheet`)
```
공용 지출     450,000
÷ 인원        3명  →  인당 150,000
내가 낸 돈    450,000
────────────────────
받을 돈       300,000   [금액 수정]
→ 🎁 제주 여행 지갑으로 돌아가요   (또는: 오늘 예산으로 들어와요)
```
금액을 고치면 "계산과 다른 금액이에요" 한 줄만 표시하고 막지 않는다. 항목별 인원이 섞여 있으면 "인당" 줄 대신 "내 몫 합계"로.

**⑤ 소비 입력** (`SpendView`) — 기존 필드 아래 **🧳 여행** 필드
- 진행 중 여행이 없으면 필드 자체가 안 보임 (위시 지갑 필드와 같은 규칙)
- 소비 날짜가 진행 중 여행 하나의 기간 안이면 **자동 선택**(끌 수 있음). 밖이거나 겹치는 여행이 둘이면 "여행 없음"이 기본
- 여행을 고르면 펼쳐짐: **인원** 스테퍼(기본 = 여행 인원, 1 = 내 개인 소비) · **누가 냈나** `내가`/`다른 사람이` 세그먼트 · 즉시 계산 한 줄("내 몫 20,000원 · 정산 때 60,000원 돌아와요" / "내 몫 100,000원만 오늘 예산에서 빠져요")
- 여행에 지갑이 있고 잔액이 `budgetAmount`를 덮으면 🎁 지갑 필드가 그 위시로 자동 선택. 부족하면 자동 선택 없이 기존 안내
- 인원 > 1이면 **환급 예정 필드 숨김** (정산과 겹치면 이중 반영)
- 편집 시트(`HistorySpendEditView`)도 같은 필드를 가진다. 정산 완료 여행의 소비는 여행·인원·결제자 필드가 잠긴다

**⑥ 내역** (`HistoryView`)
- 금액 자리에 **내 몫**, 아래 작게 "결제 80,000 · 3명 · 내가 냄" (`participants > 1`일 때만)
- 배지 `🧳 제주 여행` (탭하면 여행 상세). 🎁 배지와 나란히 올 수 있음
- 캘린더 일별 합계·월 합계는 내 몫 기준

**⑦ 위시 상세** — 저금 내역에서 `source == tripSettlement` 엔트리는 "🧳 여행 정산으로 돌아옴"으로 구분

**v1 제외**: 홈 화면 "여행 중" 배너, 여행 통계(카테고리 분포 등), 여행별 예산 목표, 멤버 이름·개인별 정산.

## 9. 엣지 케이스

| 케이스 | 처리 |
|---|---|
| 기간이 겹치는 진행 중 여행 2개 | 자동 선택 안 함, 목록에서 고르게 |
| 연결된 위시를 여행보다 먼저 삭제 | `trip.wishItem` Nullify → 이후 소비·정산은 예산으로 |
| 위시 지갑에서 쓴 소비인데 인원 > 1이고 친구가 냄 | 지갑에서 내 몫만 빠짐 (`budgetAmount`) |
| 정산 완료 여행에 소비를 넣으려 함 | 소비 입력 목록에 정산 완료 여행은 안 보임. 편집 시 관련 필드 잠김 |
| `receivable = 0`으로 정산 | 크레딧 없이 상태만 전환 |
| 정산 후 연결 소비를 삭제·수정 | 정산은 그대로 (페이백 삭제 규칙과 동일 — 이미 준 크레딧 회수 안 함). 다시 열기로 재정산 |
| 공용 소비에 환급 예정(`expectedPayback`)이 함께 있음 | 생기지 않게 막는다 — 인원 > 1이면 입력 화면에서 환급 필드를 숨기고 저장 시 0으로 비운다. `receivable`과 `expectedPayback`은 둘 다 "돌아올 돈"이라 공존하면 이중 계상된다 |
| 정산 화면에 "1인당 얼마씩 받을지" 표시 | **표시하지 않는다.** `receivable ÷ (인원−1)`은 나머지 때문에 합이 `receivable`과 어긋난다(100,000/3명이면 66,667을 둘이 나눠야 함). 화면은 **인당 소비액**(`공용 합 ÷ 인원`)과 **받을 돈 합계**만 보여주고, 친구끼리의 개인별 채권은 범위 밖이다 |
| 여행 삭제 | 소비·`participants`·`paidByMe`는 남음. 정산 완료 여행은 크레딧도 남음(회수 안 함) |
| `amount / participants` 나머지 | 내림. 남의 몫(`receivable`)에 나머지가 붙는다 |
| 인원을 1로 내림 | 공용 아님 = `myShare == budgetAmount == amount`, `receivable 0` |

## 10. 테스트 계획

**`TripSettlementTests`** (순수 계산, CoreData 없음)
- 3명·내가 45만 결제 → `myShareTotal 15만 · receivable 30만`
- 친구가 낸 30만 숙소 3명 → `myShare 10만 · budgetAmount 10만 · receivable 0`
- 항목별 인원 혼재(3명 숙소 + 2명 저녁) → 합산이 항목별 몫의 합
- `participants = 1` → 셋 다 `amount`, `receivable 0`
- 내림: 10만 ÷ 3 → `myShare 33,333 · receivable 66,667`
- `fromWallet`/`fromBudget`이 `wishItemId` 유무로 갈린다

**`TripTests`** (인메모리 `CoreDataManager`, `setUp`에서 `resetAllData()`)
- 내가 낸 공용 소비는 그날 예산에서 전액 빠진다
- 친구가 낸 공용 소비는 내 몫만 빠진다 — `todayAvailable`과 초과 판정 모두
- 정산하면 `receivable`이 오늘 예산 크레딧으로 들어온다 (지갑 없음)
- 지갑 연결 여행: 소비가 지갑에서 빠지고, 정산 크레딧이 지갑 잔액을 회복한다
- 지갑 잔액이 부족한 소비는 자동 연결되지 않고 예산에서 빠진다
- 실제 수령액을 덮어쓰면 그 금액이 반영된다
- 정산 다시 열기 → 크레딧이 사라지고 진행 중으로 돌아온다
- 지갑 크레딧을 이미 써버렸으면 다시 열기가 거부되고 아무것도 바뀌지 않는다
- 이미 정산된 여행을 다시 정산하면 `false`
- 여행 삭제 → 소비는 남고 예산 영향 불변
- 인원 변경 시 그날부터 이월이 재계산된다
- `trip(containing:)` — 하나면 반환, 둘이면 nil, 정산 완료는 제외
- 내역 월 합계·통계 월 합계가 `myShare` 기준이다

**`CoreDataMigrationTests`** 추가
- `GagaeSsi 11` 스토어를 12로 열어도 기존 소비가 보존되고 `budgetAmount == myShare == amount`

## 11. 구현 순서 (커밋 단위)

각 단계는 독립적으로 빌드·테스트 통과 상태를 유지한다.

1. `feat:` CoreData 12 + `TripModel`/`TripSettlementModel` + `SpendingRecordModel` 파생값 + `TripSettlementTests` + 마이그레이션 테스트
2. `feat:` 예산 엔진 `budgetedSpending`·지갑 잔액을 `budgetAmount` 기준으로, 내역·통계·CSV를 `myShare` 기준으로 + 회귀 테스트
3. `feat:` `CoreDataManager` 여행 섹션 (CRUD·소비 연결·`settleTrip`·`reopenTrip`) + `TripTests`
4. `feat:` 소비 입력·편집 — 여행 필드·인원·누가 냈나·지갑 자동 선택·환급 필드 숨김
5. `feat:` 여행 목록·추가 시트·상세·정산 시트 + 설정 진입점
6. `feat:` 내역 🧳 배지·내 몫 표시, 위시 상세 정산 회수 표시

2번까지는 여행 화면 없이도 기존 앱이 그대로 돌아가는 상태이고, 3번부터 여행이 실제로 생긴다.
