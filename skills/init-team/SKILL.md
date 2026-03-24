---
name: init-team
description: Use when initializing an agent team for a project — /init-team, "팀 설정 초기화", "에이전트 팀 구성", "team-config 만들어줘", "팀 워크플로우 설정".
---

# init-team: 프로젝트 에이전트 팀 설정 초기화

현재 프로젝트 디렉토리에 `.claude/team-config.json`을 생성해 팀 워크플로우 규칙을 활성화한다.

이 파일이 존재하면 `.claude/settings.local.json`의 훅이 자동으로 아래 규칙을 강제한다:
- **규칙 1**: 팀 멤버 역할을 `team_name` 없이 서브에이전트로 호출 금지

> **참고**: team-lead의 코드 직접 작성은 훅으로 강제하지 않는다.
> `settings.local.json`은 팀원 에이전트에도 동일하게 적용되기 때문에,
> `Write|Edit` 훅은 team-lead와 팀원을 구분할 수 없다. 아키텍처 규율은 원칙으로 운영한다.

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
> - PreToolUse 훅 1개 — 팀 멤버 잘못된 생성 차단 (team_name 없이 팀 멤버 역할 직접 호출 금지)
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
      }
    ]
  }
}
```

> **왜 `Write|Edit` 훅이 없나?**
> `settings.local.json`은 팀원 에이전트(frontend, backend 등)에도 동일하게 적용된다.
> team-lead와 팀원을 env var로 구분할 방법이 없으므로 `Write|Edit` 훅을 추가하면
> 팀원의 파일 작성도 차단된다. team-lead 코드 직접 작성 금지는 원칙으로 운영한다.

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

### 5-1단계: 역할별 모델 설정

선택된 역할(Agents Orchestrator 포함)에 사용할 AI 모델을 설정한다.
비용과 성능을 고려해 역할별로 다른 모델을 지정할 수 있다.

AskUserQuestion으로 선택받는다:

```
각 역할에 사용할 모델을 설정하세요.
비용과 성능을 고려해 역할별로 다르게 지정할 수 있습니다.

모델 옵션:
  opus    — 최고 성능, 복잡한 설계·판단 작업  (비용 높음)
  sonnet  — 균형잡힌 성능, 일반 구현 작업     (기본값, 권장)
  haiku   — 빠르고 저렴, 단순 반복 작업       (비용 낮음)

추천 기본값:
  orchestrator                   → sonnet  (파이프라인 관리, 판단 필요)
  engineering-backend-architect  → sonnet  (복잡한 구현)
  engineering-frontend-developer → sonnet  (복잡한 구현)
  engineering-database-optimizer → sonnet  (스키마 설계)
  engineering-devops-automator   → haiku   (스크립트 작업)

어떻게 할까요?
  1. 추천 기본값 사용
  2. 전체 동일 모델 사용 (예: "모두 sonnet")
  3. 역할별 직접 지정
```

선택 결과를 `modelConfig` 맵으로 저장한다.
(지정하지 않은 역할은 기본값 `sonnet`으로 처리한다)

---

### 6단계: 페르소나 설치 및 디폴트 에이전트 설정 (필수)

이 팀 구조는 **두 개의 세션**으로 운영된다:

```
┌─────────────────────────────────────────────────────────────┐
│ [Architect 세션] — 스펙 설계                                 │
│                                                             │
│  사람 ↔ Software Architect (스펙 리드)                       │
│              ↓ 도메인 설계 필요 시                           │
│         Software Architect ↔ Backend/Frontend Architect     │
│         (Software Architect가 팀 멤버로 생성해 협업)         │
│              ↓                                              │
│         통합 스펙 완성 → 파일로 저장                         │
└─────────────────────────────────────────────────────────────┘
                         ↓ 스펙 확정
