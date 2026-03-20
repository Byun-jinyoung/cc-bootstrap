---
name: paper-analyzer
description: 연구 논문을 체계적으로 분석하는 skill. 사용자가 논문 분석, paper analysis, 논문 리뷰를 요청하거나, PDF 파일 경로가 제공될 때 이 skill을 사용한다.
---

# Paper Analyzer

연구 논문 PDF를 직접 읽고 분석하여 구조화된 노트를 생성한다.

## PDF 읽기 (pdfplumber + pdf2image)

PDF 경로가 주어지면, run_shell_command로 Python을 실행하여 텍스트와 Figure를 직접 추출하라.

### 텍스트 추출
```bash
python3 -c "
import pdfplumber
with pdfplumber.open('paper.pdf') as pdf:
    for i, page in enumerate(pdf.pages):
        text = page.extract_text()
        if text:
            print(f'--- PAGE {i+1} ---')
            print(text)
"
```
- 장점: 빠름, 테이블 구조 추출
- 한계: Figure 내용 못 봄, 수식 깨짐 가능

### Figure 이미지 변환
```bash
python3 -c "
from pdf2image import convert_from_path
images = convert_from_path('paper.pdf', dpi=150)
for i, img in enumerate(images):
    img.save(f'paper_page_{i+1}.png')
    print(f'Saved: paper_page_{i+1}.png')
"
```
- Figure가 있는 페이지를 이미지로 변환
- 변환된 이미지는 workspace 내에 저장하여 read_file로 확인

### 사용 기준
- 본문 텍스트 → pdfplumber (shell command)
- Figure/수식 확인 → pdf2image로 이미지 변환 후 read_file
- Table 추출 → pdfplumber `extract_tables()`

텍스트 파일(.txt)이 이미 제공된 경우, 추출 단계를 건너뛰고 바로 분석하라.

## 분석 원칙

1. **사실과 추론을 분리**: 데이터에서 관찰된 내용(사실)과 해석(추론)을 명확히 구분
2. **확정 표현 제한**: 사실/측정값은 단정 가능. 해석에 한하여 "~로 보인다", "~일 가능성" 사용
3. **근거 필수 제시**: 모든 결론에 논리적 근거 + 대안 가설 제시
4. **불확실성 명시**: 신뢰도 수준(높음/중간/낮음) 포함
5. **증거 위치 필수**: 모든 핵심 데이터에 Figure/Table/Page 번호 명시
6. **모르면 모른다고 답변**: 아는 척 금지, 근거 없는 추측 금지

## 분석 절차

1. PDF에서 텍스트 추출 (pdfplumber) + Figure 페이지 이미지 변환 (pdf2image)
2. 논문 구조 파악 (Abstract, Introduction, Methods, Results, Discussion)
3. Figure 이미지를 read_file로 확인하여 그래프/표/다이어그램 해석
4. 아래 출력 형식에 따라 분석 결과 작성

## 출력 형식

반드시 아래 구조를 따를 것:

```
## 한 줄 요약
(논문 핵심을 한 문장으로)

## 방법론

### 핵심 로직
- 문제 정의:
- 핵심 아이디어:
- 왜 이 접근이 유효한가:

### 방법론 흐름
| 단계 | 목적 | 핵심 방법 | 산출물 | 증거 (Figure/Page) |

### 방법 상세
(단계별 조건/파라미터, 소프트웨어, 통계 처리, 주의사항)

## 결과 카드
(핵심 결과마다 반복)

### 결과 N: (제목)
**배경 & 질문** -
**방법 요약** -
**핵심 데이터 (사실)** — Figure/Table/Page:
**해석 (추론)** — 신뢰도: 높음/중간/낮음
- 근거:
- 대안 가설:
**결론** -

## 한계점 & 미비 사항
## Reference Trail
| 핵심 결과 | 본문 페이지 | Figure/Table/Supplement |
```
