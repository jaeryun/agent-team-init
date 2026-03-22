#!/usr/bin/env bash
# agent-team-init: 스킬 업그레이드 (최신 버전으로 덮어쓰기)
# 사용법: bash upgrade.sh
#
# git pull 후 설치된 스킬을 묻지 않고 전부 교체합니다.

set -e

SKILLS=(init-team init-sp-for-team call-team)
SKILLS_DIR="${HOME}/.claude/skills"

if [ -z "${BASH_SOURCE[0]}" ]; then
  echo "❌ curl | bash 방식으로 실행할 수 없습니다."
  echo ""
  echo "아래 방식으로 업그레이드하세요:"
  echo "  cd agent-team-init && git pull && bash upgrade.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔄 agent-team-init 스킬 업그레이드"
echo "   소스:    $REPO_DIR"
echo "   설치 경로: $SKILLS_DIR"
echo ""

# 1. git pull (로컬 변경 없을 때만)
if git -C "$REPO_DIR" diff --quiet 2>/dev/null; then
  echo "📡 최신 버전 확인 중..."
  git -C "$REPO_DIR" pull --ff-only 2>&1 | sed 's/^/   /'
  echo ""
else
  echo "   ⚠️  로컬 변경사항이 있어 git pull을 건너뜁니다."
  echo "      현재 체크아웃된 버전으로 업그레이드합니다."
  echo ""
fi

mkdir -p "$SKILLS_DIR"

upgraded=0
added=0

for skill in "${SKILLS[@]}"; do
  src="$REPO_DIR/skills/$skill"
  dst="$SKILLS_DIR/$skill"

  if [ ! -d "$src" ]; then
    echo "   ⚠️  소스 없음: $src (건너뜀)"
    continue
  fi

  if [ -d "$dst" ]; then
    rm -rf "$dst"
    cp -r "$src" "$dst"
    echo "   🔄 업그레이드됨: $skill"
    ((upgraded++)) || true
  else
    cp -r "$src" "$dst"
    echo "   ✅ 신규 설치됨: $skill"
    ((added++)) || true
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 업그레이드 완료  (업데이트: ${upgraded}개 / 신규: ${added}개)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  Claude Code를 재시작하거나 /hooks 를 실행해 설정을 리로드하세요."
