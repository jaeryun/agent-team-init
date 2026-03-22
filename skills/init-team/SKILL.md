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

### 3단계: 글로벌 설정 확인 및 설치

#### 3-1. 에이전트 팀 기능 활성화 확인

팀 생성(`TeamCreate`)이 작동하려면 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 환경변수가 필요하다:

```bash
jq '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // empty' ~/.claude/settings.json
```

값이 없거나 `"1"`이 아니면 AskUserQuestion으로 물어본다:

> "`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`이 설정되어 있지 않습니다.
> 이 값이 없으면 팀 생성(TeamCreate)이 작동하지 않습니다.
>
> 지금 추가할까요?
> 1. 예 — 자동으로 settings.json에 추가
> 2. 아니오 — 건너뛰기"

"예"를 선택하면 `~/.claude/settings.json`의 `env` 필드에 추가한다:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

#### 3-2. 글로벌 훅 확인 및 설치

팀 워크플로우 규칙을 강제하는 글로벌 훅이 `~/.claude/settings.json`에 있는지 확인한다:

```bash
jq '.hooks.PreToolUse // empty' ~/.claude/settings.json
```

**훅이 없는 경우** AskUserQuestion으로 물어본다:

> "글로벌 PreToolUse 훅이 설정되어 있지 않습니다.
> 훅이 없으면 team-config.json을 만들어도 팀 규칙이 강제되지 않습니다.
>
> 지금 설치할까요? (권장)
> 1. 예 — 글로벌 훅 자동 설치
> 2. 아니오 — 건너뛰기 (나중에 직접 설정)"

**"예"를 선택하면** `~/.claude/settings.json`에 아래 두 훅을 머지한다.
기존 설정은 보존하고 `hooks.PreToolUse` 배열에만 추가한다:

**훅 1 — Agent 툴: 팀 멤버를 team_name 없이 서브에이전트로 호출 차단**
```json
{
  "matcher": "Agent",
  "hooks": [{
    "type": "command",
    "command": "INPUT=$(cat); TEAM_CONFIG=\".claude/team-config.json\"; [ ! -f \"$TEAM_CONFIG\" ] && exit 0; SUBAGENT_TYPE=$(echo \"$INPUT\" | jq -r '.tool_input.subagent_type // \"\"'); [ -z \"$SUBAGENT_TYPE\" ] && exit 0; TEAM_NAME=$(echo \"$INPUT\" | jq -r '.tool_input.team_name // \"\"'); IS_TEAM_MEMBER=$(jq --arg r \"$SUBAGENT_TYPE\" '[.teamMembers[] | select(. == $r)] | length > 0' \"$TEAM_CONFIG\"); if [ \"$IS_TEAM_MEMBER\" = \"true\" ] && [ -z \"$TEAM_NAME\" ]; then echo \"{\\\"continue\\\": false, \\\"stopReason\\\": \\\"⛔ 팀 멤버 규칙 위반: '$SUBAGENT_TYPE' 는 TeamCreate 후 team_name + name 포함해서 생성하세요.\\\"}\"; fi",
    "statusMessage": "팀 멤버 생성 규칙 확인 중..."
  }]
}
```

**훅 2 — Write/Edit 툴: team-lead의 코드 파일 직접 구현 차단**
```json
{
  "matcher": "Write|Edit",
  "hooks": [{
    "type": "command",
    "command": "INPUT=$(cat); TEAM_CONFIG=\".claude/team-config.json\"; [ ! -f \"$TEAM_CONFIG\" ] && exit 0; FILE_PATH=$(echo \"$INPUT\" | jq -r '.tool_input.file_path // \"\"'); [ -z \"$FILE_PATH\" ] && exit 0; EXT=\".${FILE_PATH##*.}\"; BLOCKED=$(jq --arg e \"$EXT\" '[.blockedExtensions[] | select(. == $e)] | length > 0' \"$TEAM_CONFIG\"); if [ \"$BLOCKED\" = \"true\" ]; then echo \"{\\\"continue\\\": false, \\\"stopReason\\\": \\\"⛔ team-lead 직접 구현 금지: $FILE_PATH → 담당 팀 멤버에게 SendMessage로 위임하세요.\\\"}\"; fi",
    "statusMessage": "team-lead 직접 구현 여부 확인 중..."
  }]
}
```

설치 후 JSON 문법을 검증한다:
```bash
jq -e '.hooks.PreToolUse' ~/.claude/settings.json && echo "✅ 훅 설치 완료"
```

**"아니오"를 선택하면** 계속 진행하되 마지막 완료 메시지에 경고를 포함한다.

**훅이 이미 있는 경우** 조용히 계속 진행한다.

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

