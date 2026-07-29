# 이월 방식 선택 (모아둔 이월금) 설계

- **작성일**: 2026-07-29
- **상태**: 구현 완료
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)
- **관련 문서**: [하루 사용 가능 금액 계산 규칙](../../2026-07-08-daily-budget-calculation-rules.md), 업데이트 로그 "이월금 분리(v1.4 후보)"
- **관련 코드**: `Core/CoreDataManager.swift`, `Models/BudgetModels.swift`, `Features/Home/`, `Features/Settings/CarryOverModeSettingView.swift`

---

## 1. 배경·목적

기존은 전날 남은 금액(±)을 전액 다음 날 예산에 이월한다. 시간이 지나면 "오늘 쓸 수 있는 금액"이 과도하게 커져, 하루 예산을 지키게 돕는 앱 목적이 약해질 수 있다. 사용자가 **이월을 어떻게 반영할지 선택**할 수 있게 한다.

## 2. 확정된 설계 결정

| 결정 | 선택 |
|---|---|
| 남은 양수 처리 | **별도 '모아둔 이월금' 풀로 적립** (오늘 예산 미포함) |
| 과소비(음수) | **다음 날 이월 유지** (과소비 페널티는 제품 의도) |
| 전환 시점 | **오늘부터 적용**, 과거 일자·기존 풀 잔액 보존 |

## 3. 이월 방식 2종

- **전액 이월(`full`, 기본)**: 전날 잔액(±) 전액을 다음 날 `CarryOverSource`로 반영. 기존과 100% 동일.
- **모아둔 이월금 분리(`separate`)**: 전날→오늘 전환 시
  - 전날 잔액이 **양수** → 오늘 이월 0, 그 양수는 **모아둔 이월금 풀**에 적립
  - 전날 잔액이 **음수** → 그대로 오늘 이월(페널티)
  - 오늘 예산 = 기본예산 − 소비 − 위시 저금 (+ 전날 음수만)

## 4. 데이터 모델 (lightweight migration)

- `BudgetConfig.carryOverMode: String`(기본 `full`).
- 신규 `CarryOverPoolEntry`: `id, date, amount`(부호). **풀 잔액 = 합계**(+적립/−인출).
- 값 타입: `enum CarryOverMode { full, separate }`, `BudgetConfigModel.carryOverMode`.

## 5. 계산 엔진 (`processDailyBudgets`)

일자 생성 루프에서 `prevBalance = 전날.todayAvailable` 기준:
- `carry = (mode == .separate) ? min(0, prevBalance) : prevBalance`
- 분리 모드에서 `deposit = max(0, prevBalance) > 0`이면 `depositToPool`.
- 멱등성 유지(일자당 1회). 전액 이월 모드는 기존 동작 불변.

## 6. 꺼내 쓰기

- `withdrawFromPool(amount)`: 오늘 `CarryOverSource(+amount)` 추가 + `CarryOverPoolEntry(−amount)`. 잔액 초과 불가.
- 안 쓰고 남기면 다음 날 잔액이 양수 → 풀로 재적립(중복 없음). 초과 지출 시에만 페널티 없이 저금액을 쓰게 해주는 안전장치.

## 7. UI

- **설정 · 이월 방식**(`CarryOverModeSettingView`): 두 방식 카드 선택 + "오늘부터 적용" 안내.
- **홈**(분리 모드): "모아둔 이월금 ₩○○ · 꺼내 쓰기" 카드 → `CarryOverWithdrawView` 시트(전액 꺼내기 포함).

## 8. 엣지 케이스

| 케이스 | 처리 |
|---|---|
| 인출 후 미사용 | 다음 날 양수 → 풀 재적립 (round-trip 순증 0) |
| 잔액 초과 인출 | 거부 |
| 모드 전환(전액↔분리) | 오늘부터 적용, 과거 이월·풀 잔액 보존 |
| 위시 저금과 관계 | 저금 차감 후 남은 양수가 풀로 감 |

## 9. 테스트

`CarryOverModeTests` 7개: 분리 양수→풀·이월 0, 음수→페널티, 풀 누적, 인출(오늘 +·풀 −), 인출 가드, 전액 이월 회귀, 모드 전환 오늘부터.

## 10. 범위 제외 (v-next)

- 풀 잔액을 위시리스트 저금으로 이동
- 급여일마다 풀 초기화 옵션
- "일부만 이월"(비율/상한) 방식
