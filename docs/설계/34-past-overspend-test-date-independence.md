# #34 PastOverspendConversionTests 실패 2개 — 날짜 의존성 제거 설계

- 이슈: #34
- 대상 기능: 가게씨 - 초과분 부채와 상환
- 분류: 테스트 수정 (앱 구현 변경 없음)
- 작성: 2026-10-28

## 1. 목표와 범위

### 목표

`PastOverspendConversionTests`의 두 테스트가 **실행한 날짜에 따라** 깨진다. 실패 원인은 앱 로직이 아니라
테스트 입력이 주말 보정 전의 명목 급여일과 고정 금액을 쓰기 때문이다. 입력을 **실효 급여일(말일·주말 보정 후)과
실제 임계값 기준으로** 만들어, 어떤 날짜에 돌려도 같은 결과가 나오게 한다.

### 범위

| 포함 | 제외 |
|---|---|
| `GagaeSsiTests/PastOverspendConversionTests.swift`의 헬퍼와 두 테스트 수정 | `CoreDataManager`·`DailyBudgetCalculator`·`DebtRepaymentPlan` 등 앱 코드 |
| 같은 파일의 `safePayday` 전제를 실효 급여일 기준으로 단정 | 임계값 비교(`>=`)·주말 보정 규칙 변경 |
| 고정 날짜로 주말·월말 경계를 훑는 회귀 테스트 추가 | 다른 테스트 파일의 날짜 의존성 전수 점검 (§6 후속 과제) |

계산 규칙 문서(`docs/2026-07-08-daily-budget-calculation-rules.md`)의 임계값(기본 예산 × 10%, 89행)과
주말 보정(3-1)은 그대로다. 문서와 구현은 어긋나지 않으며, 테스트가 문서의 규칙을 잘못 가정하고 있었다.

## 2. 실패 분석 (2026-10-11 실행, xcresult 기준)

2026-10-11은 **일요일**이다. 따라서 day(0)=10/11(일), day(-1)=10/10(토), day(-2)=10/9(금)이다.

### 2-1. `test_여러_날_소급_입력이_각각_전환된다`

| 항목 | 값 |
|---|---|
| 입력 | 월급 3,000,000 / 고정비 0 / `payday = safePayday` = ((11+13−1) % 28)+1 = **24** |
| | day(-4)에 +30,000, day(-3)에 +20,000, day(-2)에 **+10,000** 초과 |
| 기대값 | `remainingDebt() == 60,000` |
| 실제값 | **50,000** (세 번째 10,000이 전환되지 않음) |

**원인**
1. 10/24가 토요일이라 실효 급여일이 **10/23(금)**으로 당겨진다. 이번 급여 기간은 9/24(목) ~ 10/23 = **29일**이다.
2. 기본 일일 예산 = 3,000,000 ÷ 29 = 103,448원, 임계값 = 103,448 × 10% = **10,344원**.
3. 소급 전환 경로(`convertOverspendIfEligible`)는 `amount >= threshold`일 때만 전환한다. 10,000 < 10,344라
   전환하지 않고 음수 이월로 남긴다. **규칙대로 동작한 것이다.**
4. 일반화: 급여 기간이 **30일 미만**이면(2월, 끝 급여일만 주말로 당겨진 달 등) 임계값이 10,000을 넘어
   매번 실패한다. 30일 이상이면 통과한다. 오늘(10/28)은 safePayday 13 → 10/13(화) ~ 11/13(금) 31일,
   임계값 9,677원이라 **통과한다** — 다시 돌려 통과했다고 해결로 보면 안 되는 이유다.

### 2-2. `test_이전_급여_기간의_초과는_전환하지_않는다`

| 항목 | 값 |
|---|---|
| 입력 | `payday` = day(-1)의 일자 = **10** / day(-3)(10/8)에 +40,000 초과 → 전환일 day(-2) = 10/9 |
| 기대값 | `fetchActiveDebt() == nil` (전환일이 이전 기간이라 전환 안 함) |
| 실제값 | **부채 40,000 생성** |

