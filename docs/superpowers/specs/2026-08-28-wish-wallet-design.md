# 위시 지갑 — 모은 돈으로 쓴 소비는 예산에서 빼지 않기

- **작성일**: 2026-08-28
- **상태**: 구현 완료 (2026-08-29)
- **브랜치**: develop
- **관련 문서**: [위시리스트 저금 설계](2026-07-15-wishlist-saving-design.md), [부채 수명주기 & 과거 초과 전환](2026-08-26-debt-lifecycle-and-past-overspend-design.md) (7절에서 분리된 항목)
- **관련 코드**: `Core/CoreDataManager.swift`(위시 섹션), `Models/WishModels.swift`, `Models/BudgetModels.swift`, `Models/OverspendModels.swift`, `Features/Spend/`

---

## 1. 배경 / 문제

계획된 여행은 위시 저금으로 모을 수 있다 — "제주 여행 80만원, 하루 1만원"을 걸어두면
매일 하루 예산에서 1만원이 빠지며 모인다. **문제는 실제로 여행을 가서 쓸 때다.**

- `completeWish`는 소비 기록을 만들지 않는다 (이미 매일 차감으로 모은 돈이므로 옳다)
- 그런데 여행 중 소비를 가계부에 적으면 **그날 예산에서 또 빠진다**
- 결과: 이중 차감 → 큰 초과 → 부채. 모은 돈으로 쓴 건데 빚이 된다

지금 구조에서 계획 여행을 제대로 쓰려면 여행 중 소비를 아예 기록하지 말아야 하는데,
그건 가계부로서 말이 안 된다. **소비 기록을 위시 잔액에 연결하는 통로가 필요하다.**

## 2. 컨셉

위시를 "모으는 목표"에서 **"모아둔 지갑"**으로 확장한다.
목표를 채우면(`purchasable`) 그 위시는 잔액을 가진 지갑이 되고, 소비를 그 지갑에 달면
하루 예산 대신 지갑에서 빠진다.

```
위시 잔액 = Σ 저금 엔트리 − Σ 그 위시에 연결된 소비
```

소비 기록 자체는 그대로 남는다 — 실제로 쓴 돈이므로 소비 통계·내역에는 보여야 한다.
**예산 차감과 초과 판정에서만 빠진다.**

## 3. 확정된 설계 결정

| 결정 | 선택 | 근거 |
|---|---|---|
| 연결 방식 | `SpendingRecord` ↔ `WishItem` 관계 | 소비는 소비로 남기고 예산 차감만 면제. 별도 엔티티를 만들면 통계·내역이 갈라진다 |
| 잔액 초과 연결 | **잔액 한도 내에서만 허용** | 부분 커버(일부는 지갑, 일부는 예산)는 건별 순서에 따라 결과가 달라져 재계산이 불안정해진다 |
| 연결 가능 대상 | 잔액이 남은 위시 (저금중·구매가능 모두) | 목표 도달 전이라도 모아둔 만큼은 쓸 수 있어야 한다 |
| 소비 통계 | **포함한다** | 실제로 쓴 돈이다. 저금 시점엔 소비로 잡히지 않았으므로 이중 계상이 아니다 |
| 초과 판정 | 제외한다 | 지갑에서 나간 돈을 그날 과소비로 치면 여행 날이 전부 '초과한 날'이 된다 |
| 위시 삭제 | 연결만 끊고(Nullify) 이월 체인 재계산 | 소비가 예산 차감 대상으로 되살아나므로 그날부터 다시 계산해야 한다 |

## 4. 데이터 모델 (CoreData `GagaeSsi 11`)

배포된 버전은 in-place 수정하지 않는다 — **새 버전 `GagaeSsi 11`을 만든다.**

```
SpendingRecord
  + relationship wishItem (optional, maxCount 1, Nullify) → WishItem
WishItem
  + relationship spendingRecords (optional, toMany, Nullify) → SpendingRecord
```

두 관계 모두 optional이고 새 속성이 없으므로 lightweight migration으로 열린다.

**모델 변경**
- `SpendingRecordModel.wishItemId: UUID?` — nil이면 평소 소비
- `WishItemModel.spentAmount: Int` 추가, `balance = savedAmount − spentAmount`

