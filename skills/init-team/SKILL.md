---
name: init-team
description: Use when initializing an agent team for a project — /init-team, "팀 설정 초기화", "에이전트 팀 구성", "team-config 만들어줘", "팀 워크플로우 설정".
---

# init-team: 프로젝트 에이전트 팀 설정 초기화

현재 프로젝트 디렉토리에 `.claude/team-config.json`을 생성해 팀 워크플로우 규칙을 활성화한다.

이 파일이 존재하면 `~/.claude/settings.json`의 글로벌 훅이 자동으로 아래 규칙을 강제한다:
- **규칙 1**: 팀 멤버 역할을 `team_name` 없이 서브에이전트로 호출 금지
- **규칙 2**: team-lead(Agents Orchestrator)가 코드 파일을 직접 Write/Edit 금지

> **`teamMembers`는 "즉시 생성 목록"이 아니다.**
> 이 프로젝트에서 사용 가능하도록 승인된 **후보 풀**이다.
> 실제 생성은 team-lead가 각 작업 시작 시 필요한 역할만 골라 사용자 허락을 받고 동적으로 수행한다.

---

## 실행 단계

### 1단계: 설치된 에이전트 목록 수집

```bash
ls ~/.claude/agents/*.md 2>/dev/null
```

에이전트 파일 수를 센다:

```bash
AGENT_COUNT=$(ls ~/.claude/agents/*.md 2>/dev/null | wc -l)
```