**원인**
1. 테스트는 "명목 급여일 = 어제 → 어제가 기간 시작일"이라고 가정했다.
2. 10/10은 토요일이라 실효 급여일이 **10/9(금)**로 당겨진다. 현재 기간 시작일 `periodStart` = 10/9.
3. 전환일 10/9는 `day < periodStart`가 아니므로 현재 기간으로 판정돼 정상적으로 부채가 된다.
   **앱은 규칙대로 동작했다.**
4. 일반화: 어제가 **토요일(실행일 일요일)** 이면 시작일이 day(-2), **일요일(실행일 월요일)** 이면 day(-3)이 되어
   전환일 day(-2)가 현재 기간에 들어간다. 일주일 중 이틀은 실패한다.

### 2-3. 공통 원인

두 실패 모두 **"명목 급여일 = 실제 기간 경계"**라는 가정에서 나왔다. 895fc31(`DebtRepaymentTests`
흡수 테스트)과 같은 계열이다. 895fc31은 기간 길이가 비교에 끼어들지 않게 **변수를 상쇄**하는 방식으로 고쳤다.
이번에도 같은 원칙(실행 날짜가 바꾸는 값을 단정에 섞지 않는다)으로 고친다.

## 3. 접근 선택

| 안 | 내용 | 판단 |
|---|---|---|
| A. 기준 날짜 고정 | 테스트가 "오늘"을 주입 | **CoreData 경로에는 불가.** `recalculateCarryOverChain`이 내부에서 `Date()`로 `today`·`periodStart`를 정한다 (`CoreDataManager.swift:1118`, `1123`). 주입하려면 앱 코드를 바꿔야 하므로 이번 결정 범위 밖이다. 순수 계산 함수를 검증하는 **경계 회귀 테스트에만** 쓴다. |
| B. 실효 급여일·실제 임계값 기준 입력 | 입력을 앱과 같은 계산기로 도출 | **채택.** 앱 코드를 건드리지 않고, 테스트가 "규칙상 경계"를 정확히 겨눈다. |
| C. 금액만 크게(예: 15,000) | 최대 임계값(26일 기간 11,538원)보다 크게 | 통과는 하지만 월급·임계 비율을 바꾸면 다시 깨진다. 기각. |

## 4. 바꿀 파일과 구성 요소

변경 파일은 **`GagaeSsiTests/PastOverspendConversionTests.swift` 하나**다.

### 4-1. 날짜 계산을 순수 함수로 분리 — `PastOverspendFixture`

같은 파일 안에 테스트 전용 `enum PastOverspendFixture`를 두고, 지금 인스턴스 헬퍼에 흩어진 날짜 계산을
**`today`를 인자로 받는 정적 함수**로 옮긴다. CoreData 테스트는 `Date()`를, 경계 회귀 테스트는 고정 날짜를 넘긴다.
같은 함수를 양쪽이 쓰므로, 회귀 테스트가 실제 테스트 입력을 그대로 검증한다.

```swift
/// 실행 날짜와 무관하게 같은 경계를 겨누도록 테스트 입력을 만든다.
/// 앱과 같은 `DailyBudgetCalculator`로 실효 급여일을 구해, 명목 급여일을 경계로 가정하지 않는다.
enum PastOverspendFixture {
    static func day(_ offset: Int, from today: Date) -> Date

    /// 테스트 구간(day(-5) ~ day(0))에 실효 급여일이 걸리지 않는 명목 급여일 (기존 공식 유지)
    static func safePayday(today: Date) -> Int

    /// '이전 급여 기간' 테스트 입력.
    /// 명목 급여일을 어제로 잡되, **경계는 주말 보정 후 실제 기간 시작일**로 읽는다.
    /// - payday: day(-1)의 일자
    /// - periodStart: payPeriod(payday:containing: day(0)).start  (day(-1)~day(-3) 중 하나)
    /// - spendDay: periodStart − 2일 (≥ day(-5), 시드 범위 안)
    /// - transferDay: periodStart − 1일 (전환일, 항상 이전 기간)
    static func previousPeriodCase(today: Date) -> (payday: Int, periodStart: Date,
                                                     spendDay: Date, transferDay: Date)
}
```

### 4-2. 기존 헬퍼

