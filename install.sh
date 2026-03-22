#!/usr/bin/env bash
# agent-team-init: 스킬 설치
# 사용법: bash install.sh
#
# curl | bash 방식 불가 — 반드시 git clone 후 실행하세요:
#   git clone https://github.com/jaeryun/agent-team-init
#   bash agent-team-init/install.sh

set -e

SKILLS=(init-team init-sp-for-team call-team)
SKILLS_DIR="${HOME}/.claude/skills"

# curl|bash 방어
if [ -z "${BASH_SOURCE[0]}" ]; then
  echo "❌ curl | bash 방식으로 실행할 수 없습니다."
  echo ""
  echo "아래 방식으로 설치하세요:"
  echo "  git clone https://github.com/jaeryun/agent-team-init"
  echo "  bash agent-team-init/install.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 agent-team-init 스킬 설치"
echo "   설치 경로: $SKILLS_DIR"
echo ""

mkdir -p "$SKILLS_DIR"

installed=0
skipped=0

for skill in "${SKILLS[@]}"; do
  src="$REPO_DIR/skills/$skill"
  dst="$SKILLS_DIR/$skill"

  if [ ! -d "$src" ]; then
    echo "   ⚠️  소스 없음: $src (건너뜀)"
    ((skipped++)) || true
    continue
  fi

  if [ -d "$dst" ]; then
    echo "   ⚠️  이미 설치됨: $skill"
    read -r -p "      덮어쓸까요? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "      건너뜀: $skill"
      ((skipped++)) || true
      continue
    fi
    rm -rf "$dst"
  fi

  cp -r "$src" "$dst"
  echo "   ✅ 설치됨: $skill"
  ((installed++)) || true
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 설치 완료  (설치: ${installed}개 / 건너뜀: ${skipped}개)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "사용법:"
echo "  /init-team          — 프로젝트에서 팀 설정 초기화"
echo "  /init-sp-for-team   — Superpowers 워크플로우 연결 (선택사항)"
echo "  /call-team          — 팀 멤버 스폰 (스펙 확정 후)"
echo ""
echo "⚠️  Claude Code를 재시작하거나 /hooks 를 실행해 설정을 리로드하세요."
