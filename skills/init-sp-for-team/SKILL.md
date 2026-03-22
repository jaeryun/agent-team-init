---
name: init-sp-for-team
description: Use when setting up Superpowers skill mappings for an agent team — /init-sp-for-team, "팀 Superpowers 워크플로우 설정", "sp-workflow 만들어줘", "팀에 스킬 매핑 설정". Requires /init-team first.
---

# init-sp-for-team: Superpowers 팀 워크플로우 초기화

`.claude/team-config.json`(후보 풀)과 프로젝트 컨텍스트를 읽어
이 팀의 개발 단계별 Superpowers 스킬 매핑을 생성한다.

생성 결과물 `.claude/sp-workflow.md`는:
- git 커밋 가능 (팀 전체 공유)
- team-lead와 팀 멤버가 각 단계에서 어떤 스킬을 써야 하는지 참조하는 레퍼런스
- `.claude/team-rules.md`(플러그인 무관 행동 규칙)와 함께 사용

> **선행 조건**: `/init-team` 실행 완료 후 사용한다.

---

## 실행 단계

### 1단계: 선행 조건 확인

#### 1-1. Superpowers 플러그인 확인

이 스킬이 생성하는 `sp-workflow.md`는 **Superpowers 플러그인에 종속**된다.
플러그인이 없으면 생성된 파일의 스킬 호출 지시가 동작하지 않는다.

```bash
jq '.enabledPlugins["superpowers@claude-plugins-official"] // false' ~/.claude/settings.json
```

