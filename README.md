# ResearchArch

**자율적 AI 연구 에이전트** - 주제를 입력하면 스스로 논문을 찾고, 분석하고, 출처가 포함된 마크다운 보고서를 작성하는 Flutter 앱

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.41+-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart" alt="Dart">
  <img src="https://img.shields.io/badge/LangChain.dart-0.7+-green" alt="LangChain">
  <img src="https://img.shields.io/badge/Qdrant-HNSW-DC382D" alt="Qdrant">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License">
</p>

---

## Overview

ResearchArch는 **ReAct (Reasoning + Acting) 프레임워크** 기반의 자율 연구 에이전트입니다.
사용자가 연구 주제를 입력하면, 에이전트가 스스로 계획을 수립하고 웹 검색, PDF 분석, 벡터 DB 검색을 수행한 뒤 종합 보고서를 자동 생성합니다.

```
사용자 입력 → [계획 수립] → [웹 검색] → [문서 분석] → [RAG 저장/검색] → [보고서 작성]
     ↑                                                                    |
     └──────────────────── ReAct Loop (최대 15단계) ──────────────────────┘
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Dashboard                       │
│  ┌──────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ Research  │  │    Progress      │  │    Report        │  │
│  │ Input     │  │    Timeline      │  │    Viewer        │  │
│  └─────┬────┘  └────────▲─────────┘  └────────▲─────────┘  │
│        │               │                      │             │
│        ▼               │                      │             │
│  ┌─────────────────────┴──────────────────────┘             │
│  │              Riverpod State Management                   │
│  └─────────────────────┬────────────────────────            │
├────────────────────────┼────────────────────────────────────┤
│                  Agent Layer                                │
│  ┌─────────────────────▼────────────────────────┐           │
│  │            ResearchAgent                      │          │
│  │  ┌────────────────────────────────────────┐  │          │
│  │  │         ReAct Loop Engine              │  │          │
│  │  │   THOUGHT → ACTION → OBSERVATION      │  │          │
│  │  │         (with retry & timeout)         │  │          │
│  │  └──────┬──────┬──────┬──────┬────────────┘  │          │
│  └─────────┼──────┼──────┼──────┼───────────────┘          │
│            │      │      │      │                           │
│  ┌─────────▼┐ ┌──▼───┐ ┌▼────┐ ┌▼──────────┐              │
│  │ Tavily   │ │ PDF  │ │Calc │ │ Vector    │              │
│  │ Search   │ │Parser│ │     │ │ Search    │              │
│  └──────────┘ └──────┘ └─────┘ └─────┬─────┘              │
│                                       │                     │
├───────────────────────────────────────┼─────────────────────┤
│                  RAG Pipeline         │                     │
│  ┌────────────────┐  ┌───────────────▼──────────────────┐  │
│  │ Text Chunker   │  │ Qdrant Vector DB                 │  │
│  │ (Recursive     │  │ ┌─────────────────────────────┐  │  │
│  │  Splitting)    │──▶│ │ HNSW Index                  │  │  │
│  └────────────────┘  │ │ m=16, ef_construct=200       │  │  │
│  ┌────────────────┐  │ │ Cosine Similarity            │  │  │
│  │ OpenAI         │  │ └─────────────────────────────┘  │  │
│  │ Embeddings     │──▶│                                  │  │
│  │ (ada-3-small)  │  └──────────────────────────────────┘  │
│  └────────────────┘                                        │
└────────────────────────────────────────────────────────────┘
```

## Features

| Feature | Description |
|---------|-------------|
| **ReAct Agent** | 사고-행동-관찰 자율 루프 (최대 15단계, 자동 재시도) |
| **Web Search** | Tavily API 기반 고급 웹 검색 (논문, 블로그, 뉴스) |
| **PDF Parser** | URL/로컬 PDF에서 텍스트 자동 추출 |
| **Calculator** | 수학 표현식 평가 (삼각함수, 로그, 거듭제곱 지원) |
| **RAG Pipeline** | Qdrant HNSW 벡터 인덱싱 + 재귀적 텍스트 청킹 |
| **Streaming UI** | 실시간 진행 타임라인 + 마크다운 보고서 렌더링 |
| **Theme** | 시스템 연동 다크/라이트 모드 + 수동 토글 |
| **Error Resilience** | 지수 백오프 재시도, 도구 실행 타임아웃 |
| **History** | 연구 이력 관리 및 보고서 재열람 |

## Tech Stack

- **Framework**: Flutter 3.41+ / Dart 3.11+
- **Agent**: LangChain.dart (langchain, langchain_openai, langchain_community)
- **LLM**: OpenAI GPT-4o (스트리밍 지원)
- **Embeddings**: text-embedding-3-small (1536차원)
- **Vector DB**: Qdrant (HNSW 인덱싱, Cosine similarity)
- **State**: Riverpod 2.x (StateNotifier)
- **UI**: Material 3, flutter_markdown, animated_text_kit