┌─────────────────────────────────────────────────────────────┐
│ [Orchestrator 세션] — 구현 파이프라인                        │
│                                                             │
│  사람 → Agents Orchestrator (스펙 전달)                      │
│              ↓                                              │
│         태스크 분해 → 팀 멤버에게 위임 → 품질 게이트         │
│              ↓ 스펙 변경 필요 시                             │
│         파이프라인 중단 → Architect 세션으로 안내            │
│              ↓ 업데이트된 스펙 가져오면                      │
│         영향받는 태스크부터 재개                             │
└─────────────────────────────────────────────────────────────┘
```

> **Software Architect가 스펙 리드인 이유:**
> Backend/Frontend 등 도메인 아키텍트는 각 영역의 깊이는 있지만 시스템 전체를 통합하는 역할이 아니다.
> Software Architect가 전체 스펙을 소유하고, 필요 시 도메인 아키텍트를 팀 멤버로 생성해 협업한다.
> 사람은 Software Architect와만 대화하면 되고, 스펙은 하나의 통합 문서로 완성된다.

두 페르소나 모두 필수다. 설치 없이는 진행할 수 없다.

```bash
ls ~/.claude/agents/Software\ Architect.md 2>/dev/null && echo "SA: 있음" || echo "SA: 없음"
ls ~/.claude/agents/Agents\ Orchestrator.md 2>/dev/null && echo "AO: 있음" || echo "AO: 없음"
```

---

#### 케이스 A: 둘 다 있는 경우

조용히 다음으로 진행한다.

---

#### 케이스 B: 하나라도 없는 경우

AskUserQuestion으로 설치 방법을 선택받는다:

> "필수 페르소나가 설치되어 있지 않습니다.
>
> **방법 1 — agency-agents 전체 설치** (권장):
> ```bash
> git clone --depth=1 https://github.com/msitarzewski/agency-agents /tmp/agency-agents-install
> cp /tmp/agency-agents-install/agents/*.md ~/.claude/agents/
> rm -rf /tmp/agency-agents-install
> ```
>
> **방법 2 — 필요한 페르소나만 개별 설치**:
> ```bash
> mkdir -p ~/.claude/agents
> # Software Architect
> curl -fsSL "https://raw.githubusercontent.com/msitarzewski/agency-agents/main/agents/Software%20Architect.md" \
>   -o ~/.claude/agents/Software\ Architect.md
> # Agents Orchestrator
> curl -fsSL "https://raw.githubusercontent.com/msitarzewski/agency-agents/main/agents/Agents%20Orchestrator.md" \
>   -o ~/.claude/agents/Agents\ Orchestrator.md
> ```
>
> 1. 전체 설치 (권장)
> 2. 개별 설치"

선택에 따라 설치 명령을 실행한다.

---

#### 디폴트 에이전트 설정

**메인 터미널의 기본 페르소나는 Software Architect**다.
스펙 설계가 워크플로우의 시작점이며 가장 많은 시간을 차지하기 때문이다.

`settings.json`의 `agent` 필드를 확인하고 설정한다:

```bash
jq '.agent // "미설정"' ~/.claude/settings.json
```

- 이미 `"Software Architect"`이면 변경 없이 넘어간다.
- 다른 값이면 현재 값을 보여주고 재확인 후 업데이트한다:

```json
{
  "agent": "Software Architect"
}
```

완료 후 알린다:

> "✅ 페르소나 설정 완료
>
> 메인 터미널: **Software Architect** (스펙 설계 허브)
>
> 워크플로우:
> 1. 이 터미널에서 요구사항 분석 및 스펙 설계
> 2. 스펙 확정 후 /call-team → Agents Orchestrator + 도메인 멤버 스폰
> 3. Agents Orchestrator에게 스펙 전달 → 구현 파이프라인 실행"

---

### 7단계: 파일 생성

#### `.claude/` 디렉토리 생성 (없는 경우)
```bash
mkdir -p .claude
```

#### `.claude/team-config.json` 생성 (최종 확정된 후보 풀로)
```json
{
  "_teamMembers_note": "후보 풀입니다. 실제 생성은 team-lead가 작업별로 사용자 허락을 받고 동적으로 수행합니다.",
  "teamMembers": ["최종 선택된 역할 후보 목록"],
  "modelConfig": {
    "orchestrator": "sonnet",
    "engineering-backend-architect": "sonnet",
    "engineering-frontend-developer": "sonnet",
    "engineering-database-optimizer": "sonnet",
    "engineering-devops-automator": "haiku"
  }
}
```

> `modelConfig`의 키는 역할 ID(`teamMembers`에 포함된 것) 및 `"orchestrator"`를 사용한다.
> 키가 없는 역할은 스폰 시 `sonnet`을 기본값으로 사용한다.

---

### 8단계: .gitignore 업데이트

프로젝트 루트의 `.gitignore`에 없으면 추가한다:

```
# Agent team local settings (local only)
.claude/settings.local.json
.claude/team-config.json
```

---

### 9단계: 유저 레벨 team-rules.md 생성

`~/.claude/team-rules.md`가 이미 존재하는지 확인한다:

```bash
cat ~/.claude/team-rules.md 2>/dev/null && echo "이미 있음" || echo "없음"
```

**없는 경우** `~/.claude/team-rules.md`를 아래 내용으로 생성한다:

```markdown
# 에이전트 팀 행동 규칙

> 이 파일은 `/init-team` 스킬로 생성된다. 워크플로우 도구와 무관하게 팀 구조에 항상 적용된다.

## 세션 구조

이 팀 워크플로우는 **두 개의 분리된 세션**으로 운영된다:

| 세션 | 페르소나 | 목적 |
| --- | --- | --- |
| **Architect 세션** | Software Architect (스펙 리드) | 요구사항 정의, 설계, 스펙 작성 |
| **Orchestrator 세션** | Agents Orchestrator | 구현 파이프라인, 팀 관리, 품질 게이트 |

스펙 설계는 Architect 세션에서 사람이 **직접** Software Architect와 대화해 수행한다.
Agents Orchestrator는 **확정된 스펙을 받은 시점부터만** 파이프라인을 시작한다.

### Architect 세션 구조

Software Architect가 스펙 전체를 소유한다.
도메인별 심층 설계가 필요하면 Software Architect가 직접 도메인 아키텍트를 팀 멤버로 생성해 협업한다:

- 백엔드 설계 필요 → Backend Architect 생성
- 프론트엔드 설계 필요 → Frontend Developer/Architect 생성
- DB 설계 필요 → Database Optimizer 생성

사람은 Software Architect와만 대화하면 되고, 통합 스펙은 Software Architect가 작성한다.

## Agents Orchestrator 역할

- 구현 파이프라인 조율, 태스크 배분, 통합, 최종 승인 담당
- 코드·설정 파일 직접 구현 금지 — 반드시 담당 팀 멤버에게 SendMessage로 위임
- 설계·브레인스토밍 직접 수행 금지 — 스펙이 없으면 Architect 세션으로 안내

### 스펙 없이 구현 요청이 들어온 경우

파이프라인 시작을 거부하고 안내한다:

> "구현을 시작하려면 먼저 스펙이 필요합니다.
> Software Architect와 별도 세션에서 설계를 진행해주세요.
> 스펙이 확정되면 이 세션으로 돌아와 전달해주세요."

### 스펙 변경이 필요한 경우

구현 중 스펙 변경 요청이 들어오면:

1. 현재 진행 중인 태스크를 즉시 중단한다
2. 파이프라인 현재 상태를 기록한다:
   > "스펙 변경이 필요하군요. Architect 세션에서 스펙을 업데이트해주세요.
   >
   > 현재 파이프라인 상태:
   > - 완료: [완료된 태스크 목록]
   > - 중단: [중단된 태스크]
   > - 미시작: [남은 태스크 목록]"
3. 업데이트된 스펙을 받으면 변경 영향 범위를 분석해 해당 태스크부터 재개한다

## 팀 멤버 역할 경계

도메인 구현 멤버(Backend Architect, Frontend Developer, Database Optimizer 등)는
자신의 도메인 구현 작업만 담당한다. 아래 유형의 요청이 들어오면 **거부하고 올바른 세션으로 안내**한다.

### 설계·브레인스토밍 요청이 들어온 경우

> "저는 구현 담당입니다. 요구사항 정의나 시스템 설계는 제 역할이 아닙니다.
> **Architect 세션**에서 Software Architect와 직접 진행해주세요.
> 스펙이 확정되면 Orchestrator 세션으로 돌아오세요."

### 파이프라인 관리·태스크 배분 요청이 들어온 경우

> "저는 구현 담당입니다. 파이프라인 관리나 태스크 조율은 제 역할이 아닙니다.
> **Orchestrator 세션**의 Agents Orchestrator에게 요청해주세요."

### 다른 도메인 구현 요청이 들어온 경우

> "저는 [본인 도메인] 담당입니다. [요청 도메인] 구현은 제 역할 범위가 아닙니다.
> Orchestrator 세션에서 해당 도메인 담당 멤버에게 요청해주세요."

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
- 범용 태스크(리뷰·문서화·검증·보안 검토)는 서브에이전트로 처리 (팀 멤버 불필요)

## 서브에이전트 vs 팀 멤버

| 상황 | 선택 |
| --- | --- |
| 지속적 구현이 필요한 도메인 전문 역할 | 팀 멤버 |
| 코드 리뷰, 완료 검증, 문서화, 보안 검토 등 단발 목적 | 서브에이전트 |
| 후보 풀에 없는 역할 | 서브에이전트 |

## 팀 멤버 도메인 제한

- 각 멤버는 할당된 도메인만 담당
- 다른 멤버 담당 파일 직접 수정 금지 — 필요하면 `SendMessage`로 해당 멤버에게 요청

## 완료 기준

Agents Orchestrator는 아래가 모두 충족될 때만 태스크 완료로 간주한다:

1. 모든 테스트 통과
2. 담당 멤버의 완료 검증 실행 완료
3. 코드 리뷰 서브에이전트 리뷰 통과
4. 통합 방식 결정 및 실행 (PR 또는 머지)
```

**이미 있는 경우** 변경 없이 넘어간다.

---

### 10단계: 유저 레벨 CLAUDE.md에 참조 추가

`~/.claude/CLAUDE.md`에 `@team-rules.md`가 포함되어 있는지 확인한다:

```bash
grep -q "@team-rules.md" ~/.claude/CLAUDE.md 2>/dev/null && echo "team-rules: 있음" || echo "team-rules: 없음"
```

없으면 `~/.claude/CLAUDE.md` 끝에 추가한다:

```markdown
@team-rules.md
```

`~/.claude/CLAUDE.md`가 없는 경우 새로 생성한다.

> `team-rules.md`는 모든 프로젝트에서 공통으로 적용되는 팀 행동 규칙이다.
> 훅이 `team-config.json` 존재 여부를 먼저 확인하므로, 팀 설정이 없는 프로젝트에서는 자연스럽게 비활성화된다.

---

### 11단계: 완료 메시지

```
✅ 팀 설정 완료!

생성된 파일:
  ~/.claude/team-rules.md      ← 팀 행동 규칙 (유저 레벨, 모든 프로젝트 공통)
  ~/.claude/CLAUDE.md          ← @team-rules.md 참조 추가됨
  .claude/settings.local.json  ← 훅 + env var (로컬 전용, gitignore됨)
  .claude/team-config.json     ← 팀 후보 풀 (로컬 전용, gitignore됨)

활성화된 팀 후보 풀:
  - [선택된 역할들]

워크플로우:
  [스펙 설계]  Software Architect 페르소나로 새 세션 시작
               → 요구사항 정의 및 설계 (도메인 아키텍트와 협업)
               → 통합 스펙 파일 완성
  [구현]       이 세션(Agents Orchestrator)에 스펙 전달
               → 파이프라인 자동 실행
  [스펙 변경]  언제든 Architect 세션으로 돌아가 수정 가능
               → 업데이트된 스펙을 Orchestrator 세션에 전달하면 재개

다음 단계:
  1. Superpowers 워크플로우 연결 (선택사항):
     /init-sp-for-team
  2. ⚠️  Claude Code를 재시작하거나 /hooks 를 실행해 훅을 리로드하세요.
     (재시작 전까지 훅이 적용되지 않습니다)
  3. 재시작 후 Software Architect 세션에서 스펙 설계를 시작하세요.
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
