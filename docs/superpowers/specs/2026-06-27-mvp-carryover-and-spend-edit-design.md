# 가계씨 MVP — 이월 자동화 & 지출 수정 설계

작성일: 2026-06-27
브랜치: develop

## 배경

가계씨는 "하루 단위 예산 관리" 앱. 빠른 출시를 위해 MVP 범위를 2개 기능으로 확정:
1. 이월(carry-over) 자동화 — 핵심 컨셉이나 미구현 (`createCarryOverSource()`가 호출되지 않음)
2. 지출 수정 — 현재 추가/삭제만 가능

제외(추후 업데이트): 데이터 백업, 피드백, 푸시 알림.

## 기능 1: 이월(Carry-over) 자동화

### 결정된 동작 규칙
- **마이너스도 이월**: 어제 예산보다 더 썼으면 음수 이월금으로 오늘 예산에서 차감.
- **전부 소급 이월**: 며칠 만에 열어도 마지막 기록일~오늘까지 모든 날을 순회해 이월 누적.
- **급여일 리셋 없음**: 새 급여 기간이 시작돼도 이월 잔액 유지.

### 핵심 원리
하루의 남은 돈 = `availableAmount(기본예산) + Σ carryOverSources − Σ spendingRecords`
= 기존 `DailyBudgetModel.todayAvailable`. 이 값이 다음 날 이월금으로 흐름 (음수 가능).

### 신규 메서드: `CoreDataManager.processDailyBudgets(upTo date: Date)`
1. `fetchBudgetConfig()` 없으면 즉시 return.
2. 가장 최근 `DailyBudget` 엔티티(max date)를 찾음.
   - 없으면 return (신규 사용자 — 오늘은 `fetchOrCreateTodayDailyBudget()`가 이월 0으로 생성).
   - `latestDate >= today` 이면 이미 처리됨 → return.
3. `latestDate + 1일 ~ today`(포함) 순회. 각 날짜 `d`:
   - `base = DailyBudgetCalculator.calculate(from: config, for: d)`
   - `prevModel = fetchDailyBudgetModel(date: d-1)` → `carry = prevModel.todayAvailable` (음수 가능)
   - `DailyBudget(d)` 생성: `availableAmount = base`, `CarryOverSource(amount: carry, date: d-1, toDate: d)` 1개 첨부.
   - 새로 만든 날이 다음 순회의 "전날"이 됨.
4. **멱등성**: 이미 존재하는 날짜는 생성하지 않음 → 재실행해도 중복 이월 없음.

### 트리거
- `HomeViewModel.fetchTodayBudget()` 첫머리에서 `processDailyBudgets(upTo: today)` 호출 후 기존 로직 수행.
- `HomeView`에 `@Environment(\.scenePhase)` 추가 → `.active` 전환 시 `fetchTodayBudget()` 재호출 (백그라운드 중 자정 넘긴 경우 대비).

### 엣지 케이스
- 음수 이월: `carry < 0` → `todayAvailable` 감소. 정상.
- 급여일 횡단: 리셋 안 함, carry 그대로 흐름.
- 며칠 공백: 순회로 전부 소급. 미사용일은 지출 0이라 `base`가 통째로 이월 누적.
- 설정(월급) 변경: 과거 날짜 base도 현재 config 기준 재계산 (기존 `recalculateTodayBudget` 동작과 동일).

## 기능 2: 지출 수정

### `SpendViewModel`
- `editingRecordId: UUID?` 추가 (nil = 추가 모드).
- `isEditing: Bool { editingRecordId != nil }`.
- `beginEdit(_ record: SpendingRecordModel)`: temp 필드(title/amount/amountText/date/category)에 값 채우고 `editingRecordId` 설정.
- `cancelEdit()`: `clearForm()` + `editingRecordId = nil`.
- `saveSpending`: 편집 모드면 `model.id = editingRecordId`로 `updateSpendingRecord` 호출, 아니면 기존 `createSpendingRecord`. 저장 후 편집 상태 해제.
- `clearForm()`에 `editingRecordId = nil` 포함.

### `SpendView`
- `spendingRow`에 ✏️ 버튼 추가(휴지통 왼쪽) → `viewModel.beginEdit(record)`.
- 편집 모드일 때: 입력 카드 헤더 "지출 수정 중", 우측 취소(X) 버튼, 저장 버튼 라벨 "수정 완료".
- `beginEdit` 시 입력 폼은 화면 상단에 이미 있으므로 별도 스크롤 불필요(필요 시 ScrollViewReader로 상단 이동).

### 날짜 변경 재연결
- `CoreDataManager.updateSpendingRecord`가 날짜 변경 시 대상 날짜의 `DailyBudget`에 재연결하도록 보강.
- 헬퍼 `fetchOrCreateDailyBudget(date:)`: 해당 날짜 엔티티 있으면 반환, 없으면 `base` 예산으로 생성(이월 0).
- 통계는 `SpendingRecord.date` 기준 쿼리라 영향 없고, 홈/일별 집계 일관성 확보.

## 작업 순서
1. 기능 1 (이월 자동화) — 홈 숫자 정상화가 검증 기반.
2. 기능 2 (지출 수정).

각 기능 구현 후 빌드 확인.
