# 변동 고정비 설계 (Phase A — v1.2 후보)

- **작성일**: 2026-07-29
- **상태**: **Phase A · Phase B 구현 완료**
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)
- **관련 코드**: `Core/CoreDataManager.swift`, `Models/BudgetModels.swift`, `Features/Settings/FixedExpense*`

---

## 1. 배경·목적

관리비·이자·환율처럼 **매달 금액이 달라지는 고정비**를 다룬다. 기존 `FixedCost`는 고정 월액 하나뿐이라 이런 항목을 정확히 반영하지 못했다. 변동 고정비에 **예상액**을 두고, 매월 지출일에 **실제 확정 금액**을 입력하면 하루 예산에 반영한다.

## 2. 확정된 설계 결정

| 결정 | 선택 |
|---|---|
| 분할 | **2단계** — Phase A(모델+예산+입력), Phase B(알림) |
| 예산 반영 | **예상액 배분 + 확정 시 재계산** (기존 "설정 변경 시 오늘부터 재계산" 규칙 재사용) |
| 소비 기록 | 생성 안 함 — 예산 배분값만 조정 (자동이체 이중 차감 방지) |

## 3. 데이터 모델 (lightweight migration)

- `FixedCost`에 추가: `isVariable: Bool`(기본 false), `dueDay: Int16`(지출일 1~31, 0=미설정). `amount`는 변동형의 **현재 예상액(=마지막 확정액)**.
- 신규 `MonthlyFixedCostEntry`: `id, year, month, amount, confirmedAt` + `FixedCost` 관계(**Cascade** 삭제). 월별 확정 이력·"이번 달 확정" 판정.
- 값 타입: `FixedCostModel`(+`isVariable`,`dueDay`), `MonthlyFixedCostEntryModel`.

## 4. 예산 반영 (계산 엔진 무변경)

- `DailyBudgetCalculator.calculate`는 기존대로 `amount`를 배분. 변동형도 동일.
- **확정 흐름** `CoreDataManager.confirmMonthlyAmount(costId, year, month, amount)`:
  1. (비용, 연, 월) 월별 엔트리 upsert — 이력 기록
  2. `FixedCost.amount = 확정액` — 배분에 반영
  3. `notifyFixedExpenseChanged()` → 홈이 `recalculateTodayBudget()`로 오늘부터 재계산
- 과거 일자 예산은 불변(멱등). 오늘·이후만 새 금액 적용 = "확정 시 그날부터 재계산".

## 5. UI

- `FixedExpenseEditView`: "변동형" 토글 → 지출일 선택 + 금액 라벨 "예상 월 금액".
- `FixedExpenseListView`: 변동형 행에 `변동` 뱃지 + "매월 N일 · 이번 달 확정/미확정(예상 ○○)". "확정 입력/수정" 버튼 → `MonthlyAmountConfirmView` 시트에서 확정.

## 6. 엣지 케이스

| 케이스 | 처리 |
|---|---|
| 이번 달 미확정 | 예상액으로 배분, 목록 "미확정(예상 ○○)" |
| 예상액 편집 vs 확정 | 둘 다 amount 갱신, 확정만 이력 남김 |
| 변동 고정비 삭제 | 월별 엔트리 Cascade 삭제 |
| 기존 고정비 | `isVariable=false` 마이그레이션, 동작 불변 |

## 7. 테스트

`VariableFixedCostTests` 6개: 플래그 저장, 확정 upsert+amount 갱신, 재확정 덮어쓰기, 다른 달 미확정, `calculate` 확정액 반영, Cascade 삭제.

## 8. Phase B — 지출일 알림 (구현 완료, 2026-07-29)

**결정**: 오전 + 오후 재알림 · 홈 배너 포함.

- **`NotificationService`** (`Core/NotificationService.swift`): 로컬 알림(UNUserNotificationCenter).
  - `VariableCostReminder.nextDueDate(dueDay:from:isCurrentMonthConfirmed:)` — 순수 로직.
    이번 달 지출일이 오늘 이후이고 미확정이면 이번 달, 아니면 다음 달. 말일 clamp.
  - `refreshVariableCostReminders`: 기존 `vcost-` 알림 제거 후, 각 변동 고정비의 다음 미확정
    지출일에 **오전 9시 + 오후 8시** 알림 2건 스케줄(비반복). 지난 시각은 스킵.
  - 식별자 `vcost-<id>-am/-pm` → 재설정 시 자연 대체.
- **재설정 시점**: 앱 활성화(`RootView` scenePhase/task), 확정·추가·수정·삭제(`FixedExpenseListView.afterChange`).
  확정하면 그달 알림이 다음 달로 밀려 그날 오후 재알림이 자동 취소된다.
- **권한**: 변동 고정비 최초 생성 시 맥락 요청(`requestAuthorizationIfNeeded`).
- **홈 배너**: 지출일이 지났는데 이번 달 미확정인 변동 고정비가 있으면 "이번 달 미확정 N건"
  배너 표시 → 탭 시 고정비 관리 시트로. `CoreDataManager.unconfirmedVariableCosts(asOf:)`.
- **초기화**: `resetAllData` 시 `cancelAllVariableCostReminders`.
- **테스트**: `NotificationSchedulingTests` 7(다음 알림일·clamp·확정 분기), 미확정 조회 1.
- **부수 수정**: `recalculateTodayBudget`가 위시 저금액을 누락하던 문제 수정(재계산 시 오늘 가용액 정확).
