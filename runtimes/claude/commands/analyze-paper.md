---
description: PDF 논문을 분석하고 Codex/Gemini와 교차 검증하여 Obsidian 노트를 생성한다.
---

# 논문 분석 및 교차 검증

사용자가 제공한 PDF 논문을 분석하고, Codex + Gemini와 교차 검증하여 최종 노트를 생성하라.

## 0단계: 디렉토리 생성

PDF 경로에서 논문 대표 이름(method명 또는 짧은 키워드)을 추출하여 Paper/ 아래에 개별 디렉토리를 생성하라.

```
PROject/Paper/{논문대표이름}/
├── {원본파일명}.pdf          ← PDF 원본 (이동 또는 복사)
├── {논문대표이름}_analysis.md ← 분석 노트 (최종 산출물)
└── {논문대표이름}_text.txt    ← 추출 텍스트 (Codex/Gemini용)
```

PDF가 이미 Paper/ 폴더에 있으면 이동, 외부 경로면 복사하라.

## 1단계: PDF 텍스트 및 Figure 추출

```python
import pdfplumber
from pdf2image import convert_from_path
import os

pdf_path = "$ARGUMENTS"  # 사용자가 전달한 PDF 경로

# 디렉토리 설정
paper_dir = "PROject/Paper/{논문대표이름}"  # 0단계에서 결정한 경로
os.makedirs(paper_dir, exist_ok=True)

# 텍스트 추출
with pdfplumber.open(pdf_path) as pdf:
    full_text = ""
    for i, page in enumerate(pdf.pages):
        text = page.extract_text()
        if text:
            full_text += f"--- PAGE {i+1} ---\n{text}\n\n"

# 텍스트를 디렉토리 내에 저장
text_path = os.path.join(paper_dir, "{논문대표이름}_text.txt")
with open(text_path, "w") as f:
    f.write(full_text)

# Figure 페이지 이미지 변환
images = convert_from_path(pdf_path, dpi=150)
figure_paths = []
for i, img in enumerate(images):
    fig_path = f"/tmp/paper_page_{i+1}.png"
    img.save(fig_path)
    figure_paths.append(fig_path)
```

위 코드를 실행하여 텍스트와 Figure 이미지를 추출하라.

## 2단계: 3자 독립 분석 (Claude + Codex + Gemini 병렬)

### 2a: Claude 독립 분석

추출한 텍스트와 Figure 이미지를 읽고, 아래 템플릿 형식으로 분석하라.

**분석 원칙:**
1. **사실과 추론을 분리**: 관찰 사실과 해석을 명확히 구분
2. **확정 표현 제한**: 해석/추론에 한하여 "~로 보인다", "~일 가능성" 등 사용. 사실/측정값은 단정 가능
3. **근거 필수 제시**: 모든 결론에 논리적 근거 + 대안 가설 제시
4. **불확실성 명시**: 신뢰도 수준(높음/중간/낮음) 포함
5. **증거 위치 필수**: Figure/Table/Page 번호 명시

**출력 형식:** PROject/Templates/Paper_Note 템플릿.md 형식을 따르라. 핵심 섹션:
- 한 줄 요약
- 방법론 (핵심 로직, Flow Chart(mermaid), 흐름 테이블, 방법 상세)
- 결과 카드 (배경&질문, 방법요약, 핵심데이터(사실), 해석(추론)+신뢰도, 결론)
- 한계점 & 미비 사항
- Reference Trail

Claude 분석 결과를 `PROject/Paper/{논문대표이름}/claude_analysis.md`에 저장하라.
**중요: /tmp가 아닌 논문 디렉토리에 저장.**

### 2b: Codex 독립 분석

Bash로 codex exec를 호출. Codex에 ~/.codex/skills/paper-analyzer/ skill이 설치되어 있다.

```bash
codex exec \
  -i /tmp/paper_page_*.png \
  --full-auto \
  "paper-analyzer skill을 사용하여 논문을 분석하라.
텍스트 파일: {text_path}
첨부 이미지: Figure 페이지들

전체 분석을 수행하라:
- 한 줄 요약
- 방법론 (핵심 로직, 방법론 흐름 테이블, 방법 상세)
- 결과 카드 (모든 핵심 결과)
- 한계점 & 미비 사항
- Reference Trail

결과를 PROject/Paper/{논문대표이름}/codex_analysis.md 파일로 저장하라."
```

### 2c: Gemini 독립 분석

mcp__gemini-mcp__ask_gemini를 호출. Gemini에 paper-analyzer skill이 설치되어 있다.
Gemini는 workspace 내 파일만 읽을 수 있으므로, text_path는 반드시 PROject/Paper/ 아래 경로를 사용.

```
mcp__gemini-mcp__ask_gemini 호출:
  prompt: "paper-analyzer skill을 사용하여 논문을 분석하라.
    텍스트 파일: {text_path} (workspace 내 경로)
    전체 분석을 수행하라.
    결과를 PROject/Paper/{논문대표이름}/gemini_analysis.md로 저장하라."
  working_directory: PROject 경로
```

**Gemini 제약 사항:**
- workspace 외부 파일 접근 불가 → text_path는 PROject/Paper/ 내 경로 사용
- 이미지 파일 첨부 파라미터 없음 → 텍스트 기반 분석만 수행
- Figure 내용은 텍스트의 Figure 캡션에 의존

**3자를 가능한 한 병렬로 실행**하라 (Agent 백그라운드 + Bash + mcp 동시 호출).

## 3단계: 교차 검증

Claude 분석(2a), Codex 분석(2b), Gemini 분석(2c)을 비교하라:

1. **사실 불일치**: 같은 데이터에 대해 다른 수치/해석을 제시한 부분
2. **누락 차이**: 한쪽만 언급한 핵심 결과나 한계점
3. **해석 차이**: 동일 데이터에 대한 다른 추론 (어느 쪽이 더 근거가 강한지 판단)
4. **Figure 의존성**: Codex가 Figure를 보고 추가로 파악한 내용 (Gemini는 Figure 미참조)
5. **3자 일치 항목**: 세 AI 모두 동의하는 내용은 신뢰도 높음으로 표시

차이점 목록을 작성하라.

## 4단계: 최종 노트 작성

3단계의 차이점을 반영하여 최종 분석 노트를 {논문대표이름} 디렉토리에 저장하라.
노트 하단에 교차 검증 결과 섹션을 추가하라:

```markdown
## 교차 검증 결과
- 검증 방법: Claude (모델명) + Codex (모델명) + Gemini (모델명) 독립 분석 → 3자 비교
- 사실 불일치: (있으면 기술)
- 3자 일치 사항: (세 AI 모두 동의한 핵심 내용)
- 추가 반영 사항: (각 AI에서 반영한 내용과 출처)
- 미반영 사항 및 이유: (반영하지 않은 의견과 그 이유)
```

최종 산출물:
```
PROject/Paper/{논문대표이름}/
├── {원본}.pdf
├── {논문대표이름}_analysis.md   ← 최종 분석 노트
└── {논문대표이름}_text.txt      ← 추출 텍스트
```
