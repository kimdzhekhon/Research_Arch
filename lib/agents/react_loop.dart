import 'dart:async';
import '../models/research_task.dart';
import '../services/llm_service.dart';
import '../tools/tavily_search_tool.dart';
import '../tools/pdf_parser_tool.dart';
import '../tools/calculator_tool.dart';
import '../rag/vector_store.dart';

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
3. Store important findings in the knowledge base
4. Use vector_search to retrieve stored knowledge
5. When you have enough information, output REPORT with a complete markdown report
6. Include proper citations with URLs
7. The report should be comprehensive with sections: Introduction, Key Findings, Analysis, Conclusion, References
8. Write the report in the SAME LANGUAGE as the user's query
9. Maximum 10 action steps before writing the report
''';

class ReActLoop {
  final LlmService llm;
  final TavilySearchTool webSearch;
  final PdfParserTool pdfParser;
  final CalculatorTool calculator;
  final VectorStore vectorStore;
  final int maxSteps;

  ReActLoop({
    required this.llm,
    required this.webSearch,
    required this.pdfParser,
    required this.calculator,
    required this.vectorStore,
    this.maxSteps = 10,
  });

  /// ReAct 루프 실행 - 각 단계를 스트리밍으로 반환
  Stream<AgentStep> execute(String topic) async* {
    final messages = <LlmMessage>[
      LlmMessage(role: 'system', content: _systemPrompt),
      LlmMessage(role: 'user', content: '연구 주제: $topic\n\n이 주제에 대해 체계적으로 조사하고 출처가 포함된 종합 보고서를 작성해주세요.'),
    ];

    for (var step = 0; step < maxSteps; step++) {
      // LLM에게 다음 단계 요청
      final response = await llm.complete(messages, temperature: 0.3);
      messages.add(LlmMessage(role: 'assistant', content: response));

      // 응답 파싱
      final lines = response.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();

        if (trimmed.startsWith('THOUGHT:')) {
          yield AgentStep(
            type: 'thought',
            content: trimmed.substring(8).trim(),
            timestamp: DateTime.now(),
          );
        } else if (trimmed.startsWith('ACTION:')) {
          final actionStr = trimmed.substring(7).trim();
          yield AgentStep(
            type: 'action',
            content: actionStr,
            timestamp: DateTime.now(),
            toolName: _extractToolName(actionStr),
          );

          // 도구 실행
          final observation = await _executeTool(actionStr);
          yield AgentStep(
            type: 'observation',
            content: observation,
            timestamp: DateTime.now(),
            toolName: _extractToolName(actionStr),
          );

          // 관찰 결과를 대화에 추가
          messages.add(LlmMessage(
            role: 'user',
            content: 'OBSERVATION: $observation',
          ));
        } else if (trimmed.startsWith('REPORT:') || response.contains('REPORT:')) {
          final reportStart = response.indexOf('REPORT:');
          if (reportStart != -1) {
            final reportContent = response.substring(reportStart + 7).trim();
            yield AgentStep(
              type: 'report',
              content: reportContent,
              timestamp: DateTime.now(),
            );
            return; // 보고서가 생성되면 루프 종료
          }
        }
      }
    }

    // 최대 단계 도달 시 강제 보고서 생성
    messages.add(LlmMessage(
      role: 'user',
      content: '최대 단계에 도달했습니다. 지금까지 수집한 정보를 바탕으로 REPORT를 작성해주세요.',
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

  Future<String> _executeTool(String action) async {
    final toolName = _extractToolName(action);
    final input = _extractToolInput(action);

    try {
      return switch (toolName) {
        'web_search'      => await webSearch.run(input),
        'pdf_parse'       => await pdfParser.run(input),
        'calculate'       => calculator.run(input),
        'vector_search'   => await _vectorSearch(input),
        'store_document'  => await _storeDocument(input),
        _                 => '알 수 없는 도구: $toolName',
      };
    } catch (e) {
      return '도구 실행 오류 ($toolName): $e';
    }
  }

  Future<String> _vectorSearch(String query) async {
    final results = await vectorStore.search(query, topK: 3);
    if (results.isEmpty) return '관련 문서를 찾을 수 없습니다.';
    final buf = StringBuffer();
    for (final r in results) {
      buf.writeln('[점수: ${r.score.toStringAsFixed(3)}] ${r.document.content}');
      buf.writeln('---');
    }
    return buf.toString();
  }

  Future<String> _storeDocument(String input) async {
    final parts = input.split('|||');
    final content = parts[0].trim();
    final metadata = parts.length > 1 ? {'source': parts[1].trim()} : <String, dynamic>{};

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
