---
name: anthropic-folder-mastery
description: "Anthropic 수준의 폴더 구조화/관리 방법론 — 7계층 분류, 디렉토리 승격 기준, 4가지 네이밍 컨벤션, 레지스트리 패턴, 의미론적 조직화"
whenToUse: "폴더 구조, 디렉토리 설계, 파일 정리, 프로젝트 구조, folder structure, directory organization"
---

# Anthropic Folder Mastery

Claude Code 302개 디렉토리, 1905개 파일의 폴더 구조에서 추출한 조직화 방법론.

## 적용 대상: $ARGUMENTS

---

## 원칙 1: 기능 계층별 분리 (7-Layer)

```
Layer 0: entrypoints/    — 진입점 (최소 임포트, 빠른 경로)
Layer 1: types/, schemas/ — 핵심 타입 (import cycle 방지)
Layer 2: query/          — 핵심 파이프라인
Layer 3: tools/, tasks/  — 실행 단위
Layer 4: commands/, skills/ — 사용자 인터페이스
Layer 5: components/, screens/ — UI
Layer 6: services/, utils/ — 인프라
Layer 7: plugins/, bridge/, remote/ — 확장
```

**의존성은 아래로만.** 같은 레이어 내 횡단 참조 최소화.

---

## 원칙 2: 디렉토리 승격 기준

**단일 파일 → 디렉토리 승격 시점:**

| 조건 | 예시 |
|------|------|
| UI 분리 필요 (`UI.tsx`) | `BashTool/BashTool.tsx + UI.tsx` |
| 프롬프트 분리 필요 (`prompt.ts`) | `AgentTool/AgentTool.tsx + prompt.ts` |
| 상수 분리 필요 (`constants.ts`) | `TaskCreateTool/constants.ts` |
| 3+ 헬퍼 파일 | `BashTool/bashSecurity.ts + bashPermissions.ts + ...` |

**기준 미달 시 단일 파일 유지** — 불필요한 디렉토리 생성 금지.

---

## 원칙 3: 4가지 네이밍 컨벤션

| 컨벤션 | 의미 | 사용처 |
|--------|------|--------|
| `PascalCase` | 클래스/컴포넌트/주요 모듈 | `BashTool.tsx`, `QueryEngine.ts` |
| `camelCase` | 유틸/서비스/헬퍼 | `bashPermissions.ts`, `agentMemory.ts` |
| `kebab-case` | 커맨드 디렉토리 | `add-dir/`, `release-notes/` |
| `SCREAMING_SNAKE` | 모듈 상수 | `TOOL_DEFAULTS`, `MAX_STATUS_CHARS` |

**규칙**: 네이밍 컨벤션 자체가 파일의 역할을 전달. 혼용 금지.

---

## 원칙 4: "척추" 파일은 루트에

루트 레벨에 남는 파일 = 아키텍처의 척추:
```
Tool.ts, Task.ts       — 핵심 인터페이스 (거의 모든 곳에서 import)
tools.ts, tasks.ts     — 레지스트리 (단일 진실 소스)
query.ts, QueryEngine.ts — 파이프라인 중심
commands.ts            — 커맨드 허브
context.ts             — 컨텍스트 조립
```

**이유**: 서브디렉토리에 넣으면 임포트 경로에 불필요한 노이즈 추가.

---

## 원칙 5: 레지스트리 패턴

```typescript
// tools.ts — 단일 진실 소스
export function getAllBaseTools(): Tools { ... }

// commands.ts — 우선순위 기반 병합
function getCommands(): Command[] {
  return merge(bundled, builtinPlugin, skillDir, workflow, plugin, mcp)
}
```

**모든 유형의 실행 단위(도구/커맨드/스킬/태스크)는 하나의 레지스트리 파일이 진실 소스.**

---

## 원칙 6: 도구 디렉토리 내부 컨벤션

```
tools/{PascalCaseName}Tool/
  ├── {PascalCaseName}Tool.ts[x]  — 메인 구현 (buildTool 호출)
  ├── prompt.ts                    — 시스템 프롬프트 텍스트
  ├── UI.tsx                       — Ink 렌더링 컴포넌트
  ├── constants.ts                 — 이름/설정 상수
  └── [도메인별 헬퍼]              — camelCase 헬퍼 파일
```

---

## 원칙 7: utils/ 점진적 추출

```
utils/ (250+ 파일 — 가장 큰 디렉토리)
  ├── permissions/   ← 이미 추출됨
  ├── hooks/         ← 이미 추출됨
  ├── model/         ← 이미 추출됨
  ├── settings/      ← 이미 추출됨
  ├── bash/          ← 이미 추출됨
  ├── swarm/         ← 이미 추출됨
  └── [나머지 flat files] ← 자연스러운 그룹이 보이면 추출
```

**원칙**: catch-all 디렉토리는 존재하되, 자연스러운 클러스터가 형성되면 서브디렉토리로 추출.

---

## 원칙 8: Import Cycle 방지 전략

1. **공유 타입을 `types/`로 추출** — cycle의 90%를 해결
2. **지연 `require()`** — 조건부 임포트로 초기화 순서 문제 해결
3. **레지스트리 패턴** — 순환 참조를 간접 참조로 교체
4. **코드 복제 허용** (극소량) — cycle 방지가 DRY보다 우선

---

## 실행

`$ARGUMENTS`에 대해:
1. 현재 구조 파악 및 계층 식별
2. 각 파일/디렉토리의 역할 분류
3. 네이밍 컨벤션 일관성 확인
4. 디렉토리 승격 기준 적용
5. 레지스트리 패턴으로 진실 소스 확립
6. Import cycle 방지 전략 적용
