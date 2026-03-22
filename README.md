# agent-team-init

Claude Code 프로젝트에 에이전트 팀 워크플로우를 초기화하는 스킬 모음입니다.

## 포함된 스킬

### `/init-team`
프로젝트에 에이전트 팀 환경을 설정합니다.

- 설치된 에이전트 목록을 수집해 프로젝트에 적합한 후보 풀 추천
- 글로벌 PreToolUse 훅 설치 (팀 규칙 기계적 강제)
- team-lead 페르소나(Agents Orchestrator) 설정
- `.claude/team-config.json` (후보 풀) 생성
- `.claude/team-rules.md` (플러그인 무관 팀 행동 규칙) 생성

### `/init-sp-for-team`
`/init-team` 이후, 팀에 [Superpowers](https://github.com/obra/superpowers) 워크플로우를 연결합니다.

- 팀 후보 풀과 프로젝트 유형을 분석해 단계별 스킬 매핑 생성
- `.claude/sp-workflow.md` 생성 (git 커밋 가능, 팀 공유용)

## 생성 파일 구조

```
.claude/
  team-config.json         ← 후보 풀 + blockedExtensions (gitignore)
  team-config.example.json ← 커밋용 템플릿
  team-rules.md            ← 플러그인 무관 팀 행동 규칙 (커밋 권장)
  sp-workflow.md           ← Superpowers 단계별 스킬 매핑 (커밋 권장)
```

## 사전 요구사항

- [Claude Code](https://claude.ai/code)
- [Superpowers 플러그인](https://github.com/obra/superpowers) (`/init-sp-for-team` 사용 시)

에이전트 페르소나 파일이 적은 경우 [agency-agents](https://github.com/msitarzewski/agency-agents) 설치를 권장합니다 (선택사항).

## 설치

```bash
# 자동 설치
curl -fsSL https://raw.githubusercontent.com/jaeryun/agent-team-init/main/install.sh | bash

# 수동 설치
git clone https://github.com/jaeryun/agent-team-init
cp -r agent-team-init/skills/init-team ~/.claude/skills/
cp -r agent-team-init/skills/init-sp-for-team ~/.claude/skills/
```

## 사용법

새 프로젝트에서:

```
# 1. 에이전트 팀 초기화 (플러그인 무관)
/init-team

# 2. Superpowers 워크플로우 연결 (선택사항)
/init-sp-for-team

# 3. 프로젝트 CLAUDE.md에 추가
@.claude/team-rules.md
@.claude/sp-workflow.md
```

## 설계 철학

- **`/init-team`은 플러그인 무관**: Superpowers 없이도 동작
- **`/init-sp-for-team`은 Superpowers 종속**: sp를 쓰는 팀만 실행
- **`teamMembers`는 후보 풀**: 즉시 생성 목록이 아님. team-lead가 작업별로 동적 생성
- **프로젝트 레벨 설정**: 전역 파일 없이 프로젝트마다 독립적으로 관리