- **`true`인 경우**: 조용히 계속 진행한다.
- **`false` 또는 키가 없는 경우**: AskUserQuestion으로 경고한다:

  > "⚠️ Superpowers 플러그인이 활성화되어 있지 않습니다.
  >
  > `sp-workflow.md`는 Superpowers 스킬(`brainstorming`, `writing-plans` 등)을 사용하도록
  > 설계되어 있습니다. 플러그인 없이 파일을 생성해도 스킬 호출이 동작하지 않습니다.
  >
  > 설치: [superpowers 플러그인](https://github.com/obra/superpowers)
  > ```
  > /plugin install superpowers@claude-plugins-official
  > ```
  >
  > 그래도 계속 진행할까요?
  > 1. 예 — 일단 파일만 생성 (나중에 플러그인 설치 후 사용)
  > 2. 아니오 — 중단 (플러그인 먼저 설치)"

  "아니오"를 선택하면 중단한다.

#### 1-2. team-config.json 확인

`.claude/team-config.json`이 존재하는지 확인한다:

```bash
cat .claude/team-config.json 2>/dev/null
```

- **파일이 없는 경우**: 중단하고 안내한다:
  > "`.claude/team-config.json`이 없습니다. 먼저 `/init-team`을 실행해 팀 후보 풀을 설정하세요."

- **파일이 있는 경우**: `teamMembers` 목록을 추출해 다음 단계로 진행한다.

---

### 2단계: 프로젝트 컨텍스트 분석

프로젝트 유형을 파악해 불필요한 단계를 식별한다:

```bash
ls -1 . 2>/dev/null
cat CLAUDE.md 2>/dev/null | head -30
cat package.json 2>/dev/null | head -10
ls requirements*.txt pyproject.toml 2>/dev/null
ls Dockerfile docker-compose*.yml 2>/dev/null
ls .github/workflows/ 2>/dev/null
```

파악할 항목:
- 프론트엔드 존재 여부 (package.json, *.tsx, *.vue)
- 백엔드 존재 여부 (*.py, *.go, FastAPI/Django 등)
- DB 존재 여부 (migrations/, alembic/, prisma/)
- 인프라 존재 여부 (Dockerfile, CI/CD)
- 단일 담당자 프로젝트 여부 (팀원 1명이면 병렬 배분 단계 불필요)

---

### 3단계: 역할-단계 매핑 초안 생성

`teamMembers` 목록과 프로젝트 분석 결과를 조합해 아래 10단계에 역할을 자동 매핑한다:

**매핑 기준:**

| 역할 키워드 | 자동 배정 단계 |
| --- | --- |
| architect, designer, planner | 1단계(설계), 2단계(계획) |
| backend, api, server | 4단계(격리), 5단계(구현), 6단계(디버깅), 7단계(검증) |
| frontend, ui, client | 4단계(격리), 5단계(구현), 6단계(디버깅), 7단계(검증) |
| database, db, data | 4단계(격리), 5단계(구현) |
| devops, infra, deploy | 4단계(격리), 10단계(머지) |
| team-lead | 3단계(배분), 10단계(마무리) |

담당 역할이 없는 단계는 `team-lead`가 직접 처리하거나 서브에이전트로 위임한다.

---

### 4단계: 워크플로우 확인 및 커스터마이즈

AskUserQuestion으로 생성할 워크플로우를 보여주고 확인받는다:

```
📋 생성될 Superpowers 워크플로우:

단계  담당 역할              스킬
──────────────────────────────────────────────────
 1   [architect 계열]       brainstorming
 2   [architect 계열]       writing-plans
 3   team-lead              dispatching-parallel-agents (2개 이상 시)
 4   담당 멤버              using-git-worktrees
 5   담당 멤버              test-driven-development
 6   담당 멤버              systematic-debugging
 7   담당 멤버              verification-before-completion
 8   Code Reviewer (서브에이전트)   requesting-code-review
 9   담당 멤버              receiving-code-review
10   team-lead              finishing-a-development-branch

어떻게 할까요?
  1. 이대로 생성
  2. 일부 단계 제거 또는 담당 역할 변경
```

"2"를 선택하면 조정 사항을 입력받는다.

---

### 5단계: sp-workflow.md 생성

`.claude/sp-workflow.md`를 아래 형식으로 생성한다:

```markdown
# Superpowers 팀 워크플로우

> 이 파일은 `/init-sp-for-team` 스킬로 생성됐다.
> 플러그인 무관 팀 행동 규칙은 `~/.claude/team-rules.md`를 참조한다.

## 팀 후보 풀

[team-config.json의 teamMembers 목록]

## Superpowers 스킬 사용 원칙

`using-superpowers`는 세션 시작 시 자동 로드되는 메타 규칙이다.
어떤 스킬이 1%라도 적용될 것 같으면 반드시 먼저 호출한다.

- **팀 멤버**: 세션 시작 시 자동 적용됨
- **서브에이전트**: `using-superpowers` 스킵 — 할당된 스킬만 직접 실행

### Deprecated 커맨드 (사용 금지)

| 구 커맨드 | 대체 스킬 |
| --- | --- |
| `/brainstorm` | `superpowers:brainstorming` |
| `/write-plan` | `superpowers:writing-plans` |
| `/execute-plan` | `superpowers:executing-plans` |

## 단계별 스킬 매핑

각 에이전트 프롬프트에 반드시 해당 단계의 스킬 호출 지시를 포함할 것.
에이전트 간 공유 파일 동시 수정 금지.

### 🔵 스펙 확정 전 (Pre-spec) — 대화·설계 단계

> team-lead는 사람과 대화하며 요구사항을 수집한다. 설계·브레인스토밍은 architect에게 위임.
> 이 단계에서 구현 팀 멤버 생성 금지.

| # | 단계 | 담당 역할 | 스킬 | 산출물 |
| --- | --- | --- | --- | --- |
| 1 | 요구사항 정의 및 설계 | [architect 계열] | `brainstorming` | 스펙·설계 문서 |
| 2 | 계획 수립 및 태스크 분해 | [architect 계열] | `writing-plans` | 플랜·태스크 목록 |

### 🟢 스펙 확정 후 (Post-spec) — 구현 단계

> team-lead는 자율 파이프라인 관리자로 전환. 모든 구현 작업을 담당 멤버에게 위임.
> 설계·구현·테스트 직접 수행 금지.

| # | 단계 | 담당 역할 | 스킬 | 산출물 |
| --- | --- | --- | --- | --- |
| 3 | 태스크 배분 | team-lead | `dispatching-parallel-agents` (2개 이상 시) | 멤버별 태스크 할당 |
| 4 | 워크스페이스 격리 | 담당 멤버 | `using-git-worktrees` | 격리된 브랜치 |
| 5 | 구현 | 담당 멤버 | `test-driven-development` | 코드 + 테스트 |
| 6 | 디버깅 | 담당 멤버 | `systematic-debugging` | 수정된 코드 |
| 7 | 완료 검증 | 담당 멤버 | `verification-before-completion` | 검증 결과 |
| 8 | 코드 리뷰 | Code Reviewer (서브에이전트) | `requesting-code-review` | 리뷰 피드백 |
| 9 | 피드백 반영 | 담당 멤버 | `receiving-code-review` | 수정된 코드 |
| 10 | 브랜치 마무리 | team-lead | `finishing-a-development-branch` | PR / 머지 |

## 완료 기준

team-lead는 아래가 모두 충족될 때만 태스크 완료로 간주한다:

1. 모든 테스트 통과
2. 담당 멤버의 `verification-before-completion` 실행 완료
3. `Code Reviewer` 서브에이전트 `requesting-code-review` 리뷰 통과
4. `finishing-a-development-branch`로 통합 방식 결정 및 실행
```

---

### 6단계: 유저 레벨 CLAUDE.md에 sp-workflow 로드 지침 추가

`~/.claude/CLAUDE.md`에 프로젝트 레벨 `sp-workflow.md` 자동 로드 지침이 있는지 확인한다:

```bash
grep -q "sp-workflow.md" ~/.claude/CLAUDE.md 2>/dev/null && echo "이미 있음" || echo "없음"
```

**없는 경우** `~/.claude/CLAUDE.md` 끝에 추가한다:

```markdown
## 프로젝트 워크플로우 자동 로드

세션 시작 시, 현재 프로젝트 디렉터리에 `.claude/sp-workflow.md` 파일이 존재하면 반드시 읽고 적용한다.
```

> `sp-workflow.md`는 프로젝트마다 경로가 다르므로 `@` import로 전역 로드할 수 없다.
> 텍스트 지침으로 등록해 AI가 세션 중 Read 툴로 직접 읽도록 유도한다.

---

### 7단계: .gitignore 업데이트

프로젝트 루트의 `.gitignore`에 없으면 추가한다:

```
.claude/sp-workflow.md
```

---

### 8단계: 완료 메시지

```
✅ Superpowers 워크플로우 설정 완료!

생성된 파일:
  .claude/sp-workflow.md  ← 단계별 스킬 매핑 (로컬 전용, gitignore됨)
  ~/.claude/CLAUDE.md     ← sp-workflow 자동 로드 지침 추가됨

다음 단계:
  1. ⚠️  Claude Code를 재시작하거나 /hooks 를 실행해 설정을 리로드하세요.
  2. 재시작 후 자연어로 작업을 요청하세요.
     team-lead가 sp-workflow.md의 단계별 스킬을 참조해 진행합니다.
```

---

## 주의사항

- `team-config.json`이 없으면 실행 불가 — `/init-team` 선행 필수
- `sp-workflow.md`는 Superpowers 플러그인 종속 파일이다
- 플러그인 무관 팀 규칙은 `team-rules.md`가 담당한다 (이 스킬은 건드리지 않음)
- 다른 워크플로우 도구를 쓴다면 `/init-[도구명]-for-team` 스킬을 별도로 만든다