- **3개 이하이면**: 아래 경고를 1회 보여주고 계속 진행한다 (강제 아님):
  > "⚠️ 에이전트가 ${AGENT_COUNT}개만 설치되어 있습니다. 팀 역할 선택지가 제한될 수 있습니다.
  > [agency-agents](https://github.com/msitarzewski/agency-agents)를 설치하면
  > 더 다양한 전문 역할을 팀 멤버로 활용할 수 있습니다. (선택사항)"

- **4개 이상이면**: 메시지 없이 조용히 진행한다.

파일명 목록을 수집한다. 각 `.md` 파일의 이름(확장자 제거)이 사용 가능한 에이전트 역할명이다.

---

### 2단계: 기존 설정 확인

`.claude/team-config.json`이 이미 존재하면 현재 내용을 보여주고 물어본다:

> "team-config.json이 이미 있습니다. 어떻게 할까요?
> 1. 업데이트 (새 추천 기반으로 수정)
> 2. 덮어쓰기 (완전히 새로 설정)
> 3. 취소"

**취소를 선택하면** 즉시 중단한다. 이 이후 단계에서 변경되는 설정(훅·페르소나 등)이 없도록 여기서 조기 종료한다.

---

### 3단계: 프로젝트 설정 파일 생성

훅과 env var는 **프로젝트 레벨** `.claude/settings.local.json`에 작성한다.
글로벌 `~/.claude/settings.json`은 건드리지 않는다 — 다른 프로젝트에 영향을 주지 않기 위해서다.

#### 3-1. 기존 설정 확인

```bash
cat .claude/settings.local.json 2>/dev/null
```

- **파일이 이미 있는 경우**: 현재 내용을 보여주고 머지할지 물어본다.
- **없는 경우**: 조용히 다음으로 진행한다.

#### 3-2. `.claude/settings.local.json` 생성

AskUserQuestion으로 물어본다:

> "프로젝트 레벨 설정 파일(`.claude/settings.local.json`)에 아래를 추가할까요?
>
> - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — TeamCreate 기능 활성화
> - PreToolUse 훅 2개 — 팀 규칙 강제 (팀 멤버 잘못된 생성 차단, team-lead 직접 구현 차단)
>
> 이 파일은 이 프로젝트에서만 적용됩니다. (gitignore 권장)
>
> 1. 예 — 자동 생성 (권장)
> 2. 아니오 — 건너뛰기 (나중에 직접 설정)"

**"예"를 선택하면** `.claude/settings.local.json`을 아래 내용으로 생성(또는 머지)한다:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Agent",
        "hooks": [{
          "type": "command",
          "command": "INPUT=$(cat); TEAM_CONFIG=\".claude/team-config.json\"; [ ! -f \"$TEAM_CONFIG\" ] && exit 0; SUBAGENT_TYPE=$(echo \"$INPUT\" | jq -r '.tool_input.subagent_type // \"\"'); [ -z \"$SUBAGENT_TYPE\" ] && exit 0; TEAM_NAME=$(echo \"$INPUT\" | jq -r '.tool_input.team_name // \"\"'); IS_TEAM_MEMBER=$(jq --arg r \"$SUBAGENT_TYPE\" '[.teamMembers[] | select(. == $r)] | length > 0' \"$TEAM_CONFIG\"); if [ \"$IS_TEAM_MEMBER\" = \"true\" ] && [ -z \"$TEAM_NAME\" ]; then echo \"{\\\"continue\\\": false, \\\"stopReason\\\": \\\"⛔ 팀 멤버 규칙 위반: '$SUBAGENT_TYPE' 는 TeamCreate 후 team_name + name 포함해서 생성하세요.\\\"}\"; fi",
          "statusMessage": "팀 멤버 생성 규칙 확인 중..."
        }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "INPUT=$(cat); TEAM_CONFIG=\".claude/team-config.json\"; [ ! -f \"$TEAM_CONFIG\" ] && exit 0; FILE_PATH=$(echo \"$INPUT\" | jq -r '.tool_input.file_path // \"\"'); [ -z \"$FILE_PATH\" ] && exit 0; EXT=\".${FILE_PATH##*.}\"; BLOCKED=$(jq --arg e \"$EXT\" '[.blockedExtensions[] | select(. == $e)] | length > 0' \"$TEAM_CONFIG\"); if [ \"$BLOCKED\" = \"true\" ]; then echo \"{\\\"continue\\\": false, \\\"stopReason\\\": \\\"⛔ team-lead 직접 구현 금지: $FILE_PATH → 담당 팀 멤버에게 SendMessage로 위임하세요.\\\"}\"; fi",
          "statusMessage": "team-lead 직접 구현 여부 확인 중..."
        }]
      }
    ]
  }
}
```

생성 후 JSON 문법을 검증한다:
```bash
jq -e '.hooks.PreToolUse' .claude/settings.local.json && echo "✅ 프로젝트 설정 완료"
```

**"아니오"를 선택하면** 계속 진행하되 마지막 완료 메시지에 경고를 포함한다.

---

### 4단계: 프로젝트 컨텍스트 분석

현재 프로젝트의 성격을 파악하기 위해 아래를 확인한다:

```bash
# 프로젝트 구조 파악
ls -1 . 2>/dev/null
cat CLAUDE.md 2>/dev/null | head -50
cat package.json 2>/dev/null | head -20
ls requirements*.txt pyproject.toml setup.py 2>/dev/null
ls *.go go.mod 2>/dev/null
ls Dockerfile docker-compose*.yml 2>/dev/null
ls .github/workflows/ 2>/dev/null
```

수집한 정보로 프로젝트 유형을 파악한다:
- 프론트엔드 파일(package.json, *.tsx, *.vue)이 있는가?
- 백엔드 파일(*.py, *.go, requirements.txt, FastAPI/Django 등)이 있는가?
- DB 관련 파일(migrations/, alembic/, *.sql, prisma/)이 있는가?
- 인프라 파일(Dockerfile, docker-compose, .github/workflows/, terraform/)이 있는가?
- 보안 요구사항이 CLAUDE.md에 언급되어 있는가?

---

### 5단계: 적합한 에이전트 추천

1단계에서 수집한 **설치된 에이전트 목록**과 4단계의 **프로젝트 분석 결과**를 조합해
이 프로젝트에 적합한 에이전트를 추천한다.

추천 기준:
- 프로젝트에 실제로 필요한 역할만 추천한다 (과도한 팀 구성 지양)
- 설치되지 않은 에이전트는 추천 목록에 포함하지 않는다
- 각 추천 이유를 간략히 설명한다

AskUserQuestion으로 추천 결과를 보여주고 확인받는다:

```
📦 프로젝트 분석 결과: [프로젝트 유형 요약]

이 프로젝트의 후보 풀로 등록할 역할을 선택하세요.
(실제 팀 멤버 생성은 각 작업 시작 시 team-lead가 필요한 역할만 동적으로 수행합니다)

추천 후보 (설치된 에이전트 기반):
  ✅ Backend Architect    — FastAPI/Python 백엔드 감지됨
  ✅ Frontend Developer   — React/TypeScript 감지됨
  ✅ Database Optimizer   — Alembic 마이그레이션 감지됨
  ⬜ DevOps Automator     — Docker/CI 파일 감지됨 (선택사항)

