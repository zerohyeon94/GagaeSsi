# 초과 소비 상환 계획 설계

- **작성일**: 2026-08-07
- **상태**: 설계 확정
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)
- **관련 문서**: [하루 사용 가능 금액 계산 규칙](../../2026-07-08-daily-budget-calculation-rules.md), [이월 방식 선택 설계](2026-07-29-carryover-mode-design.md)
- **관련 코드**: `Core/CoreDataManager.swift`, `Core/Utils/BudgetCalculationUtils.swift`, `Models/BudgetModels.swift`, `Features/Home/`, `Features/Settings/`

---

## 1. 배경·목적

현재는 전날 초과 지출(음수 잔액)이 **다음 날 예산에서 전액 차감**된다. 과소비 페널티는 제품 의도이지만, 큰 금액을 초과했을 때 다음 날 예산이 통째로 음수가 되어 "오늘 얼마 쓸 수 있어?"라는 앱의 핵심 질문에 답을 못 하는 상태가 된다. 사용자가 회복을 포기하게 만드는 구간이다.

초과분을 **부채로 분리**해 며칠에 걸쳐 나눠 갚게 하면, 하루 예산은 원래 금액을 유지한 채 회복 계획이 눈에 보인다. 페널티는 유지하되 감당 가능한 크기로 쪼개는 것이 목적이다.

## 2. % 범위·기본값의 근거

사용자가 고를 수 있는 범위를 **하루 예산의 10~50%(5% 단위), 기본 20%** 로 정한 근거:

| 구간 | 근거 |
|---|---|
| **20%** (기본·추천) | **50/30/20 법칙** — Elizabeth Warren이 대중화한 예산 원칙. 세후 소득의 20%를 저축 + 부채 상환에 배정한다. 가장 널리 쓰이는 기준선이므로 기본값으로 채택. |
| **25~35%** (공격적) | 고금리 부채 상황에서 권장되는 **50/15/35 변형** — '원하는 것(wants)' 배분을 일시적으로 상환에 돌려 최대 35%까지 올리는 것이 합리적이라고 안내된다. |
| **40% 이상** (경고) | 한국 **DSR(총부채원리금상환비율) 규제 상한이 은행권 40%**, 비은행권 60%다. 40%는 금융당국이 정한 '더 빌리면 안 되는 선'이므로, 이 이상을 고르면 경고 문구를 노출한다. |
| **10%** (하한) | 그 이하는 상환 기간이 과도하게 길어져(예: 하루 예산 2일치 초과 시 20일+) 계획으로서 의미가 흐려진다. |

