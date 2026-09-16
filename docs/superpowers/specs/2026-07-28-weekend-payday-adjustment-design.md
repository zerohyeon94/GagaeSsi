# 주말 급여일 보정 설계 (v1.1 후보)

- **작성일**: 2026-07-28
- **상태**: 설계 확정 (구현 진행)
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)
- **관련 문서**: [하루 사용 가능 금액 계산 규칙](../../2026-07-08-daily-budget-calculation-rules.md)
- **관련 코드**: `Core/Utils/BudgetCalculationUtils.swift`, `Core/CoreDataManager.swift`

---

## 1. 배경·목적

급여일이 **주말**이면 실제 입금은 직전 평일(금요일)에 이뤄진다. 현재 `DailyBudgetCalculator`는 명목 급여일을 그대로 급여 기간 경계로 사용해 현실과 어긋난다. 또한 급여일을 29~31일로 설정하면 그 날이 없는 달(2월·30일 달)에서 `DateComponents(day:31)`이 다음 달로 오버플로되는 **기존 P0 버그**가 있다.

두 문제 모두 "명목 급여일 → 실제 입금일" 변환이 없어서 생기므로 **하나의 보정 함수로 함께 해결**한다.

## 2. 확정된 설계 결정

| 결정 사항 | 선택 |
|---|---|
| 보정 방식 | **급여 기간 경계 이동** (표시만이 아니라 일일예산 계산에 반영) |
| 보정 대상 | **주말만** (토·일). 공휴일은 범위 제외 (데이터 유지보수 부담) |
| 보정 방향 | **직전 금요일** (토 −1, 일 −2) |
| 말일 보정 | **함께 처리** (주말 보정의 전제 조건) |

## 3. 핵심 규칙

### 3-1. 실효 급여일 `effectivePayday(payday:year:month:)`

명목 급여일을 해당 연·월의 실제 입금일(startOfDay)로 변환한다.

1. **말일 보정**: `day = min(payday, 그 달의 일수)`
   - 예: payday 31 + 2026년 2월 → 2월 28일, payday 31 + 4월 → 4월 30일
2. **주말 보정**: 위 날짜의 요일이
   - 토요일 → −1일 (금)
   - 일요일 → −2일 (금)
   - 평일 → 보정 없음

### 3-2. 급여 기간 계산 (후보 브래킷팅)

명목월 산술로 경계를 구하면, 실효 급여일이 달 경계를 넘는 경우(예: 1일이 일요일 → 전월 말)를 놓친다. 대신 **today 주변 3개월의 실효 급여일 후보로 감싼다**:

```
today가 속한 달 기준 prev·this·next 3개월의 effectivePayday를 계산 → 오름차순 정렬
periodStart = (today 이하인 실효 급여일) 중 가장 늦은 것
periodEnd   = (today 초과인 실효 급여일) 중 가장 이른 것
totalDays   = periodEnd − periodStart (일)
일일예산    = (월급 − 고정비 합계) ÷ totalDays  (원 단위 내림, 기존과 동일)
```

- 보정폭이 최대 2일이고 한 달은 최소 28일이므로 3개월 후보면 항상 today를 감싼다.
- `periodStart <= today < periodEnd` 반열림 구간. 급여일 당일은 새 기간의 시작(periodStart)이다.

### 3-3. 이월·리셋과의 관계

- 이월 체인(`processDailyBudgets`)은 **급여일에 리셋되지 않고 연속**이며, 각 날짜의 기본 일일예산만 `calculate(from:for:)`로 매일 재계산된다.
- 따라서 경계 이동은 "며칠부터 새 기간의 일일예산이 적용되는지"만 바꾼다. 일시금 입금·리셋 로직이 없어 **`processDailyBudgets`·통계·CoreData 스키마 변경이 전혀 없다.**

## 4. 영향 범위

`DailyBudgetCalculator` (`Core/Utils/BudgetCalculationUtils.swift`)만 수정한다.

| 함수 | 변경 |
|---|---|
| `effectivePayday(payday:year:month:)` | **신규** — 말일 clamp + 주말 보정 |
| `payPeriod(payday:containing:)` | **신규** — 3개월 후보 브래킷팅으로 (start, end) 반환 |
| `calculate(from:for:)` | periodEnd를 브래킷 기반으로. 기존 `periodStart + 1개월` 고정 제거 |
| `calculatePayPeriodStart(payday:today:)` | 브래킷의 start 반환 (시그니처 유지 — 호환) |
| `daysUntilNextPayday(payday:from:)` | 브래킷의 end 사용 |

호출부(`HomeViewModel`, `StatsViewModel`, `CoreDataManager.processDailyBudgets`)는 **시그니처 무변경**이라 수정 불필요.

## 5. 표시 (UI)

- 계산기에 헬퍼 노출: `nextPayday(payday:from:)`(다음 실효 급여일), `isPaydayAdjusted(payday:year:month:)`(보정 발생 여부).
- **급여일 설정 화면**(`EditBudgetView`, `SetupSalaryView`)에 규칙 안내 문구 1줄 상시 표시: "급여일이 주말이면 직전 평일에 입금돼요 📅".
- 홈 배너(이번 급여일이 실제 보정될 때만 "이번 급여일 25일은 주말이라 24일(금) 입금")는 **선택적 v-next**로 남긴다. 현재 홈에 급여일 관련 UI가 없어 신규 배치가 필요하므로 이번 범위에서 제외.

## 6. 테스트 계획

`GagaeSsiTests`에 `DailyBudgetCalculatorTests` 신설 (순수 함수라 인메모리 CoreData 불필요):

- **말일 clamp**: payday 31 + 2월(윤/평년) → 말일, payday 31 + 4월 → 30일, 오버플로로 다음 달 넘어가지 않음
- **주말 보정**: 특정 연·월에서 토요일 급여일 → 금요일, 일요일 급여일 → 금요일
- **평일 무보정**: 평일 급여일은 명목일과 동일
- **기간 일수 회귀**: 보정 전/후 totalDays·일일예산 비교로 경계 이동 검증
- **월 경계 극단**: payday 1이 일요일인 달 → periodStart가 전월 말 금요일
- **반열림 경계**: today == 실효 급여일이면 그 날이 periodStart

## 7. 엣지 케이스

| 케이스 | 처리 |
|---|---|
| 급여일 29~31 + 짧은 달 | 말일로 clamp 후 주말 보정 |
| clamp된 말일이 주말 | 그대로 −1/−2 (금요일로) |
| 급여일 1일이 일요일 | 전월 말 금요일로 (브래킷 자동 처리) |
| 평일 급여일 | 보정 없음 — 기존과 동일 결과 (회귀 없음) |
| totalDays 0 이하(방어) | usableSalary 그대로 반환 |

## 8. 범위 제외 (v-next)

- 공휴일 보정 (매년 갱신·음력 이동 데이터 필요)
- 홈 화면 급여일 보정 배너
- "다음 월요일 지급" 등 회사별 지급 정책 옵션