## Getting Started

### Prerequisites

- Flutter 3.41+ / Dart 3.11+
- [OpenAI API Key](https://platform.openai.com/api-keys)
- [Tavily API Key](https://tavily.com)
- Docker (Qdrant 실행용)

### 1. Clone & Install

```bash
git clone https://github.com/kimdzhekhon/Research_Arch.git
cd Research_Arch
flutter pub get
```

### 2. Start Qdrant (Docker)

```bash
docker run -d --name qdrant \
  -p 6333:6333 -p 6334:6334 \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant
```

### 3. Run the App

```bash
# Web
flutter run -d chrome \
  --dart-define=OPENAI_API_KEY=sk-your-key \
  --dart-define=TAVILY_API_KEY=tvly-your-key \
  --dart-define=QDRANT_URL=http://localhost:6333

# macOS
flutter run -d macos \
  --dart-define=OPENAI_API_KEY=sk-your-key \
  --dart-define=TAVILY_API_KEY=tvly-your-key

# iOS / Android
flutter run \
  --dart-define=OPENAI_API_KEY=sk-your-key \
  --dart-define=TAVILY_API_KEY=tvly-your-key
```

### Quick Setup (Shell Script)

```bash
chmod +x setup_research_agent.sh
bash setup_research_agent.sh
```

## Project Structure

```
lib/
├── main.dart                      # App entry point (Riverpod + M3)
├── config/
│   └── app_config.dart            # API keys via --dart-define
├── agents/
│   ├── research_agent.dart        # Autonomous research agent
│   └── react_loop.dart            # ReAct loop engine
├── tools/
│   ├── tavily_search_tool.dart    # Web search (Tavily API)
│   ├── pdf_parser_tool.dart       # PDF text extraction
│   └── calculator_tool.dart       # Math expression evaluator
├── rag/
│   ├── vector_store.dart          # Qdrant client (HNSW)
│   ├── embeddings_service.dart    # OpenAI embeddings
│   └── text_chunker.dart          # Recursive text splitter
├── models/
│   ├── research_task.dart         # Task & AgentStep models
│   └── research_report.dart       # Report model
├── services/
│   ├── llm_service.dart           # LLM service (streaming + retry)
│   └── research_provider.dart     # Riverpod providers
├── screens/
│   └── dashboard_screen.dart      # Main dashboard
└── widgets/
    ├── research_input.dart        # Topic input card
    ├── progress_timeline.dart     # Real-time step timeline
    ├── report_viewer.dart         # Markdown report renderer
    └── stats_panel.dart           # Research statistics panel
```

## How the ReAct Loop Works

```
Step 1: THOUGHT - "이 주제를 조사하려면 먼저 최신 논문을 검색해야 한다"
Step 2: ACTION  - web_search("LLM reasoning capabilities 2024 survey")
Step 3: OBSERVATION - [검색 결과 5건: 논문 제목, URL, 요약...]
Step 4: THOUGHT - "핵심 논문 3개를 찾았다. 벡터 DB에 저장하고 추가 검색하자"
Step 5: ACTION  - store_document(논문 요약|||출처 URL)
Step 6: OBSERVATION - "문서가 벡터 DB에 저장되었습니다"
  ...
Step N: REPORT  - # 종합 보고서 (마크다운 + 출처 포함)
```

## Configuration

| Environment Variable | Description | Required |
|---------------------|-------------|----------|
| `OPENAI_API_KEY` | OpenAI API 키 | Yes |
| `TAVILY_API_KEY` | Tavily 검색 API 키 | Yes |
| `QDRANT_URL` | Qdrant 서버 URL (기본: `http://localhost:6333`) | No |
| `QDRANT_API_KEY` | Qdrant 인증 키 (클라우드 사용 시) | No |

## RAG Pipeline Details

### HNSW Indexing Configuration

```dart
'hnsw_config': {
  'm': 16,                // 그래프 연결 수 (정확도 ↑, 메모리 ↑)
  'ef_construct': 200,    // 구축 시 탐색 범위 (정확도 ↑, 구축 시간 ↑)
}
// 검색 시: hnsw_ef = 128 (검색 정확도 vs 속도 균형)
```

### Text Chunking Strategy

재귀적 텍스트 분할 (Recursive Character Text Splitter):
- **Chunk Size**: 500 tokens
- **Overlap**: 50 tokens
- **Separators**: `\n\n` → `\n` → `. ` → ` ` (우선순위)

## License

MIT License - see [LICENSE](LICENSE) for details.
