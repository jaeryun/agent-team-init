#!/usr/bin/env bash
set -e

SKILLS_DIR="${HOME}/.claude/skills"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 agent-team-init 스킬 설치 중..."

mkdir -p "$SKILLS_DIR"

cp -r "$REPO_DIR/skills/init-team" "$SKILLS_DIR/"
cp -r "$REPO_DIR/skills/init-sp-for-team" "$SKILLS_DIR/"

echo "✅ 설치 완료!"
echo ""
echo "사용법:"
echo "  새 프로젝트에서 /init-team 을 실행하세요."
echo "  Superpowers 워크플로우가 필요하면 이후 /init-sp-for-team 을 실행하세요."
