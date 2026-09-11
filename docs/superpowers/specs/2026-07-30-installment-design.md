# 할부 처리 설계 (월 분할 예산 차감)

- **작성일**: 2026-07-30
- **상태**: 구현 진행
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)
- **관련 문서**: [하루 사용 가능 금액 계산 규칙](../../2026-07-08-daily-budget-calculation-rules.md)
- **관련 코드**: `Core/Utils/BudgetCalculationUtils.swift`, `Core/CoreDataManager.swift`, `Models/`, `Features/Settings/`

---

## 1. 배경·목적

할부 구매는 큰 금액이 여러 달에 걸쳐 빠져나가 가계부 정리가 애매하다. 전액을 한 번에 소비로 잡으면 그 달 예산이 왜곡되고, 무시하면 실제 지출이 누락된다. 할부를 **월 분할로 그 달 예산에서 미리 차감**한다(고정비와 동일한 "이미 나갈 돈" 취급).

## 2. 확정된 설계 결정

| 결정 | 선택 |
|---|---|
| 예산 반영 | **매월 하루 예산에서 미리 차감** (활성 개월만, 고정비 스타일) |
| 입력 | **총액 + 개월수** → 월 납입액 자동 계산. 이자는 총액에 포함 |
| 소비 기록 | 생성 안 함 (이중 차감 방지) |

## 3. 모델

- 신규 엔티티 `Installment`: `id, title, totalAmount, months, startYear, startMonth, createdAt`.
- `InstallmentModel` + 계산:
  - `monthlyAmount = totalAmount / months`(정수).
  - `monthsSinceStart(date) = (year−startYear)*12 + (month−startMonth)`.
  - `isActive(date) = 0 ≤ monthsSinceStart < months`.
  - `remainingMonths(date)`: 시작 전 → months, 완료 → 0, 진행 중 → `months − monthsSinceStart`.
  - `static activeMonthlyTotal(_, for:)`: 그 달 활성 할부들의 월 납입액 합.

## 4. 예산 계산 (규칙 확장)

- `DailyBudgetCalculator.calculate(from:, installments: [InstallmentModel] = [], for:)`:
  `usableSalary = 월급 − 고정비 − activeInstallmentTotal(date)`. 급여기간·나눗셈 동일.
- 호출부 5곳(`CoreDataManager` 3, `HomeViewModel`, `StatsViewModel`)에서 `fetchInstallments()` 전달.
- 소비 기록·이월·통계 로직은 무변경(usableSalary만 감소).

## 5. UI

- 설정 → **할부 관리**(`InstallmentListView`): 진행 중/완료 목록. 항목별 제목·총액·**남은 N개월 · 월 X원**·진행률. 추가/편집/삭제.
- 추가/편집 시트(`InstallmentEditView`): 제목·총액·개월수·시작 월(기본 이번 달) → 월 납입액 미리보기.
- 설정 "예산 설정" 섹션에 진입점.

## 6. 자동 종료

개월수 경과 시 `isActive`가 false → 예산 차감 자동 중단, 목록에는 "완료" 표시. 별도 배치 없음.

## 7. 데이터·마이그레이션

신규 `Installment` 엔티티(lightweight migration). `resetAllData` 목록에 포함.

## 8. 테스트

`InstallmentTests`: monthlyAmount, monthsSinceStart, isActive(진행 중/시작 전/종료 후), remainingMonths, `activeMonthlyTotal` 다중 합산, `calculate`가 할부 반영.

## 9. 엣지 케이스

| 케이스 | 처리 |
|---|---|
| 개월수 경과 | 완료 — 차감 제외 |
| 시작 월 미래 | 시작 전 — 아직 미반영 |
| 총액 < 개월수 | 허용, 월 = total/months |
| 무이자/유이자 | 이자 포함 총액 입력 |

## 10. 범위 제외 (v-next)

- 홈 "이번 달 할부 합계" 카드
- 할부 이자율 자동 계산, 중도 상환
