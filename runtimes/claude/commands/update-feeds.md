---
description: Slack #ai-feed 채널에서 새 도구 링크를 수집하여 Claude and Claude code.md에 분류·추가한다.
---

# Slack → 도구 문서 자동 업데이트

## 1단계: Slack #ai-feed 채널에서 메시지 수집

mcp__slack-server__conversations_search_messages를 호출하여 #ai-feed 채널의 최근 메시지를 가져온다.

```
mcp__slack-server__conversations_search_messages:
  filter_in_channel: "#ai-feed"
  limit: 50
```

참고: conversations_history는 missing_scope 에러 발생. conversations_search_messages를 사용할 것.

## 2단계: URL 추출 및 중복 확인

수집된 메시지에서:
1. URL을 추출한다 (text 필드의 <URL> 또는 attachments의 from_url)
2. PROject/AI_Tools/Claude/Claude and Claude code.md를 읽는다
3. 이미 등록된 URL인지 확인한다 (중복 스킵)

## 3단계: 새 URL 조사 (Claude 독립 분석)

중복이 아닌 새 URL 각각에 대해:

1. **Slack 메시지의 attachments.text에서 설명 확인** — Slack 미리보기에 포함된 요약 활용
2. **URL이 GitHub repo면** WebFetch로 리포 내용 확인
3. **Claude가 먼저 분류 판단:**
   - Skill: SKILL.md 포함. Claude가 동적 로드하는 마크다운 지시서
   - Plugin: .claude-plugin manifest 포함. /plugin install로 설치
   - MCP: Model Context Protocol 서버
   - Agent/Automation: 멀티 Claude 오케스트레이션, 워크플로 자동화, CLI 도구
   - Guide: 문서, 기사, 치트시트
   - Marketplace: 모음집, 디렉토리
   - Inbox: 분류 불확실하거나 Claude Code 무관

## 3.5단계: Codex + Gemini 교차 검증

Claude의 분류 결과를 Codex와 Gemini에 병렬로 검증 요청한다.

**Codex 검증** (mcp__codex-mcp__ask_codex):
```
각 도구에 대해 CORRECT / WRONG (올바른 카테고리) / UNSURE로 답하라.
분류 기준:
- Skill: SKILL.md 포함
- Plugin: .claude-plugin manifest 포함
- MCP: Model Context Protocol 서버
- Agent/Automation: 멀티 Claude 오케스트레이션, CLI 도구
- Guide: 문서/기사
- Marketplace: 모음집
- Inbox: 미확인
```

**Gemini 검증** (mcp__gemini-mcp__ask_gemini):
```
동일한 분류 기준으로 각 도구의 분류를 검증하라.
google_web_search로 실제 리포/사이트를 확인할 것.
```

**합의 규칙:**
- 3자 일치 → 해당 분류 확정
- 2자 일치 → 다수 의견 채택, 소수 의견 기록
- 3자 불일치 → Inbox에 추가 (확인 필요 표시)

## 4단계: 문서 업데이트

PROject/AI_Tools/Claude/Claude and Claude code.md의 해당 섹션에 새 도구를 추가한다.

형식:
```
- [도구명](URL) — 한 줄 설명 #tag
```

## 5단계: 결과 보고

추가된 도구 목록을 사용자에게 보고한다:
- 새로 추가: (도구명, 분류, 3자 합의 여부)
- 이미 존재하여 스킵: (목록)
- 분류 불확실하여 Inbox에 추가: (목록, 각 AI 의견)
- 교차 검증에서 불일치한 항목: (Claude/Codex/Gemini 각 의견)
