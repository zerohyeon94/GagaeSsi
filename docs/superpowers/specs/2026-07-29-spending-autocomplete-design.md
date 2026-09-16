# 소비 항목 자동완성 설계

- **작성일**: 2026-07-29
- **상태**: 구현 진행
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72) (업데이트 로그 "자동완성 MVP" 아이디어)
- **관련 코드**: `Features/Spend/SpendView.swift`, `Features/Spend/SpendViewModel.swift`, `Core/CoreDataManager.swift`

---

## 1. 배경·목적

매번 같은 소비 항목을 다시 입력하는 번거로움을 줄이고, 동일 항목이 다르게 저장돼 통계가 흩어지는 문제를 완화한다. 기존 소비 기록을 활용해 입력 시 추천/자동완성을 제공한다. **별도 데이터 모델 없이** 기존 `SpendingRecord`에서 파생한다.

## 2. 데이터 (파생, 스키마 변경 없음)

- 고유 항목별 집계: **최근 카테고리 · 최근 금액 · 최근 사용일 · 사용 횟수**.
- 정규화: 앞뒤 공백 제거 + 연속 공백 1칸 + 대소문자 무시로 중복 제거. 같은 항목이 여러 카테고리면 **가장 최근 카테고리**.
- `SpendingSuggestion` 값 타입 + `SpendingSuggestionEngine`(순수 함수: `build`, `filter`).
- `CoreDataManager.fetchSpendingSuggestions()`.

## 3. 추천/정렬 (순수 함수 `filter`)

- **빈 쿼리**(포커스만): 최근 사용 순 상위 N(≈8).
- **글자 입력**: 항목명에 포함되는 것만 필터 → 정렬 우선순위 **① 입력 글자로 시작 ② 최근 사용 ③ 사용 횟수 ④ 가나다**.

## 4. 입력 UX

- "내용" 필드 포커스 + 추천 존재 시, 필드 **바로 아래 가로 스크롤 추천 칩**.
- 칩: `카테고리 이모지 + 항목명`, 작게 최근 금액 참고 표시.
- 칩 탭 → **항목명 + 최근 카테고리 자동 입력**. **금액은 자동 입력 안 함**(가격 변동·오입력 방지). 이후 금액 필드로 포커스 이동.
- 일치 기록 없으면 새 항목 그대로 저장(현재 동작 유지).

## 5. 영향 범위

- 신규 `Models/SpendingSuggestion.swift`(값 타입 + 엔진).
- `CoreDataManager.fetchSpendingSuggestions()`.
- `SpendViewModel`: `allSuggestions` 로드, `titleSuggestions`(현재 입력 기준 필터), `applySuggestion`.
- `SpendView`: 추천 칩 UI.

## 6. 테스트

`SpendingSuggestionTests`:
- 정규화(공백 정리·중복 제거)
- 같은 항목 여러 카테고리 → 최근 카테고리
- 빈 쿼리 최근순
- 필터: prefix 우선 → recency → frequency
- 사용 횟수 집계

## 7. 엣지 케이스

| 케이스 | 처리 |
|---|---|
| 기록 없는 신규 사용자 | 추천 영역 숨김 |
| 금액 | 절대 자동 입력 안 함(참고 표시만) |
| 편집 모드 | 동일 표시 |

## 8. 범위 제외 (v-next)

- 즐겨찾기 고정, 초성 검색, 카테고리 우선 추천, 별도 `SpendingPreset` 모델