| 헬퍼 | 변경 |
|---|---|
| `day(_:)` | `PastOverspendFixture.day(_:from: Date())` 위임 |
| `safePayday` | `PastOverspendFixture.safePayday(today:)` 위임. 주석을 "주말 보정으로 최대 2일 당겨져도 구간과 겹치지 않는다"로 고친다 |
| `setup(debtPlanEnabled:)` | **전제 단정 추가** — `payPeriod(payday: safePayday, containing: day(-5)).start == payPeriod(…, containing: day(0)).start`. 깨지면 엉뚱한 금액 불일치 대신 "테스트 구간에 급여일이 걸렸다"로 실패한다 |
| 신규 `minimumConvertible(transferDay:)` | `DebtRepaymentPlan.threshold(dailyBudget: 전환일 availableAmount)`. 전환 임계값을 **전환일(적자가 넘어가는 날) 기본 예산**으로 계산한다 — 앱(`convertOverspendIfEligible`)과 같은 기준 |

`test_임계값_미만_초과는_전환하지_않는다`도 이미 같은 계산을 직접 하고 있으므로 `minimumConvertible`로 바꿔
두 테스트가 한 기준을 공유하게 한다 (동작 변화 없음).

### 4-3. `test_여러_날_소급_입력이_각각_전환된다`

```swift
setup(); seedDays()
// 세 번째는 '작게 넘겼지만 임계값 이상' — 기간 길이에 따라 임계값이 1만 원을 넘을 수 있다
let third = max(10_000, minimumConvertible(transferDay: day(-1)))
addSpend(allowance(day(-4)) + 30_000, on: day(-4))
addSpend(allowance(day(-3)) + 20_000, on: day(-3))
addSpend(allowance(day(-2)) + third,  on: day(-2))
XCTAssertEqual(remainingDebt(), 50_000 + third)
```

- 30,000·20,000은 임계값 최대치(26일 기간 11,538원)보다 커서 그대로 둔다.
- `third`는 첫 소비를 넣기 **전에** 구한다 (전환 뒤 값이 바뀌지 않음을 기대하지 않도록).
- 테스트 의도("날마다 각각 전환되고 합이 맞는다")는 그대로다.

### 4-4. `test_이전_급여_기간의_초과는_전환하지_않는다`

```swift
let c = PastOverspendFixture.previousPeriodCase(today: Date())
createBudgetConfig(payday: c.payday, …)
seedDays()
// 전제: 전환일이 실제(주말 보정 후) 기간 시작일보다 앞선다
XCTAssertLessThan(c.transferDay, c.periodStart)
addSpend(allowance(c.spendDay) + 40_000, on: c.spendDay)
XCTAssertNil(sut.fetchActiveDebt(), "이미 정산된 기간은 다시 빚으로 만들지 않는다")
```

- 10/11(일) 실행 시: periodStart 10/9, spendDay 10/7, transferDay 10/8 → 이전 기간, 통과.
- 평일 실행 시: periodStart = day(-1), spendDay = day(-3) — **기존 입력과 동일**하다.

## 5. 데이터·화면 흐름

화면·데이터 흐름 변화 없음. 테스트가 타는 경로는 그대로다.

```
addSpend → createSpendingRecord → recalculateCarryOverChain(from:)
   → (today = Date(), periodStart = currentPeriodStart)
   → 전환일마다 convertibleOverspend → convertOverspendIfEligible
        ├ day < periodStart        → 전환 안 함   (4-4가 겨누는 분기)
        └ amount >= threshold(base) → 부채 전환   (4-3이 겨누는 분기)
```

## 6. 테스트 계획

### 6-1. 수정 테스트 (CoreData, 실행일 기준)

1. `test_여러_날_소급_입력이_각각_전환된다` — §4-3
2. `test_이전_급여_기간의_초과는_전환하지_않는다` — §4-4
3. `test_임계값_미만_초과는_전환하지_않는다` — `minimumConvertible`로 교체만 (기대값 동일)

### 6-2. 신규 경계 회귀 테스트 (순수 계산, 고정 날짜)

같은 파일에 `PastOverspendFixtureBoundaryTests`(XCTestCase)를 추가한다. CoreData를 쓰지 않고
`PastOverspendFixture`와 `DailyBudgetCalculator`만 호출한다.