설치되어 있으나 이 프로젝트에 불필요:
  — Security Engineer, Mobile App Builder, ...

후보 풀 구성을 어떻게 할까요?
  1. 추천대로 사용 (✅ 표시된 것만)
  2. 직접 선택 (목록에서 고르기)
  3. 전체 설치 에이전트 사용
```

---

### 6단계: team-lead 페르소나 설정

team-lead 역할을 맡을 페르소나를 설정한다.

먼저 "Agents Orchestrator" 페르소나 파일이 설치되어 있는지 확인한다:

```bash
ls ~/.claude/agents/Agents\ Orchestrator.md 2>/dev/null
```

---

#### 케이스 A: 파일이 있는 경우

AskUserQuestion으로 물어본다:

> "team-lead 페르소나를 'Agents Orchestrator'로 설정할까요?
>
> 설정하면 `~/.claude/settings.json`의 `\"agent\"` 값이 자동으로 변경됩니다.
> 이 페르소나는 파이프라인 조율·태스크 배분·최종 승인에 특화되어 있습니다.
>
> 1. 예 — Agents Orchestrator로 설정
> 2. 아니오 — 현재 설정 유지 (페르소나 변경 없음)"

---

#### 케이스 B: 파일이 없는 경우

AskUserQuestion으로 물어본다:

> "Agents Orchestrator 페르소나 파일이 설치되어 있지 않습니다.
>
> 이 페르소나를 team-lead로 사용하려면 아래 방법 중 하나로 설치할 수 있습니다:
>
> **방법 1 — agency-agents 전체 설치** (다른 전문 역할도 함께 설치됨):
> ```bash
> git clone --depth=1 https://github.com/msitarzewski/agency-agents /tmp/agency-agents-install
> cp /tmp/agency-agents-install/agents/*.md ~/.claude/agents/
> rm -rf /tmp/agency-agents-install
> ```
>
> **방법 2 — Agents Orchestrator만 설치**:
> ```bash
> mkdir -p ~/.claude/agents
> curl -fsSL https://raw.githubusercontent.com/msitarzewski/agency-agents/main/agents/Agents%20Orchestrator.md \
>   -o ~/.claude/agents/Agents\ Orchestrator.md
> ```
>
> 어떻게 할까요?
> 1. 전체 설치 (agency-agents 모든 에이전트)
> 2. Agents Orchestrator만 설치
> 3. 설치 건너뛰기 (페르소나 변경 없음)"

선택에 따라 처리:

- **1 또는 2 선택**: 해당 설치 명령을 실행한 뒤, 설치 성공 시 "예"와 동일하게 `agent` 필드를 업데이트한다.
- **3 선택**: 페르소나 변경 없이 다음 단계로 진행한다.

---

#### 페르소나 설정 적용 (케이스 A "예" 또는 케이스 B 1·2 선택 시)

`~/.claude/settings.json`의 `agent` 필드를 확인하고 업데이트한다:

```bash
jq '.agent // "미설정"' ~/.claude/settings.json
```

- 이미 `"Agents Orchestrator"`이면 변경 없이 넘어간다.
- 다른 값이면 현재 값을 보여주고 덮어쓸지 재확인한다.

settings.json의 `agent` 필드를 수정한다:
```json
{
  "agent": "Agents Orchestrator"
}
```

완료 후 알린다:
> "✅ team-lead 페르소나: Agents Orchestrator 설정됨
>
> ℹ️ 이 페르소나는 완전 자율 파이프라인으로 설계되어 있습니다.
> `.claude/team-rules.md`를 CLAUDE.md에 추가하면 TeamCreate 방식·사용자 허락 등
> 이 프로젝트의 팀 규칙이 페르소나보다 우선 적용됩니다."

---

### 7단계: 파일 확장자 설정

AskUserQuestion으로 기본값 사용 여부를 확인한다:

```
파일 확장자 설정 (team-lead 직접 구현 차단 대상)

기본 차단: .py .ts .tsx .js .jsx .go .rs .java .cpp .c .cs
기본 허용: .md .json .yaml .yml .txt .gitignore .env.example

기본값을 사용할까요? (yes / no)
```

"no"이면 커스텀 목록을 입력받는다.

---

### 8단계: 파일 생성

#### `.claude/` 디렉토리 생성 (없는 경우)
```bash
mkdir -p .claude
```

