#!/usr/bin/env bash
set -e

# curl | bash 방식으로 실행하면 BASH_SOURCE[0]이 비어 REPO_DIR이 잘못 설정됩니다.
# 반드시 git clone 후 직접 실행하세요:
#   git clone https://github.com/jaeryun/agent-team-init
#   bash agent-team-init/install.sh

SKILLS_DIR="${HOME}/.claude/skills"

# BASH_SOURCE[0]이 비어있으면 (curl|bash) 안전하게 중단
if [ -z "${BASH_SOURCE[0]}" ]; then
  echo "❌ 이 스크립트는 curl | bash 방식으로 실행할 수 없습니다."
  echo ""
  echo "아래 방식으로 설치하세요:"
  echo "  git clone https://github.com/jaeryun/agent-team-init"
  echo "  bash agent-team-init/install.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 agent-team-init 스킬 설치 중..."

mkdir -p "$SKILLS_DIR"

# 기존 스킬 덮어쓰기 경고
for skill in init-team init-sp-for-team; do
  if [ -d "$SKILLS_DIR/$skill" ]; then
    echo "⚠️  기존 스킬 발견: $SKILLS_DIR/$skill"
    read -r -p "   덮어쓸까요? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "   건너뜀: $skill"
      continue
    fi
  fi
  cp -r "$REPO_DIR/skills/$skill" "$SKILLS_DIR/"
  echo "   ✅ 설치됨: $skill"
done

echo ""
echo "✅ 설치 완료!"
echo ""
echo "사용법:"
echo "  새 프로젝트에서 /init-team 을 실행하세요."
echo "  Superpowers 워크플로우가 필요하면 이후 /init-sp-for-team 을 실행하세요."
echo ""
echo "⚠️  Claude Code를 재시작하거나 /hooks 를 열어 설정을 리로드하세요."
