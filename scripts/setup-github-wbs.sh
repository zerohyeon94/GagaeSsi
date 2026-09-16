#!/usr/bin/env bash
# 가계씨 WBS 보드 셋업 — GitHub Projects(v2)
#
# 사전 조건: gh auth refresh -s project,read:project
# 사용법:    ./scripts/setup-github-wbs.sh
#
# 하는 일: 프로젝트 생성 → Status 6단계로 교체 → 커스텀 필드 5개 추가 → 열린 이슈 등록
# 재실행 시 같은 이름의 프로젝트가 또 만들어지므로 한 번만 실행한다.

set -euo pipefail

OWNER="zerohyeon94"
REPO="zerohyeon94/GagaeSsi"
TITLE="가계씨 WBS"

echo "▸ 스코프 확인"
gh project list --owner "$OWNER" >/dev/null 2>&1 || {
  echo "  ✗ project 스코프 없음. 먼저 실행하세요: gh auth refresh -s project,read:project" >&2
  exit 1
}

echo "▸ 프로젝트 생성: $TITLE"
CREATED=$(gh project create --owner "$OWNER" --title "$TITLE" --format json)
NUM=$(echo "$CREATED" | jq -r '.number')
PID=$(echo "$CREATED" | jq -r '.id')
echo "  프로젝트 #$NUM ($PID)"

echo "▸ 기본 Status 필드를 6단계로 교체"
SFID=$(gh project field-list "$NUM" --owner "$OWNER" --format json \
  | jq -r '.fields[] | select(.name=="Status") | .id')

if [ -n "$SFID" ] && [ "$SFID" != "null" ]; then
  gh api graphql -f query='
    mutation($fieldId:ID!, $opts:[ProjectV2SingleSelectFieldOptionInput!]) {
      updateProjectV2Field(input:{fieldId:$fieldId, singleSelectOptions:$opts}) {
        projectV2Field { ... on ProjectV2SingleSelectField { name options { name } } }
      }
    }' \
    -f fieldId="$SFID" \
    -F opts='[
      {"name":"📋 백로그","color":"GRAY","description":"아직 하기로 정하지 않음"},
      {"name":"🔜 예정","color":"BLUE","description":"이번 릴리즈에 하기로 정함"},
      {"name":"🚧 진행중","color":"YELLOW","description":"작업 브랜치에서 커밋 중"},
      {"name":"⏸️ 보류","color":"ORANGE","description":"멈춤. Blocked reason 필수"},
      {"name":"👀 리뷰중","color":"PURPLE","description":"PR 머지 대기"},
      {"name":"✅ 완료","color":"GREEN","description":"main에 머지됨"}
    ]' --jq '.data.updateProjectV2Field.projectV2Field.options[].name' | sed 's/^/  /'
else
  echo "  ! Status 필드를 찾지 못함 — 웹 UI에서 직접 설정 필요"
fi

echo "▸ 커스텀 필드 추가"
add_field() {
  if gh project field-create "$NUM" --owner "$OWNER" "$@" >/dev/null 2>&1; then
    echo "  ✓ $2"
  else
    echo "  ! $2 실패 (이미 존재하거나 미지원)"
  fi
}
add_field --name "Epic"           --data-type SINGLE_SELECT \
          --single-select-options "v1.7 여행 정산,v1.6 위시 지갑,브랜드·디자인,알림·리텐션,기술 부채"
add_field --name "Blocked reason" --data-type TEXT
add_field --name "Estimate"       --data-type NUMBER
add_field --name "Start date"     --data-type DATE
add_field --name "Target date"    --data-type DATE

echo "▸ 열린 이슈 등록"
for n in $(gh issue list -R "$REPO" --state open --limit 100 --json number --jq '.[].number'); do
  gh project item-add "$NUM" --owner "$OWNER" --url "https://github.com/$REPO/issues/$n" >/dev/null
  echo "  ✓ #$n"
done

echo
echo "완료. 보드: https://github.com/users/$OWNER/projects/$NUM"
echo "남은 수동 작업:"
echo "  - Settings › Workflows › 'Pull request merged' → ✅ 완료 자동 이동 켜기"
echo "  - Roadmap 뷰 추가 (Start date / Target date 기준)"
echo "  - 'Status = ⏸️ 보류' 필터 Table 뷰 추가"
