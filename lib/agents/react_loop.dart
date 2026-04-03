import 'dart:async';
import '../models/research_task.dart';
import '../services/llm_service.dart';
import '../tools/tavily_search_tool.dart';
import '../tools/pdf_parser_tool.dart';
import '../tools/calculator_tool.dart';
import '../rag/vector_store.dart';
import '../rag/text_chunker.dart';

const _systemPrompt = '''
You are an autonomous research agent. You follow the ReAct (Reasoning + Acting) framework.

For each step, output EXACTLY one of:
THOUGHT: <your reasoning about what to do next>
ACTION: <tool_name>(<input>)
OBSERVATION: <will be filled by the system>
REPORT: <final markdown report when done>

Available tools:
- web_search(query): Search the web for information using Tavily
- pdf_parse(url_or_path): Extract text from a PDF document
- calculate(expression): Evaluate a mathematical expression
- vector_search(query): Search the knowledge base for relevant documents
- store_document(content|||metadata): Store a document in the knowledge base

Rules:
1. Always start with a THOUGHT about your research plan
2. Use web_search to find relevant papers and information
3. Store important findings in the knowledge base using store_document
4. Use vector_search to retrieve stored knowledge when synthesizing
5. When you have enough information, output REPORT with a complete markdown report
6. Include proper citations with URLs in [title](url) format
7. The report must include: Introduction, Key Findings, Analysis, Conclusion, References
8. Write the report in the SAME LANGUAGE as the user's query
9. You have up to 15 action steps - use them wisely
10. Each THOUGHT should be followed by exactly one ACTION
11. After receiving an OBSERVATION, always respond with a new THOUGHT
''';

class ReActLoop {
  final LlmService llm;
  final TavilySearchTool webSearch;
  final PdfParserTool pdfParser;
  final CalculatorTool calculator;
  final VectorStore vectorStore;
  final TextChunker chunker;
  final int maxSteps;
  final Duration toolTimeout;

  ReActLoop({
    required this.llm,
    required this.webSearch,
    required this.pdfParser,
    required this.calculator,
    required this.vectorStore,
    TextChunker? chunker,
    this.maxSteps = 15,
    this.toolTimeout = const Duration(seconds: 30),
  }) : chunker = chunker ?? const TextChunker();

  /// ReAct 루프 실행 - 각 단계를 스트리밍으로 반환
  Stream<AgentStep> execute(String topic) async* {
    final messages = <LlmMessage>[
      const LlmMessage(role: 'system', content: _systemPrompt),
      LlmMessage(
        role: 'user',
        content: '연구 주제: $topic\n\n'
            '이 주제에 대해 체계적으로 조사하고 출처가 포함된 종합 보고서를 작성해주세요.',
      ),
    ];

    var actionCount = 0;

    for (var step = 0; step < maxSteps * 2; step++) {
      // LLM에게 다음 단계 요청
      final response = await llm.complete(messages, temperature: 0.3);
      messages.add(LlmMessage(role: 'assistant', content: response));

      // REPORT 체크 (최우선)
      if (response.contains('REPORT:')) {
        final reportStart = response.indexOf('REPORT:');
        final reportContent = response.substring(reportStart + 7).trim();

        // REPORT 이전에 THOUGHT가 있으면 먼저 yield
        final beforeReport = response.substring(0, reportStart);
        final thoughtMatch = RegExp(r'THOUGHT:\s*(.+)', multiLine: true).firstMatch(beforeReport);
        if (thoughtMatch != null) {
          yield AgentStep(
            type: 'thought',
            content: thoughtMatch.group(1)!.trim(),
            timestamp: DateTime.now(),
          );
        }

        yield AgentStep(
          type: 'report',
          content: reportContent,
          timestamp: DateTime.now(),
        );
        return;
      }

      // 응답 파싱 - THOUGHT와 ACTION 쌍을 추출
      final thoughtMatch = RegExp(r'THOUGHT:\s*(.+)', multiLine: true).firstMatch(response);
      final actionMatch = RegExp(r'ACTION:\s*(.+)', multiLine: true).firstMatch(response);

      if (thoughtMatch != null) {
        yield AgentStep(
          type: 'thought',
          content: thoughtMatch.group(1)!.trim(),
          timestamp: DateTime.now(),
        );
      }

      if (actionMatch != null) {
        actionCount++;
        if (actionCount > maxSteps) break;

        final actionStr = actionMatch.group(1)!.trim();
        final toolName = _extractToolName(actionStr);

        yield AgentStep(
          type: 'action',
          content: actionStr,
          timestamp: DateTime.now(),
          toolName: toolName,
        );

        // 도구 실행 (타임아웃 포함)
        final observation = await _executeToolWithTimeout(actionStr);

        yield AgentStep(
          type: 'observation',
          content: observation,
          timestamp: DateTime.now(),
          toolName: toolName,
        );

        // 관찰 결과를 대화에 추가
        messages.add(LlmMessage(
          role: 'user',
          content: 'OBSERVATION: $observation',
        ));
      } else if (thoughtMatch == null) {
        // THOUGHT도 ACTION도 REPORT도 없으면 다시 시도 유도
        messages.add(const LlmMessage(
          role: 'user',
          content: '응답 형식이 올바르지 않습니다. THOUGHT, ACTION, 또는 REPORT 중 하나로 시작해주세요.',
        ));
      }
    }

    // 최대 단계 도달 시 강제 보고서 생성
    messages.add(const LlmMessage(
      role: 'user',
      content: '최대 단계에 도달했습니다. 지금까지 수집한 정보를 바탕으로 즉시 REPORT를 작성해주세요.',
    ));

    final finalResponse = await llm.complete(messages, temperature: 0.3);
    final reportStart = finalResponse.indexOf('REPORT:');
    final reportContent = reportStart != -1
        ? finalResponse.substring(reportStart + 7).trim()
        : finalResponse;

    yield AgentStep(
      type: 'report',
      content: reportContent,
      timestamp: DateTime.now(),
    );
  }

