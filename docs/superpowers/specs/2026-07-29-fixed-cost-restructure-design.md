# 고정비 재구성 설계 (종류 분리 + 고정/변동 분리)

- **작성일**: 2026-07-29
- **상태**: 구현 진행
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)
- **관련 코드**: `Models/BudgetModels.swift`, `Core/CoreDataManager.swift`, `Features/Settings/FixedExpense*`

---

## 1. 배경·목적

고정비가 한 덩어리로 보여 "월 고정 지출" 숫자가 크게 느껴진다(#5 — 저축·투자까지 순수 지출로 뭉뚱그려져 기분이 좋지 않음). 또 고정/변동이 섞여 있다(#4). 고정비를 **종류(지출/저축/투자)**와 **고정/변동**으로 분리해 보여주고, 변동은 결제일 순으로 정렬한다.

## 2. 확정된 설계 결정

| 결정 | 선택 |
|---|---|
| 종류의 예산 영향 | **표시용만** — 저축·투자도 기존처럼 월급에서 차감(계산 불변) |
| 섹션 우선순위 | **종류 우선** — 저축·투자는 변동이어도 저축·투자 섹션에 |

## 3. 모델

- `FixedCost.kind: String` 추가 (기본 `지출`). `FixedCostKind` enum: 지출/저축/투자 (이모지·라벨).
- `FixedCostModel.kind` 추가.
- **예산 계산 무변경**: `DailyBudgetCalculator`는 종류 무관하게 모든 고정비를 차감.

## 4. 순수 로직 (`FixedCostGrouping`)

고정비 배열 → 3그룹 + 종류별 합계:
- `fixedSpending`: 지출·고정
- `variableSpending`: 지출·변동 (**dueDay 오름차순 정렬**)
- `savingInvestment`: 저축/투자 (변동 포함)
- `spendingTotal / savingTotal / investmentTotal`, `total`

## 5. UI

- **편집 화면**(`FixedExpenseEditView`): 상단 **종류 세그먼트**(지출/저축/투자). 기존 변동형 토글·지출일·(예상)금액 유지.
- **목록 화면**(`FixedExpenseListView`):
  - 합계 카드에 **종류별 breakdown**(지출/저축/투자) 표시.
  - 섹션(빈 섹션 숨김): ① 고정 지출 ② 변동 지출(결제일 순) ③ 저축·투자.
  - 변동 지출은 기존 변동 뱃지·이번 달 확정/미확정·확정 입력 유지.

## 6. 데이터·마이그레이션

`kind` String 추가 (lightweight migration, 기본 `지출`). 기존 항목은 지출로 동작·계산 불변.

## 7. 테스트

`FixedCostGroupingTests`: 종류별 합계, 3그룹 분류, 변동 지출 결제일 순 정렬, 저축·투자(변동 포함) 분류, 기본값(지출).

## 8. 범위 제외 (v-next)

- 투자 수익률·투자 탭(#8), 저축 목표 연동
- 종류별 통계 화면 반영