**(a) 2026-10-11 재현 테스트** — 옛 입력이 실패했던 이유를 숫자로 박제한다.
- safePayday 24 → 기간 9/24 ~ 10/23, 29일, day(-1)의 임계값 10,344 > 10,000 (옛 고정값 부족)
- 명목 급여일 10 → 실효 시작일 10/9 = day(-2) ≠ day(-1) (옛 가정 붕괴)
- 새 입력: `previousPeriodCase`의 transferDay 10/8 < periodStart 10/9

**(b) 이름 붙인 경계 사례** — 각 날짜에서 §(c) 불변식을 단정한다.

| 실행일 | 경계 |
|---|---|
| 2026-10-11 (일) | 어제 토요일 → 시작일 day(-2) (이번 실패일) |
| 2026-10-12 (월) | 어제 일요일 → 시작일 day(-3) |
| 2026-11-02 (월) | 어제 11/1(일) → 시작일 10/30(금), **달을 거슬러** 당겨짐 |
| 2026-03-01 (일) | 어제 2/28(토), 2월 말일 + 주말 |
| 2026-08-01 (토) | 어제 7/31(금), 31일 말일·주말 보정 없음 |

**(c) 2년 전수 스윕** — 2026-01-01 ~ 2027-12-31의 매일을 `today`로 넣어 아래를 모두 단정한다.
순수 계산 730회라 수 밀리초 수준이다. 실패 메시지에 날짜를 넣어 어느 날 깨졌는지 바로 보이게 한다.
- `previousPeriodCase`: periodStart ∈ [day(-3), day(-1)], spendDay ≥ day(-5), transferDay < periodStart,
  periodStart == `payPeriod(payday:, containing: day(0)).start`
- `safePayday`: day(-5) ~ day(0)이 모두 같은 급여 기간에 속한다 (실효 급여일 기준)
- 임계값 범위: day(-3) ~ day(-1)의 `threshold(3,000,000 ÷ 기간 일수)` < 20,000
  (4-3에서 30,000·20,000을 고정값으로 남겨도 되는 근거)

### 6-3. 확인 방법

- 전체 `GagaeSsiTests` 실행 (CLAUDE.md의 `iPhone 17,OS=26.0` destination).
- 앱 코드 diff가 비어 있는지 확인한다 (`git diff --stat`에 `GagaeSsi/` 경로가 없어야 함).
- 시뮬레이터 날짜를 바꿔 CoreData 테스트를 돌리는 수동 확인은 하지 않는다 — 6-2가 같은 입력 함수를
  고정 날짜로 검증하므로 대체된다.

## 7. 위험과 대안

| 위험 | 대응 |
|---|---|
| 스윕 테스트가 앱과 같은 `DailyBudgetCalculator`를 쓰므로, 계산기 자체의 버그는 잡지 못한다 | 이 테스트의 목적은 **테스트 입력의 날짜 독립성** 검증이다. 계산기 정합성은 기존 `DailyBudgetCalculator` 테스트 몫이며, 경계 사례 표(6-2 b)에 기대 날짜를 하드코딩해 최소한의 독립 검증을 겸한다 |
| CoreData 테스트는 여전히 `Date()`에 묶여 있다. 자정을 넘기며 돌면 day(0)이 바뀔 수 있다 | 기존과 같은 수준의 위험이며 이번 실패와 무관하다. 근본 해결(오늘 주입)은 앱 코드 변경이 필요해 별도 이슈로 남긴다 |
| 같은 "명목 급여일 = 경계" 가정이 다른 테스트 파일에도 남아 있을 수 있다 (`DebtRepaymentTests`의 `todayDom` 등) | 이번 범위는 이 파일로 한정한다. 구현 단계에서 `cal.component(.day, from:` 사용처를 훑어 목록만 이슈에 코멘트로 남기고, 수정은 후속 이슈로 분리한다 |

### 기각한 대안

- **임계값 비교를 `>`→`>=` 이외로 바꾸거나 주말 보정을 테스트에서 끄기**: 문서에 정해진 동작을 테스트에 맞춰
  바꾸는 것이라 기각 (Zero 결정: 앱 구현 불변).
- **어제가 주말이면 `XCTSkip`**: 일주일에 이틀 커버리지가 사라진다. 실효 시작일 기준 입력으로 매일 검증할 수 있으므로 기각.
