import 'dart:async';
import '../models/research_task.dart';
import '../models/research_report.dart';
import '../services/llm_service.dart';
import '../tools/tavily_search_tool.dart';
import '../tools/pdf_parser_tool.dart';
import '../tools/calculator_tool.dart';
import '../rag/vector_store.dart';
import '../rag/embeddings_service.dart';
import 'react_loop.dart';

/// 자율적 연구 에이전트 - 전체 파이프라인 관리
class ResearchAgent {
  final LlmService _llm;
  final TavilySearchTool _webSearch;
  final PdfParserTool _pdfParser;
  final CalculatorTool _calculator;
  final VectorStore _vectorStore;
  final EmbeddingsService _embeddings;

  late final ReActLoop _reactLoop;

  ResearchAgent({
    required LlmService llm,
    required TavilySearchTool webSearch,
    required PdfParserTool pdfParser,
    required CalculatorTool calculator,
    required VectorStore vectorStore,
    required EmbeddingsService embeddings,
  })  : _llm = llm,
        _webSearch = webSearch,
        _pdfParser = pdfParser,
        _calculator = calculator,
        _vectorStore = vectorStore,
        _embeddings = embeddings {
    _reactLoop = ReActLoop(
      llm: _llm,
      webSearch: _webSearch,
      pdfParser: _pdfParser,
      calculator: _calculator,
      vectorStore: _vectorStore,
    );
  }

  /// 팩토리 생성자 - 기본 설정으로 에이전트 생성
  factory ResearchAgent.create({
    String? openAiApiKey,
    String? tavilyApiKey,
    String? qdrantUrl,
  }) {
    final llm = LlmService(apiKey: openAiApiKey);
    final webSearch = TavilySearchTool(apiKey: tavilyApiKey);
    final pdfParser = PdfParserTool();
    final calculator = CalculatorTool();
    final embeddings = EmbeddingsService(apiKey: openAiApiKey);
    final vectorStore = VectorStore(
      baseUrl: qdrantUrl,
      embeddings: embeddings,
    );

    return ResearchAgent(
      llm: llm,
      webSearch: webSearch,
      pdfParser: pdfParser,
      calculator: calculator,
      vectorStore: vectorStore,
      embeddings: embeddings,
    );
  }

  /// 벡터 DB 초기화
  Future<void> initialize() async {
    try {
      await _vectorStore.createCollection();
    } catch (_) {
      // 컬렉션이 이미 존재하면 무시
    }
  }

  /// 연구 실행 - ResearchTask 스트림 반환
  Stream<ResearchTask> research(String topic) async* {
    var task = ResearchTask(topic: topic, status: TaskStatus.planning);
    yield task;

    final allSteps = <AgentStep>[];

    await for (final step in _reactLoop.execute(topic)) {
      allSteps.add(step);

      // 상태 업데이트
      TaskStatus newStatus;
      double progress;

      switch (step.type) {
        case 'thought':
          newStatus = TaskStatus.planning;
          progress = (allSteps.length / 20).clamp(0.0, 0.4);
        case 'action':
          newStatus = step.toolName == 'web_search'
              ? TaskStatus.searching
              : TaskStatus.analyzing;
          progress = (allSteps.length / 20).clamp(0.1, 0.7);
        case 'observation':
          newStatus = TaskStatus.analyzing;
          progress = (allSteps.length / 20).clamp(0.2, 0.8);
        case 'report':
          newStatus = TaskStatus.writing;
          progress = 0.9;
        default:
          newStatus = task.status;
          progress = task.progress;
      }

      task = task.copyWith(
        status: newStatus,
        steps: List.from(allSteps),
        progress: progress,
        report: step.type == 'report' ? step.content : task.report,
      );
      yield task;
    }

    // 완료
    task = task.copyWith(
      status: TaskStatus.completed,
      progress: 1.0,
    );
    yield task;
  }

  /// 보고서 파싱
  ResearchReport? parseReport(ResearchTask task) {
    if (task.report == null) return null;

    final content = task.report!;
    final lines = content.split('\n');
    String title = task.topic;
    String summary = '';

    for (final line in lines) {
      if (line.startsWith('# ')) {
        title = line.substring(2).trim();
        break;
      }
    }

    // 요약 추출
    final summaryMatch = RegExp(r'>\s*(.+)', multiLine: true).firstMatch(content);
    if (summaryMatch != null) {
      summary = summaryMatch.group(1) ?? '';
    }

    // 출처 추출
    final sources = <Source>[];
    final sourcePattern = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    for (final match in sourcePattern.allMatches(content)) {
      sources.add(Source(
        title: match.group(1) ?? '',
        url: match.group(2) ?? '',
        snippet: '',
      ));
    }

    return ResearchReport(
      title: title,
      summary: summary,
      markdownBody: content,
      sources: sources,
      generatedAt: DateTime.now(),
    );
  }

  void dispose() {
    _llm.dispose();
    _webSearch.dispose();
    _pdfParser.dispose();
    _vectorStore.dispose();
    _embeddings.dispose();
  }
}