#### `.claude/team-config.json` 생성 (최종 확정된 후보 풀로)
```json
{
  "_teamMembers_note": "후보 풀입니다. 실제 생성은 team-lead가 작업별로 사용자 허락을 받고 동적으로 수행합니다.",
  "teamMembers": ["최종 선택된 역할 후보 목록"],
  "blockedExtensions": [".py", ".ts", ".tsx", "..."],
  "allowedExtensions": [".md", ".json", ".yaml", "..."]
}
```

---

### 9단계: .gitignore 업데이트

프로젝트 루트의 `.gitignore`에 없으면 추가한다:

```
# Agent team local settings (local only)
.claude/settings.local.json
.claude/team-config.json
```

---

### 10단계: 유저 레벨 team-rules.md 생성

`~/.claude/team-rules.md`가 이미 존재하는지 확인한다:

```bash
cat ~/.claude/team-rules.md 2>/dev/null && echo "이미 있음" || echo "없음"
```

**없는 경우** `~/.claude/team-rules.md`를 생성한다 (내용은 8단계의 team-rules.md 템플릿과 동일).

**이미 있는 경우** 변경 없이 넘어간다.

---

### 11단계: 유저 레벨 CLAUDE.md에 참조 추가

`~/.claude/CLAUDE.md`에 아래 항목이 포함되어 있는지 확인한다:

```bash
grep -q "@team-rules.md" ~/.claude/CLAUDE.md 2>/dev/null && echo "team-rules: 있음" || echo "team-rules: 없음"
grep -q "@agent-workflow.md" ~/.claude/CLAUDE.md 2>/dev/null && echo "agent-workflow: 있음" || echo "agent-workflow: 없음"
```

없는 항목만 `~/.claude/CLAUDE.md` 끝에 추가한다:

```markdown
@team-rules.md

@agent-workflow.md
```

`~/.claude/CLAUDE.md`가 없는 경우 새로 생성한다.

> `team-rules.md`는 플러그인 무관 팀 행동 규칙이며, `agent-workflow.md`는 에이전트 워크플로우 지침이다.
> 두 파일 모두 `~/.claude/`(유저 레벨)에 위치하며 모든 프로젝트에서 공통으로 적용된다.
> 훅이 `team-config.json` 존재 여부를 먼저 확인하므로, 팀 설정이 없는 프로젝트에서는 자연스럽게 비활성화된다.

---

### 12단계: 완료 메시지

```
✅ 팀 설정 완료!

생성된 파일:
  ~/.claude/team-rules.md      ← 팀 행동 규칙 (유저 레벨, 모든 프로젝트 공통)
  ~/.claude/CLAUDE.md          ← @team-rules.md, @agent-workflow.md 참조 추가됨
  .claude/settings.local.json  ← 훅 + env var (로컬 전용, gitignore됨)
  .claude/team-config.json     ← 팀 후보 풀 (로컬 전용, gitignore됨)

활성화된 팀 후보 풀:
  - [선택된 역할들]

차단된 파일 확장자: [목록]

다음 단계:
  1. Superpowers 워크플로우 연결 (선택사항):
     /init-sp-for-team
  2. ⚠️  Claude Code를 재시작하거나 /hooks 를 실행해 훅을 리로드하세요.
     (재시작 전까지 훅이 적용되지 않습니다)
  3. 재시작 후 자연어로 작업을 요청하세요.
     team-lead가 필요한 팀 멤버를 동적으로 구성합니다.
```

---

## 주의사항

- `team-config.json`과 `settings.local.json`은 로컬 전용 — gitignore, 커밋하지 않는다
- `team-rules.md`는 `~/.claude/`(유저 레벨)에 한 번만 생성 — 모든 프로젝트 공통 적용
- 훅은 `team-config.json` 존재 여부를 먼저 확인하므로 팀 설정 없는 프로젝트에서는 자동 비활성화
- 추천 목록은 **설치된 에이전트** 범위 내에서만 구성한다
- agency-agents 설치는 선택사항이며 이 스킬의 종속성이 아니다
- 훅과 env var는 `.claude/settings.local.json`(프로젝트 레벨)에 저장된다 — 글로벌 설정 오염 없음
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 없이는 TeamCreate가 동작하지 않는다
- `agent` 페르소나 설정만 `~/.claude/settings.json`(글로벌)에 저장된다