완료 후 알린다: `"✅ team-lead 페르소나: Agents Orchestrator 설정됨"`

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
  "_comment": "이 파일은 gitignore됩니다. 팀 공유용은 team-config.example.json을 사용하세요.",
  "_teamMembers_note": "후보 풀입니다. 실제 생성은 team-lead가 작업별로 사용자 허락을 받고 동적으로 수행합니다.",
  "teamMembers": ["최종 선택된 역할 후보 목록"],
  "blockedExtensions": [".py", ".ts", ".tsx", "..."],
  "allowedExtensions": [".md", ".json", ".yaml", "..."]
}
```

#### `.claude/team-config.example.json` 생성 (git 커밋용 템플릿)

현재 설치된 전체 에이전트 목록을 포함한 템플릿으로 생성한다:
```json
{
  "_comment": "복사해서 team-config.json으로 사용하세요. team-config.json은 gitignore됩니다.",
  "teamMembers": ["설치된 전체 에이전트 목록"],
  "blockedExtensions": [".py", ".ts", ".tsx", ".js", ".jsx", ".go", ".rs", ".java", ".cpp", ".c", ".cs"],
  "allowedExtensions": [".md", ".json", ".yaml", ".yml", ".txt", ".gitignore", ".env.example"]
}
```

#### `.claude/team-rules.md` 생성 (플러그인 무관 팀 행동 규칙)

git 커밋 가능. team-lead와 팀 멤버가 런타임에 참조하는 행동 규칙이다.
워크플로우 도구(Superpowers 등)와 무관하게 팀 구조에 항상 적용된다.

```markdown
# 에이전트 팀 행동 규칙

> 이 파일은 `/init-team` 스킬로 생성된다. 워크플로우 도구와 무관하게 팀 구조에 항상 적용된다.

## team-lead 역할

- 파이프라인 조율, 태스크 배분, 통합, 최종 승인 담당
- 코드·설정 파일 직접 구현 금지 — 반드시 담당 팀 멤버에게 SendMessage로 위임

## 동적 팀 멤버 생성 프로세스

각 작업 시작 시 아래 순서를 따른다:

1. **작업 분석** — 현재 태스크에 필요한 역할 판단
2. **최소 멤버 결정** — `.claude/team-config.json` 후보 풀에서 꼭 필요한 역할만 선택
3. **사용자 허락 요청** — 생성 전 반드시 확인:
   > "이 작업을 위해 다음 팀 멤버를 생성하겠습니다:
   > - **[역할명]** ([페르소나]): [담당 내용]
   > 진행해도 될까요?"
4. **생성** — `TeamCreate` → `Agent(team_name=..., name=..., subagent_type=...)`
5. **재사용 우선** — 이미 생성된 멤버는 새로 만들지 않고 `SendMessage`로 재사용

**원칙:**
- 한 번에 최소 필요 멤버만 생성 (과도한 팀 구성 금지)
- 불확실하면 한 명씩 순차 생성
- 범용 태스크(리뷰·문서화·검증)는 서브에이전트로 처리 (팀 멤버 불필요)

## 서브에이전트 vs 팀 멤버

| 상황 | 선택 |
| --- | --- |
| 지속적 구현이 필요한 도메인 전문 역할 | 팀 멤버 |
| 코드 리뷰, 완료 검증, 문서화 등 단발 목적 | 서브에이전트 |
| 후보 풀에 없는 역할 | 서브에이전트 |

## 팀 멤버 도메인 제한

- 각 멤버는 할당된 도메인만 담당
- 다른 멤버 담당 파일 직접 수정 금지 — 필요하면 `SendMessage`로 해당 멤버에게 요청

## 완료 기준

team-lead는 아래가 모두 충족될 때만 태스크 완료로 간주한다:

1. 모든 테스트 통과
2. 담당 멤버의 완료 검증 실행 완료
3. 코드 리뷰 서브에이전트 리뷰 통과
4. 통합 방식 결정 및 실행 (PR 또는 머지)
```

---

### 9단계: .gitignore 업데이트

프로젝트 루트의 `.gitignore`에 없으면 추가한다:

```
# Agent team config (local only)
.claude/team-config.json
```

---

### 10단계: 완료 메시지

```
✅ 팀 설정 완료!

생성된 파일:
  .claude/team-config.json         ← 로컬 전용 (gitignore됨)
  .claude/team-config.example.json ← 팀 공유용 템플릿 (git 커밋 권장)
  .claude/team-rules.md            ← 팀 행동 규칙 (git 커밋 권장)

활성화된 팀 후보 풀:
  - [선택된 역할들]

차단된 파일 확장자: [목록]

다음 단계:
  1. 팀 규칙을 AI 컨텍스트에 포함하려면 프로젝트 CLAUDE.md에 추가:
     @.claude/team-rules.md
  2. Superpowers 워크플로우 연결 (선택사항):
     /init-sp-for-team
  3. git 커밋:
     git add .claude/team-config.example.json .claude/team-rules.md
  4. 팀 작업 시작:
     TeamCreate → Agent(team_name=..., name=...) → SendMessage
  5. Claude Code를 재시작하거나 /hooks 를 열어 설정을 리로드하세요.
```

---

## 주의사항

- 항상 **현재 프로젝트 디렉토리**에 파일을 생성한다 (`~/.claude/`가 아님)
- 추천 목록은 **설치된 에이전트** 범위 내에서만 구성한다
- agency-agents 설치는 선택사항이며 이 스킬의 종속성이 아니다
- `team-config.json`은 gitignore, `team-config.example.json`은 git 커밋 권장
- 글로벌 훅이 없으면 `team-config.json`만으로는 규칙이 강제되지 않는다
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 없이는 TeamCreate가 동작하지 않는다
