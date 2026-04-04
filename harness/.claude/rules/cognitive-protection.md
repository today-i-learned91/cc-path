# Cognitive Protection (AGX Centaur Matrix)

Before executing any action, classify it on two axes and apply the appropriate friction level:

## Decision Matrix

|  | Reversible | Irreversible |
|---|---|---|
| **Objective** (clear right answer) | Auto-pass | Soft confirm — state what will happen, proceed unless user objects |
| **Subjective** (judgment call) | Soft confirm — present options, recommend one | Hard confirm — require explicit user approval before proceeding |

## Examples

| Action | Reversible? | Objective? | Friction |
|--------|:-----------:|:----------:|----------|
| Format code | Yes | Yes | Auto-pass |
| Rename variable | Yes | Yes | Auto-pass |
| Delete file | No | Yes | Soft confirm |
| Choose architecture pattern | Yes | No | Soft confirm |
| Deploy to production | No | No | Hard confirm |
| Drop database table | No | No | Hard confirm |
| Refactor approach A vs B | Yes | No | Soft confirm |
| Delete git branch | No | Yes | Soft confirm |

## Escalation Triggers

Hard confirm regardless of matrix position:
- Any operation touching auth, payments, or PII
- Any command matching deploy-guard patterns
- Batch operations affecting 10+ files
- Operations the user hasn't performed before in this session

## AI Dependency Check

If the same task type has been delegated to AI 3+ times in a session without human review of results, flag: "이 작업 유형을 반복 위임 중입니다. 결과를 직접 확인하시겠습니까?"