  String _extractToolName(String action) {
    final parenIdx = action.indexOf('(');
    if (parenIdx == -1) return action;
    return action.substring(0, parenIdx).trim();
  }

  String _extractToolInput(String action) {
    final start = action.indexOf('(');
    final end = action.lastIndexOf(')');
    if (start == -1 || end == -1 || end <= start) return action;
    return action.substring(start + 1, end).trim();
  }

  Future<String> _executeToolWithTimeout(String action) async {
    try {
      return await _executeTool(action).timeout(
        toolTimeout,
        onTimeout: () => '도구 실행 타임아웃 (${toolTimeout.inSeconds}초 초과)',
      );
    } catch (e) {
      return '도구 실행 오류: $e';
    }
  }

  Future<String> _executeTool(String action) async {
    final toolName = _extractToolName(action);
    final input = _extractToolInput(action);

    return switch (toolName) {
      'web_search'     => await webSearch.run(input),
      'pdf_parse'      => await pdfParser.run(input),
      'calculate'      => calculator.run(input),
      'vector_search'  => await _vectorSearch(input),
      'store_document' => await _storeDocument(input),
      _                => '알 수 없는 도구: $toolName. 사용 가능한 도구: web_search, pdf_parse, calculate, vector_search, store_document',
    };
  }

  Future<String> _vectorSearch(String query) async {
    final results = await vectorStore.search(query, topK: 3);
    if (results.isEmpty) return '관련 문서를 찾을 수 없습니다.';
    final buf = StringBuffer();
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      buf.writeln('[${i + 1}] (점수: ${r.score.toStringAsFixed(3)})');
      buf.writeln(r.document.content);
      if (r.document.metadata.isNotEmpty) {
        buf.writeln('메타데이터: ${r.document.metadata}');
      }
      buf.writeln('---');
    }
    return buf.toString();
  }

  Future<String> _storeDocument(String input) async {
    final parts = input.split('|||');
    final content = parts[0].trim();
    final metadata = parts.length > 1 ? {'source': parts[1].trim()} : <String, dynamic>{};

    // 긴 문서는 청킹하여 저장
    final chunks = chunker.split(content, metadata: metadata);

    if (chunks.length > 1) {
      final docs = chunks
          .map((c) => VectorDocument(
                id: '${DateTime.now().millisecondsSinceEpoch}_${c.index}',
                content: c.content,
                metadata: {...c.metadata, ...metadata},
              ))
          .toList();
      await vectorStore.addDocuments(docs);
      return '문서가 ${chunks.length}개 청크로 분할되어 벡터 DB에 저장되었습니다.';
    }

    await vectorStore.addDocuments([
      VectorDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        metadata: metadata,
      ),
    ]);
    return '문서가 벡터 DB에 저장되었습니다.';
  }
}
