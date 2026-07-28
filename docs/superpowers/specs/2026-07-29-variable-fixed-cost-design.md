# 변동 고정비 설계 (Phase A — v1.2 후보)

- **작성일**: 2026-07-29
- **상태**: Phase A 구현 완료 / Phase B(알림) 설계 예정
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

## 8. Phase B (범위 제외 — 다음)

- 지출일 로컬 알림: 오전 알림 + 오후 재알림(미결제 대비), 권한 처리
- 홈 "이번 달 미확정 N건" 프롬프트
- 지출일 말일 clamp 표시 보정 (`effectivePayday` clamp 재사용)
