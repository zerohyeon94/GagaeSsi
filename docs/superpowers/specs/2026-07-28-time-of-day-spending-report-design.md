# 결제 시간대 리포트 설계 (v1.1 후보)

- **작성일**: 2026-07-28
- **상태**: 설계 확정 (구현 진행)
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)
- **관련 코드**: `Features/Spend/SpendViewModel.swift`, `Core/CoreDataManager.swift`, `Features/Stats/StatsViewModel.swift`, `Features/Stats/StatsView.swift`

---

## 1. 배경·목적

"하루 중 몇 시쯤 결제를 많이 하는지"를 보여주면 소비 패턴 인식에 도움이 된다. 그러나 현재 소비 기록은 저장 시 `startOfDay`로 **시간을 버려서** 시간대 분석이 불가능하다. 실제 타임스탬프를 보존하고, 통계에 시간대 리포트를 추가한다.

## 2. 확정된 설계 결정

| 결정 사항 | 선택 |
|---|---|
| 시각 기록 방식 | **자동 기록** (입력 시각). 별도 시간 선택 UI 없음 |
| 리포트 단위 | **4구간 친근형** (오전/점심/저녁/심야) + 피크 콜아웃 |
| 기존 기록 | 시간=정확히 00:00:00은 "시간 정보 없음"으로 제외 |

## 3. 핵심 규칙

### 3-1. 타임스탬프 저장 (시간 유실 지점 3곳)

- `SpendViewModel.saveSpending`: `model.date = startOfDay(tempDate)` → `model.date = tempDate`
  - SpendView의 DatePicker가 `displayedComponents: .date`라 `tempDate`는 시간 성분을 보존한다. 생성 시 기본값 `Date()`(현재 시각), 편집 시 원래 기록 시각이 유지된다.
- `CoreDataManager.updateSpendingRecord`: DailyBudget 연결(일 예산 귀속)은 `startOfDay(model.date)`로 유지하되, `spendingRecord.date`에는 **전체 타임스탬프**를 저장한다 (현재는 startOfDay로 덮어씀).
- `createSpendingRecord`·`fetchSpendingRecords`는 무변경: 전자는 `fetchDailyBudgetEntity`가 내부적으로 startOfDay로 일 예산을 찾고, 후자는 `date >= 자정 AND date < 익일` 범위 쿼리라 타임스탬프가 있어도 일자 조회가 정확하다.

### 3-2. 시간대 버킷 `TimeSlot.from(date:)`

| 버킷 | 시간 범위 |
|---|---|
| 🌅 오전 | 06:00 – 11:59 |
| ☀️ 점심 | 12:00 – 16:59 |
| 🌆 저녁 | 17:00 – 20:59 |
| 🌙 심야 | 21:00 – 05:59 |

- 시각이 **정확히 00:00:00**이면 `nil` 반환 → "시간 정보 없음"으로 집계 제외 (기존 startOfDay 기록 걸러냄).
- 실제 00:00~05:59 소비는 정상적으로 심야에 집계된다 (정확히 00:00:00만 예외).

### 3-3. 집계 `TimeSlot.totals(from:)`

- 월별 소비 기록에서 시간 정보가 있는 것만 버킷별 합산 → 4개 버킷 항목(0원 포함) + 비율 + `timedCount`(집계에 포함된 건수) 반환.
- 순수 함수로 분리해 CoreData 없이 테스트 가능하게 한다.

## 4. 리포트 UI

- `StatsView`에 `timeSlotCard` 추가 (일별 차트 카드 아래).
- 4구간 막대(금액·비율) + **"가장 많이 쓰는 시간대: 저녁 🌆"** 피크 콜아웃.
- `timedCount == 0`이면 "아직 시간대 데이터가 쌓이지 않았어요" 빈 상태.
- 하단 캡션 "시간 정보가 있는 N건 기준".

## 5. 데이터 모델·집계

- 신규 `Models/TimeSlot.swift`: `enum TimeSlot`(라벨·이모지·범위), `struct TimeSlotTotal`(slot/amount/percentage), `static func totals(from:)`.
- `StatsViewModel`: `timeSlotTotals: [TimeSlotTotal]`, `timedRecordCount: Int`, `peakTimeSlot: TimeSlot?` 추가. `loadTimeSlotStats()`가 월별 기록으로 집계.
- CoreData 스키마 변경 없음.

## 6. 테스트

`TimeSlotTests` 신설 (순수 함수):
- `TimeSlot.from` 경계값: 05:59→심야, 06:00→오전, 11:59→오전, 12:00→점심, 16:59→점심, 17:00→저녁, 20:59→저녁, 21:00→심야, 00:30→심야
- 00:00:00 → nil (제외)
- `TimeSlot.totals`: 버킷 합산·비율, 00:00:00 기록 제외로 timedCount 감소, 빈 입력

## 7. 범위 제외 (v-next)

- 시간별 24시간 상세 바
- 요일 × 시간대 히트맵
- 명시적 시간 선택 UI