참고 자료:
- [The 50/30/20 Budget Rule Explained — Ramsey](https://www.ramseysolutions.com/budgeting/50-20-30-budget-rule)
- [What is the 50/30/20 Budget Rule? — Discover](https://www.discover.com/personal-loans/resources/consolidate-debt/50-30-20-rule/)
- [Using the 50-30-20 rule to power your household budget — Britannica Money](https://www.britannica.com/money/what-is-the-50-30-20-rule)
- [3단계 스트레스 DSR 시행방안 확정·발표 — 금융위원회](https://www.fsc.go.kr/no010101/84617)

> 주의: 위 자료는 모두 **월 소득 대비 비율**에 대한 것이고, 본 기능은 **하루 예산 대비 비율**에 적용한다. 산술적으로 동일한 기준은 아니며, 사용자가 감을 잡을 수 있는 **출발점**으로만 사용한다. 앱은 투자·재무 조언을 하지 않으며 UI 문구도 "추천" 수준으로만 표현한다.

## 3. 확정된 설계 결정

| 결정 | 선택 |
|---|---|
| 예산 계산 방식 | **부채로 분리**. 초과분을 이월에서 떼어내 별도 관리하고, 하루 예산은 원래 금액 유지 + 상환액만 차감 |
| 계획 진행 중 재초과 | **남은 부채에 합산 + 기간만 재계산** (%는 유지, 팝업 재노출 없음) |
| 팝업 노출 조건 | **초과분 ≥ 기본 일일 예산 × 10%** 일 때만. 설정에서 기능 전체 on/off (기본 on) |
| 기능 OFF / 임계 미만 | **기존 동작 그대로** (음수 전액 이월) |
| 급여일 | 부채 **리셋하지 않음** (기존 "급여일 이월 유지" 규칙과 일관) |
| 이월 방식(전액/분리)과의 관계 | 부채는 **음수 처리만 대체**. 양수 처리(이월/풀 적립)는 두 모드 모두 기존과 동일 |
| 모아둔 이월금 풀과의 우선순위 | **풀 부족액 충당이 먼저** — 충당하면 잔액이 0이 되어 부채가 생기지 않음 (별도 분기 불필요) |

## 4. 계산 규칙

`processDailyBudgets(upTo:)`의 일자 생성 루프에서 `prevBalance = 전날.todayAvailable` 기준.

### 4-1. 초과분 → 부채 전환

```
threshold = 기본 일일 예산 × 10%   (원 단위 내림)

prevBalance ≥ 0                          → 기존 그대로 (전액 모드: 이월 / 분리 모드: 풀 적립)
prevBalance < 0, 기능 OFF                → 기존 그대로 (음수 전액 이월)
prevBalance < 0, |prevBalance| < threshold → 기존 그대로 (음수 전액 이월)
prevBalance < 0, |prevBalance| ≥ threshold → 이월 0, 부채에 |prevBalance| 합산
```

부채 합산 시:
- 활성 부채가 없으면 신규 생성 (`isPlanned = false`, 계획 미확정 상태)
- 활성 부채가 있으면 `originalAmount += `, `remainingAmount += ` (`isPlanned`·`repayRatePercent`는 유지)

### 4-2. 일별 상환

활성 부채가 있고 `isPlanned == true`인 날마다:

```
상환액 = min(remainingAmount, 기본 일일 예산 × repayRatePercent% ⌊원 단위 내림⌋)
```

- `CarryOverSource(amount: −상환액, date: 그날, toDate: 그날)` 추가
  → `DailyBudgetModel.todayAvailable`이 자동 반영. **`withdrawFromPool`과 동일한 패턴**이므로 `recalculateCarryOverChain`(과거 소비 수정 시 `date < cursor`인 소스만 삭제)에 안전하게 보존된다.
- `DebtRepaymentEntry(date:amount:)` 원장 기록, `remainingAmount −= 상환액`
- `remainingAmount == 0` → `completedAt` 설정, 부채 비활성화

**멱등성**: 그날 `DebtRepaymentEntry`가 이미 있으면 건너뛴다. `processDailyBudgets`를 여러 번 호출해도 중복 상환되지 않는다.

**계획 미확정(`isPlanned == false`)**: 상환액 0. 앱을 며칠 안 열어 팝업을 못 본 기간에는 부채만 쌓이고 상환은 시작되지 않는다. 홈 진입 후 계획을 확정한 날부터 상환이 시작된다.

### 4-3. 순수 함수 (TDD 대상)

```swift
enum DebtRepaymentPlan {
    /// 하루 상환액과 예상 소요 일수를 계산한다.
    static func calculate(debt: Int, dailyBudget: Int, ratePercent: Int)
        -> (perDay: Int, days: Int)

    /// 초과분이 부채로 전환될 임계값 (기본 일일 예산의 10%)
    static func threshold(dailyBudget: Int) -> Int

    /// 40% 이상이면 경고 대상
    static func isAggressive(ratePercent: Int) -> Bool
}
```

- `perDay = dailyBudget × ratePercent / 100` (원 단위 내림)
- `days = ceil(debt / perDay)` — 마지막 날은 남은 부채만 차감하므로 `perDay`보다 적을 수 있다
- 가드: `perDay == 0`(예산이 너무 작음)이면 `days = 0` 반환, 계획 확정 불가 처리

## 5. 데이터 모델 (CoreData `GagaeSsi 3`, lightweight migration)

### 신규 엔티티 `SpendingDebt`
| 속성 | 타입 | 설명 |
|---|---|---|
| `id` | UUID | |
| `originalAmount` | Decimal | 누적 발생 총액 (재초과 시 증가) |
| `remainingAmount` | Decimal | 남은 부채 |
| `repayRatePercent` | Int16 | 10~50, 5 단위 |
| `isPlanned` | Bool | 계획 확정 여부 |
| `startedAt` | Date | 최초 발생일 |
| `completedAt` | Date? | 완납일 (nil이면 활성) |
| `repayments` | to-many → `DebtRepaymentEntry` | |

활성 부채는 항상 **최대 1개** (`completedAt == nil`).

### 신규 엔티티 `DebtRepaymentEntry`
| 속성 | 타입 | 설명 |
|---|---|---|
| `id` | UUID | |
| `date` | Date | 상환일 (startOfDay) |
| `amount` | Decimal | 그날 상환액 |
| `debt` | to-one → `SpendingDebt` | |

### `BudgetConfig` 필드 추가
- `debtPlanEnabled: Bool` (기본 `true`)

### 값 타입 (`Models/DebtModels.swift`)
- `struct SpendingDebtModel` — `init(entity:)` 변환 생성자 포함
- `struct DebtRepaymentEntryModel`

## 6. UI

### 6-1. 계획 설정 시트 (`DebtPlanSheet`)
홈 진입 시 `isPlanned == false`인 활성 부채가 있으면 1회 표시.

- 초과 금액 / 하루 사용 가능 금액 표시
- % 선택: 10~50, 5% 단위 (기본 20%)
- 실시간 결과: **"하루 10,000원씩 · 10일 동안"**
- 40% 이상 선택 시 경고: "한국 DSR 규제 상한(은행권 40%)보다 빡센 설정이에요. 무리하면 다시 초과하기 쉬워요."
- 버튼: **[이 계획으로 갚기]** / **[나중에]**
  - "나중에" → 오늘은 재표시하지 않고 홈 배너로만 유지 (다음 날 홈 진입 시 재표시)

### 6-2. 홈 화면
```
오늘 쓸 수 있는 금액        38,000원

  기본 일일 예산            50,000원      ← 원래 금액 그대로
  초과분 상환               −10,000원
  오늘 소비                 −2,000원

🐷 초과분 갚는 중
   [▓▓▓░░░░░░░]  70,000 / 100,000원 · 앞으로 7일
```
- 브레이크다운에 "기본 일일 예산"을 **원래 금액**으로 명시하고, 상환액을 별도 행으로 노출
- 진행 게이지 = `(originalAmount − remainingAmount) / originalAmount`
- `CharacterState`에 `.repaying`(회복 중) 추가 — 기존 `.coveredFromPool`과 동일한 결의 순한 메시지. 죄책감 유발 표현 금지.

### 6-3. 설정
"초과 소비 상환 계획" 섹션:
- 기능 on/off 토글 (기본 on)
- 부채 진행 중이면: 남은 금액·% 표시, **% 변경**, **조기 완납**(오늘 예산에서 남은 전액 차감)

## 7. 엣지 케이스

| 케이스 | 처리 |
|---|---|
| 상환 중 또 초과 | 남은 부채에 합산, 기간만 재계산. % 유지, 팝업 없이 홈 배너로 알림 |
| 임계 미만 소액 초과 | 기존대로 음수 전액 이월 (부채 생성 안 함) |
| `perDay == 0` (예산 대비 % 가 너무 작음) | 계획 확정 불가. 더 높은 %를 고르도록 안내 |
| 기능 OFF 전환 시 기존 부채 | 남은 부채를 **그날 이월(음수)로 전환**해 즉시 반영 후 부채 종료 |
| 급여일 도래 | 부채 유지 (리셋 안 함) |
| 과거 소비 수정/삭제 | 상환 `CarryOverSource`는 `date == 그날`이라 `recalculateCarryOverChain`에서 보존됨. 부채 잔액은 재계산하지 않음 (기록 보존) |
| 분리 모드 풀 충당과 동시 발생 | 풀 충당이 먼저 → 잔액 0 → 부채 미발생 |
| 데이터 초기화 | `SpendingDebt`·`DebtRepaymentEntry` 함께 삭제 |

## 8. 테스트 (`DebtRepaymentTests`)

1. `calculate` — 10만원 부채 / 5만원 예산 / 20% → (10,000원, 10일)
2. `calculate` — 나누어떨어지지 않을 때 `days`가 올림
3. `threshold` — 기본 예산 10% 원 단위 내림
4. `isAggressive` — 40% 이상만 true
5. 임계 초과 시 이월 0 + 부채 생성
6. 임계 미만 시 기존 음수 이월 (부채 미생성)
7. 기능 OFF 시 기존 음수 이월
8. 계획 확정 후 일별 상환 차감 + 원장 기록
9. 멱등성 — `processDailyBudgets` 2회 호출 시 중복 상환 없음
10. 마지막 날 남은 부채만 차감 후 완납 처리
11. 상환 중 재초과 시 부채 합산
12. 전액 이월 모드 회귀 — 부채 기능 OFF면 기존 동작 동일

## 9. 범위 제외 (v-next)

- 남은 양수 잔액으로 부채 자동 조기 상환
- 부채 이력 화면 (완납한 부채 목록)
- 급여일에 부채 리셋 옵션
- 부채별 개별 상환 계획 (현재는 단일 부채로 합산)
