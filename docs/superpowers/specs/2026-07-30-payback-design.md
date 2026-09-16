# 페이백/포인트 환급 처리 설계

- **작성일**: 2026-07-30
- **상태**: 구현 진행
- **관련 노션**: [가계씨 (GagaeSsi) — 하루 예산 관리 앱](https://app.notion.com/p/359e5d4a0bac80e6b9bec68a15a22d72)
- **관련 코드**: `Models/BudgetModels.swift`, `Core/CoreDataManager.swift`, `Features/Spend/`, `Features/Stats/`

---

## 1. 배경·목적

지하철 정기권처럼 **실지출은 크지만 나중에 페이백/포인트로 일부를 돌려받는** 소비가 있다(예: 21만 지출, 16만 환급). 처음부터 상계하면 미수령 리스크가 있고, 무시하면 실제 절감이 안 보인다. **지출은 전액으로 기록**하고, **환급은 실제 받을 때 예산에 되돌려준다.**

## 2. 확정된 설계 결정

| 결정 | 선택 |
|---|---|
| 예산 반영 | 지출은 **전액(gross)** 차감, **환급 받을 때** 그 금액을 오늘 예산에 **+크레딧** |
| 통계 | 실지출 + **순 지출**(실지출 − 환급 예정) 보조 표시 |
| 입력 위치 | 소비 기록의 **환급 예정 필드**(토글, 기본 꺼짐) |

## 3. 모델

- `SpendingRecord`에 추가: `expectedPayback: Int`(기본 0), `paybackReceived: Bool`(기본 false).
- `SpendingRecordModel`에 반영. `netAmount = amount − expectedPayback`.

## 4. 예산·통계

- 지출 `amount`는 그날 예산에서 전액 차감(기존 동일).
- **환급 받음** `CoreDataManager.receivePayback(recordId:)`:
  1. 기록 `paybackReceived = true`
  2. 오늘 `DailyBudget`에 `CarryOverSource(+expectedPayback)` 추가(돈이 오늘 돌아옴, 위시 환급·이월금 꺼내기와 동일 패턴)
  - 소비 기록이 아니므로 소비 통계 왜곡 없음. 시간 경과 순 예산 영향 = −순액.
- 통계: 월 `netSpendingTotal = Σamount − ΣexpectedPayback`, `expectedPaybackTotal = ΣexpectedPayback`.

## 5. UI

- **소비 입력**(`SpendView`): "환급·페이백 예정" 토글 → 금액 입력(기본 꺼짐).
- **오늘 소비 목록** 행: 환급 예정 뱃지 + "환급 받음" 버튼(미수령) / "환급 완료"(수령).
- **통계 월 요약**: 실지출 아래 **순 지출** + "환급 예정 ₩X" 보조 표시.

## 6. 데이터

`expectedPayback`(Integer 32), `paybackReceived`(Boolean) 추가. lightweight migration, 기본 0/false. 기존 기록 무영향.

## 7. 테스트

- 순 지출/환급 예정 집계(순수 또는 인메모리)
- `receivePayback`: received 표시 + 오늘 예산 크레딧, 재수령 방지
- 편집 시 환급 필드 보존

## 8. 엣지 케이스

| 케이스 | 처리 |
|---|---|
| 환급 예정 0 | 뱃지·버튼 없음 |
| 이미 수령 | "환급 완료", 재크레딧 방지 |
| 환급 예정 > 실지출 | 허용(막지 않음), 순 지출 음수 가능 |
| 기록 삭제 | 이미 준 크레딧(이월)은 회수 안 함 |

## 9. 범위 제외 (v-next)

- 부분 환급(여러 번 나눠 받기)
- 환급 예정 알림, 카드사별 자동 페이백 규칙