## 5. 예산 계산 (핵심)

두 곳에서 **위시에 연결된 소비를 뺀다.**

```swift
// DailyBudgetModel.todayAvailable
let spent = spendingRecords.filter { $0.wishItemId == nil }.map(\.amount).reduce(0, +)

// OverspendAnalyzer.evaluate — outgoing (초과 판정 기준)
let outgoing = budget.spendingRecords.filter { $0.wishItemId == nil }...
```

이 두 줄이 기능의 전부다. 나머지(이월 체인, 부채 전환, 급여일 흡수)는 `todayAvailable`
위에 서 있으므로 자동으로 따라온다.

**주의**: `fetchSpendingRecords`(통계·내역)는 필터하지 않는다. 소비는 소비로 보여야 한다.

## 6. 데이터 계층 API

```swift
/// 위시 잔액 = 모은 돈 − 이 위시에 연결된 소비
func wishBalance(for wishItemId: UUID) -> Int

/// 소비를 위시 지갑에 연결한다. 잔액을 넘으면 실패.
/// 연결하면 그날 예산에서 빠지지 않으므로 그날부터 이월을 다시 계산한다.
@discardableResult
func linkSpendingToWish(recordId: UUID, wishItemId: UUID) -> Bool

/// 연결을 끊는다. 다시 예산 차감 대상이 되므로 마찬가지로 재계산한다.
@discardableResult
func unlinkSpendingFromWish(recordId: UUID) -> Bool
```

- 두 메서드 모두 `recalculateCarryOverChain(from: 그 소비의 날짜)`를 부른다
  (2189500에서 정한 "재계산은 데이터 계층 책임" 원칙)
- 위시 삭제(`deleteWishItem`)도 연결된 소비가 있으면 가장 이른 날짜부터 재계산한다

## 7. 화면

**소비 입력/수정** — 잔액이 남은 위시가 있을 때만 노출한다.
- "🎁 모아둔 위시에서 쓰기" 토글 + 위시 선택
- 선택하면 "제주 여행 · 남은 320,000원" 표시, 금액이 잔액을 넘으면 저장 버튼 비활성 + 안내
- 연결된 소비는 "오늘 쓸 수 있는 금액"을 건드리지 않는다는 한 줄 설명

**위시 목록/상세** — 목표 도달 후에는 게이지 대신 지갑으로 보여준다.
- "모은 320,000원 중 180,000원 씀 · 남은 140,000원"
- 연결된 소비 목록 (날짜·항목·금액)

**내역** — 위시에서 나간 소비에 🎁 배지를 달아 "예산에서 빠지지 않은 소비"임을 표시한다.

## 8. 테스트 계획

**예산 계산**
- 위시 연결 소비는 `todayAvailable`을 줄이지 않는다
- 연결 소비만 있는 날은 '초과한 날'로 잡히지 않는다
- 연결을 끊으면 그날부터 이월이 다시 줄어든다

**잔액**
- 잔액 = 저금 합 − 연결 소비 합
- 잔액을 넘는 연결은 거부되고 아무것도 바뀌지 않는다
- 잔액이 0이 되면 더 연결할 수 없다

**연동**
- 과거 날짜 소비를 연결하면 이후 날 이월이 되살아난다 (재계산 확인)
- 위시를 지우면 연결이 끊기고 그날부터 예산이 다시 차감된다
- 연결 소비는 소비 통계·내역에는 그대로 남는다

**마이그레이션**
- `GagaeSsi 10` 스토어를 11로 열어도 기존 데이터가 보존된다 (기존 `CoreDataMigrationTests` 패턴)

## 9. 구현 순서 (커밋 단위)

1. `feat:` CoreData `GagaeSsi 11` + 모델 필드 (`wishItemId`, `spentAmount`)
2. `feat:` 예산 계산에서 위시 연결 소비 제외 + 데이터 계층 API + 테스트
3. `feat:` 소비 입력 화면에서 위시 지갑 연결
4. `feat:` 위시 화면 지갑 표시 · 내역 배지

각 단계는 독립적으로 빌드·테스트 통과 상태를 유지한다.
