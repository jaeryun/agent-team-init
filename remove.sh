#!/usr/bin/env bash
# agent-team-init: 스킬 제거
# 사용법: bash remove.sh
#
# ~/.claude/skills/ 에서 agent-team-init 스킬을 모두 삭제합니다.
# ~/.claude/CLAUDE.md, team-rules.md, settings.json 은 건드리지 않습니다.

set -e

SKILLS=(init-team init-sp-for-team call-team)
SKILLS_DIR="${HOME}/.claude/skills"

echo "🗑️  agent-team-init 스킬 제거"
echo "   제거 경로: $SKILLS_DIR"
echo ""

# 설치된 스킬 목록 확인
installed=()
for skill in "${SKILLS[@]}"; do
  if [ -d "$SKILLS_DIR/$skill" ]; then
    installed+=("$skill")
  fi
done

if [ ${#installed[@]} -eq 0 ]; then
  echo "   설치된 스킬이 없습니다. 종료합니다."
  exit 0
fi

echo "   제거 대상:"
for skill in "${installed[@]}"; do
  echo "     - $skill"
done
echo ""

read -r -p "정말 제거하시겠습니까? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "취소됐습니다."
  exit 0
fi

echo ""
removed=0
for skill in "${installed[@]}"; do
  rm -rf "$SKILLS_DIR/$skill"
  echo "   🗑️  제거됨: $skill"
  ((removed++)) || true
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 제거 완료  (${removed}개 스킬 삭제됨)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "아래 항목은 자동으로 제거되지 않습니다 (직접 확인):"
echo "  ~/.claude/team-rules.md      — 팀 행동 규칙"
echo "  ~/.claude/CLAUDE.md          — @team-rules.md 참조 라인"
echo "  ~/.claude/settings.json      — agent 페르소나 설정"
echo "  각 프로젝트의 .claude/team-config.json  — 프로젝트 팀 설정"
echo ""
echo "⚠️  Claude Code를 재시작하거나 /hooks 를 실행해 설정을 리로드하세요."
