# cc-bootstrap 개선 계획 — 유기적 3-Layer 재구성

> 작성: 2026-05-18. 목적: 런타임 의존성 자동 반영 + SRP 문서 분류 + 3-CLI 동등성.

## 1. 현재 문제

| # | 문제 | 영향 |
|---|---|---|
| P1 | Layer A `AGENTS.md` — 13개 섹션 단일 파일 (책임 혼재) | 유지보수·선택적 포함 불가 |
| P2 | Layer C loader — 텍스트 지시문 (`@import` 아님) | 템플릿·PROJECT.md 자동 로드 안 됨 (soft) |
| P3 | 최상단 CLAUDE.md — 단순 concat 덤프 | oh-my-setting식 lean 구조 아님 |
| P4 | MCP — Claude는 plugin, Codex/Gemini는 일부만 등록 | 3-CLI MCP 비대칭 |
| P5 | 프로젝트 문서 산재 (if-dfm: CLAUDE.md + policy/ + CONVENTIONS.md + docs/) | 중복·SRP 위반 |

## 2. 설계 원칙

1. **SRP**: 문서 1개 = 책임 1개.
2. **정적 해소(Static resolution)**: 의존성은 sync/apply 시점에 **병합**으로 해소 — `@import` 런타임 의존 배제 (Codex `@import` 불안정 → 3-CLI 균일성 위해 병합 채택).
3. **Lean 최상단**: 최상단 CLAUDE.md = oh-my-setting식 compact workflow 헤더 + 병합된 모듈.
4. **3-CLI 동등**: 규칙·스킬·MCP를 claude/codex/gemini에 동일 적용.

## 3. 문서 분류 (SRP) — 보고

현재 시스템의 모든 지침 콘텐츠를 단일 책임 단위로 분류:

| 책임 카테고리 | 현재 위치 | 신규 위치 | 동기화 |
|---|---|---|---|
| 신뢰성·태도 (사실 기반, "모르면 모른다", 근거·신뢰도) | `AGENTS.md` §핵심원칙·신뢰성 | `rules/00-core.md` | git (전역) |
| 컨텍스트 관리 (명확화·연속성) | `AGENTS.md` §컨텍스트* | `rules/10-context.md` | git |
| 작업 절차 (분석→spec→code, spec-gate, 의사결정) | `AGENTS.md` §의사결정·코드변경전분석 + spec-interview | `rules/20-workflow.md` | git |
| 편집·구현 (idempotent, 구조화 파일 존중) | `AGENTS.md` §편집규칙·명령및도구 | `rules/30-editing.md` | git |
| 검증 (bash -n, test 전략) | `AGENTS.md` §검증규칙 | `rules/40-verification.md` | git |
| 문서 작성 | `AGENTS.md` §문서화규칙 | `rules/50-documentation.md` | git |
| 검토/리뷰 가이드라인 | `AGENTS.md` §리뷰규칙·Subagent | `rules/60-review.md` | git |
| 결과/실험 분석 (ML 결과 해석·비교) | **없음 — ad-hoc** | `rules/70-analysis.md` (신규) | git |
| 도구 사용 (context-mode·RTK·skills·MCP) | `runtimes/<cli>/tools.md` | 유지 (Layer B, CLI별) | git |
| 응답 형식 | `AGENTS.md` §최종응답 | `runtimes/<cli>/tools.md` 흡수 (출력은 CLI별 상이) | git |
| 프로젝트 정의·spec | `PROJECT.md` | 유지 (Layer C) | 프로젝트 git |
| 프로젝트 규칙 (general/ml/slurm) | `templates/project-*.md` | 유지 (Layer C) | git |

→ Layer A = `rules/` 8개 모듈. 최상단 CLAUDE.md는 `rules/*.md`를 번호순 병합 + Layer B.

## 4. 런타임 의존성 해소 방안

- **전역(Layer A+B)**: `setup.sh assemble_global_rules`가 `cat rules/*.md + runtimes/<cli>/tools.md` → 각 CLI 전역 파일. 이미 정적 병합 ✓ (3-CLI 자동 로드 보장).
- **최상단 lean 헤더**: 병합 결과 맨 앞에 oh-my-setting식 compact 워크플로(spec-gate 한 눈 요약) 배치 → `rules/00-core.md`가 그 역할.
- **Layer C (핵심 변경)**: `apply-project-template.sh`가 **포인터 대신 템플릿 내용을 managed block에 인라인**. → 프로젝트 CLAUDE.md만 읽어도 ml/slurm 규칙이 그 자리에 존재. Codex/Gemini 포함 균일 자동 로드.
- **PROJECT.md**: 프로젝트 CLAUDE.md에 `@PROJECT.md` import(Claude/Gemini 자동 펼침) + 텍스트 지시(Codex fallback) 병기.

## 5. 3-CLI 동등성 (codex/gemini)

- **규칙**: assembly가 이미 3-CLI 처리 ✓
- **스킬**: `registry.yaml` → `~/.{claude,codex,gemini,agents}/skills/` symlink ✓ (이미 동작)
- **MCP (P4 — 미해결)**: Claude=plugin, Codex=`config.toml [mcp_servers]`, Gemini=`settings.json`. setup.sh가 context-mode만 codex에 등록 중. → **통합 MCP 등록 단계** 신설: 스킬이 요구하는 MCP(serena, code-review-graph, context-mode)를 codex+gemini 양쪽 config에 idempotent 등록.

## 6. 실행 단계

| Phase | 작업 | 산출물 | 검증 |
|---|---|---|---|
| 1 | `AGENTS.md` → `rules/` 8개 SRP 모듈 분리 | `rules/00~70*.md` | 내용 보존 diff |
| 2 | `setup.sh assemble_global_rules` — `rules/*.md` 병합으로 변경 | setup.sh | `bash -n` + 조립 출력 |
| 3 | `apply-project-template.sh` — 포인터→인라인, `@PROJECT.md` 병기 | 스크립트 | dry-run + 실프로젝트 |
| 4 | MCP 통합 등록 단계 신설 (codex/gemini) | setup.sh `ensure_mcp_parity()` | codex/gemini config 확인 |
| 5 | 프로젝트 문서 통폐합 (if-dfm: 중복 "사용자 작업 스타일"→Layer A 위임) | 프로젝트별 CLAUDE.md | 프로젝트별 커밋 |

각 Phase는 독립 커밋. Phase 1~4는 cc-bootstrap, Phase 5는 각 프로젝트 repo.

## 7. 미결 결정 (사용자 확인 필요)

- D1: `rules/` 8모듈 분리 입도 — 8개가 과한가? (6개로 통합 대안: core/context/workflow/editing/verification+review/documentation)
- D2: Layer C 인라인 시 프로젝트 CLAUDE.md 비대해짐 (ml 템플릿 ~100줄 인라인). 허용 가능한가? 아니면 Claude만 `@import`, Codex/Gemini는 인라인 하이브리드?
- D3: if-dfm 기존 "사용자 작업 스타일" 섹션 — Layer A와 중복. 삭제하고 Layer A 위임 vs 프로젝트 고유분만 남기기.
