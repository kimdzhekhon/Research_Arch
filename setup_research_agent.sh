#!/bin/bash
set -e

echo "============================================"
echo "  ResearchArch - 자율적 연구 에이전트 셋업"
echo "============================================"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# ─────────────────────────────────────────────
# 1. 디렉토리 구조 생성
# ─────────────────────────────────────────────
echo ""
echo "[1/4] 디렉토리 구조 생성 중..."

mkdir -p lib/config
mkdir -p lib/agents
mkdir -p lib/tools
mkdir -p lib/rag
mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/screens
mkdir -p lib/widgets
mkdir -p assets

echo "  ✓ 디렉토리 구조 완료"

# ─────────────────────────────────────────────
# 2. pubspec.yaml 업데이트
# ─────────────────────────────────────────────
echo ""
echo "[2/4] pubspec.yaml 업데이트 중..."

cat > pubspec.yaml << 'PUBSPEC_EOF'
name: researcharch
description: "ResearchArch - 자율적 AI 연구 에이전트"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.11.1

dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8

  # LangChain Dart
  langchain: ^0.7.6
  langchain_openai: ^0.7.2
  langchain_community: ^0.3.2

  # HTTP & Networking
  http: ^1.2.2
  dio: ^5.7.0

  # Vector DB
  qdrant: ^1.0.1+1

  # Utilities
  uuid: ^4.5.1
  equatable: ^2.0.7
  intl: ^0.20.1
  json_annotation: ^4.9.0
  path: ^1.9.1

  # State Management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # UI
  flutter_markdown: ^0.7.4+3
  google_fonts: ^6.2.1
  shimmer: ^3.0.0
  animated_text_kit: ^4.2.2
  fl_chart: ^0.70.2
  lottie: ^3.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.14
  json_serializable: ^6.9.4
  riverpod_generator: ^2.6.3

flutter:
  uses-material-design: true
  assets:
    - assets/
PUBSPEC_EOF

echo "  ✓ pubspec.yaml 업데이트 완료"

# ─────────────────────────────────────────────
# 3. Dart 소스 파일 생성
# ─────────────────────────────────────────────
echo ""
echo "[3/4] Dart 소스 파일 생성 중..."

# ──── config/app_config.dart ────
cat > lib/config/app_config.dart << 'DART_EOF'
/// API 키 및 앱 설정.
/// 실제 배포 시 환경변수 또는 --dart-define으로 주입하세요.
class AppConfig {
  static const String openAiApiKey =
      String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const String tavilyApiKey =
      String.fromEnvironment('TAVILY_API_KEY', defaultValue: '');
  static const String qdrantUrl =
      String.fromEnvironment('QDRANT_URL', defaultValue: 'http://localhost:6333');
  static const String qdrantApiKey =
      String.fromEnvironment('QDRANT_API_KEY', defaultValue: '');

  static const String defaultModel = 'gpt-4o';
  static const String embeddingModel = 'text-embedding-3-small';
  static const int embeddingDimension = 1536;
  static const String collectionName = 'research_documents';
}
DART_EOF

# ──── models/research_task.dart ────
cat > lib/models/research_task.dart << 'DART_EOF'
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum TaskStatus { idle, planning, searching, analyzing, writing, completed, error }

class AgentStep extends Equatable {
  final String type; // thought, action, observation
  final String content;
  final DateTime timestamp;
  final String? toolName;

  const AgentStep({
    required this.type,
    required this.content,
    required this.timestamp,
    this.toolName,
  });

  @override
  List<Object?> get props => [type, content, timestamp, toolName];
}

class ResearchTask extends Equatable {
  final String id;
  final String topic;
  final TaskStatus status;
  final List<AgentStep> steps;
  final String? report;
  final String? errorMessage;
  final DateTime createdAt;
  final double progress;

  ResearchTask({
    String? id,
    required this.topic,
    this.status = TaskStatus.idle,
    this.steps = const [],
    this.report,
    this.errorMessage,
    DateTime? createdAt,
    this.progress = 0.0,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  ResearchTask copyWith({
    TaskStatus? status,
    List<AgentStep>? steps,
    String? report,
    String? errorMessage,
    double? progress,
  }) {
    return ResearchTask(
      id: id,
      topic: topic,
      status: status ?? this.status,
      steps: steps ?? this.steps,
      report: report ?? this.report,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      progress: progress ?? this.progress,
    );
  }

  @override
  List<Object?> get props => [id, topic, status, steps, report, errorMessage, createdAt, progress];
}
DART_EOF

# ──── models/research_report.dart ────
cat > lib/models/research_report.dart << 'DART_EOF'
class Source {
  final String title;
  final String url;
  final String snippet;

  const Source({required this.title, required this.url, required this.snippet});
}

class ResearchReport {
  final String title;
  final String summary;
  final String markdownBody;
  final List<Source> sources;
  final DateTime generatedAt;

  const ResearchReport({
    required this.title,
    required this.summary,
    required this.markdownBody,
    required this.sources,
    required this.generatedAt,
  });

  String toFullMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# $title\n');
    buf.writeln('> $summary\n');
    buf.writeln(markdownBody);
    buf.writeln('\n---\n## 참고 문헌\n');
    for (var i = 0; i < sources.length; i++) {
      buf.writeln('${i + 1}. [${sources[i].title}](${sources[i].url})');
      buf.writeln('   - ${sources[i].snippet}\n');
    }
    buf.writeln('\n_Generated at: $generatedAt_');
    return buf.toString();
  }
}
DART_EOF

# ──── tools/tavily_search_tool.dart ────
cat > lib/tools/tavily_search_tool.dart << 'DART_EOF'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class TavilySearchResult {
  final String title;
  final String url;
  final String content;
  final double score;

  const TavilySearchResult({
    required this.title,
    required this.url,
    required this.content,
    required this.score,
  });

  factory TavilySearchResult.fromJson(Map<String, dynamic> json) {
    return TavilySearchResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      content: json['content'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
    );
  }
}

class TavilySearchTool {
  final String apiKey;
  final http.Client _client;

  TavilySearchTool({String? apiKey, http.Client? client})
      : apiKey = apiKey ?? AppConfig.tavilyApiKey,
        _client = client ?? http.Client();

  Future<List<TavilySearchResult>> search(
    String query, {
    int maxResults = 5,
    String searchDepth = 'advanced',
    bool includeAnswer = false,
  }) async {
    final response = await _client.post(
      Uri.parse('https://api.tavily.com/search'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'api_key': apiKey,
        'query': query,
        'max_results': maxResults,
        'search_depth': searchDepth,
        'include_answer': includeAnswer,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Tavily search failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>?) ?? [];

    return results
        .map((r) => TavilySearchResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// LangChain 도구 인터페이스용 문자열 반환
  Future<String> run(String query) async {
    final results = await search(query);
    final buf = StringBuffer();
    for (final r in results) {
      buf.writeln('### ${r.title}');
      buf.writeln('URL: ${r.url}');
      buf.writeln(r.content);
      buf.writeln('---');
    }
    return buf.toString();
  }

  void dispose() => _client.close();
}
DART_EOF

# ──── tools/pdf_parser_tool.dart ────
cat > lib/tools/pdf_parser_tool.dart << 'DART_EOF'
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class PdfParserResult {
  final String text;
  final int pageCount;
  final Map<String, String> metadata;

  const PdfParserResult({
    required this.text,
    required this.pageCount,
    this.metadata = const {},
  });
}

class PdfParserTool {
  final http.Client _client;

  PdfParserTool({http.Client? client}) : _client = client ?? http.Client();

  /// URL에서 PDF를 다운로드하여 텍스트 추출
  Future<PdfParserResult> parseFromUrl(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('PDF 다운로드 실패: ${response.statusCode}');
    }
    return _extractText(response.bodyBytes);
  }

  /// 로컬 파일에서 PDF 텍스트 추출
  Future<PdfParserResult> parseFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('파일을 찾을 수 없습니다: $filePath');
    }
    final bytes = await file.readAsBytes();
    return _extractText(bytes);
  }

  /// PDF 바이트에서 텍스트 추출 (간이 파서)
  PdfParserResult _extractText(List<int> bytes) {
    // PDF 스트림에서 텍스트 객체 추출
    final content = latin1.decode(bytes);
    final textBuffer = StringBuffer();
    int pageCount = 0;

    // 페이지 수 카운트
    final pagePattern = RegExp(r'/Type\s*/Page[^s]');
    pageCount = pagePattern.allMatches(content).length;

    // 텍스트 스트림 추출 (BT ... ET 블록)
    final btEtPattern = RegExp(r'BT(.*?)ET', dotAll: true);
    for (final match in btEtPattern.allMatches(content)) {
      final block = match.group(1) ?? '';
      // 괄호 안의 텍스트 리터럴 추출
      final textPattern = RegExp(r'\((.*?)\)');
      for (final tm in textPattern.allMatches(block)) {
        final text = tm.group(1) ?? '';
        if (text.trim().isNotEmpty) {
          textBuffer.write(text);
          textBuffer.write(' ');
        }
      }
    }

    final extractedText = textBuffer.toString().trim();
    if (extractedText.isEmpty) {
      return PdfParserResult(
        text: '[PDF 텍스트 추출 불가 - 스캔된 PDF이거나 보호된 문서일 수 있습니다]',
        pageCount: pageCount,
      );
    }

    return PdfParserResult(text: extractedText, pageCount: pageCount);
  }

  /// LangChain 도구 인터페이스용
  Future<String> run(String input) async {
    if (input.startsWith('http://') || input.startsWith('https://')) {
      final result = await parseFromUrl(input);
      return '페이지 수: ${result.pageCount}\n\n${result.text}';
    } else {
      final result = await parseFromFile(input);
      return '페이지 수: ${result.pageCount}\n\n${result.text}';
    }
  }

  void dispose() => _client.close();
}
DART_EOF

# ──── tools/calculator_tool.dart ────
cat > lib/tools/calculator_tool.dart << 'DART_EOF'
/// 안전한 수학 연산 계산기 도구
class CalculatorTool {
  /// 수학 표현식을 평가합니다.
  /// 지원: +, -, *, /, ^, (, ), sqrt, log, sin, cos, tan, pi, e
  String run(String expression) {
    try {
      final result = _evaluate(expression.trim());
      return result.toString();
    } catch (e) {
      return '계산 오류: $e';
    }
  }

  double _evaluate(String expr) {
    expr = expr.replaceAll(' ', '');
    // 상수 치환
    expr = expr.replaceAll('pi', '3.141592653589793');
    expr = expr.replaceAll('PI', '3.141592653589793');
    expr = expr.replaceAll(RegExp(r'(?<![a-zA-Z])e(?![a-zA-Z])'), '2.718281828459045');

    final parser = _ExprParser(expr);
    final result = parser.parseExpression();
    if (parser.pos < expr.length) {
      throw FormatException('예상하지 못한 문자: ${expr[parser.pos]}');
    }
    return result;
  }
}

class _ExprParser {
  final String input;
  int pos = 0;

  _ExprParser(this.input);

  double parseExpression() {
    var result = parseTerm();
    while (pos < input.length && (input[pos] == '+' || input[pos] == '-')) {
      final op = input[pos++];
      final term = parseTerm();
      result = op == '+' ? result + term : result - term;
    }
    return result;
  }

  double parseTerm() {
    var result = parsePower();
    while (pos < input.length && (input[pos] == '*' || input[pos] == '/')) {
      final op = input[pos++];
      final factor = parsePower();
      if (op == '/' && factor == 0) throw Exception('0으로 나눌 수 없습니다');
      result = op == '*' ? result * factor : result / factor;
    }
    return result;
  }

  double parsePower() {
    var result = parseUnary();
    if (pos < input.length && input[pos] == '^') {
      pos++;
      final exp = parseUnary();
      result = _pow(result, exp);
    }
    return result;
  }

  double parseUnary() {
    if (pos < input.length && input[pos] == '-') {
      pos++;
      return -parseUnary();
    }
    return parsePrimary();
  }

  double parsePrimary() {
    // 함수 호출
    for (final fn in ['sqrt', 'log', 'sin', 'cos', 'tan', 'abs']) {
      if (input.startsWith(fn, pos)) {
        pos += fn.length;
        if (pos < input.length && input[pos] == '(') {
          pos++; // skip (
          final arg = parseExpression();
          if (pos < input.length && input[pos] == ')') pos++;
          return _applyFunc(fn, arg);
        }
      }
    }

    // 괄호
    if (pos < input.length && input[pos] == '(') {
      pos++;
      final result = parseExpression();
      if (pos < input.length && input[pos] == ')') pos++;
      return result;
    }

    // 숫자
    final start = pos;
    while (pos < input.length && (RegExp(r'[0-9.]').hasMatch(input[pos]))) {
      pos++;
    }
    if (start == pos) throw FormatException('숫자가 예상됩니다 (위치: $pos)');
    return double.parse(input.substring(start, pos));
  }

  double _applyFunc(String name, double arg) {
    return switch (name) {
      'sqrt' => _sqrt(arg),
      'log'  => _log(arg),
      'sin'  => _sin(arg),
      'cos'  => _cos(arg),
      'tan'  => _tan(arg),
      'abs'  => arg.abs(),
      _      => throw Exception('알 수 없는 함수: $name'),
    };
  }

  static double _pow(double base, double exp) {
    double result = 1;
    for (var i = 0; i < exp.toInt(); i++) {
      result *= base;
    }
    return result;
  }

  static double _sqrt(double x) {
    if (x < 0) throw Exception('음수의 제곱근');
    double guess = x / 2;
    for (var i = 0; i < 100; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _log(double x) {
    if (x <= 0) throw Exception('0 이하의 로그');
    double result = 0;
    double term = (x - 1) / (x + 1);
    double termSq = term * term;
    double current = term;
    for (var n = 1; n <= 200; n += 2) {
      result += current / n;
      current *= termSq;
    }
    return 2 * result;
  }

  static double _sin(double x) {
    x = x % (2 * 3.141592653589793);
    double result = 0, term = x;
    for (var n = 1; n <= 20; n++) {
      result += term;
      term *= -x * x / ((2 * n) * (2 * n + 1));
    }
    return result;
  }

  static double _cos(double x) => _sin(x + 3.141592653589793 / 2);
  static double _tan(double x) => _sin(x) / _cos(x);
}
DART_EOF

# ──── rag/embeddings_service.dart ────
cat > lib/rag/embeddings_service.dart << 'DART_EOF'
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class EmbeddingsService {
  final String apiKey;
  final String model;
  final http.Client _client;

  EmbeddingsService({
    String? apiKey,
    String? model,
    http.Client? client,
  })  : apiKey = apiKey ?? AppConfig.openAiApiKey,
        model = model ?? AppConfig.embeddingModel,
        _client = client ?? http.Client();

  /// 텍스트를 임베딩 벡터로 변환
  Future<List<double>> embed(String text) async {
    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/embeddings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'input': text,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('임베딩 생성 실패: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final embedding = data['data'][0]['embedding'] as List<dynamic>;
    return embedding.map((e) => (e as num).toDouble()).toList();
  }

  /// 여러 텍스트를 배치로 임베딩
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/embeddings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'input': texts,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('배치 임베딩 생성 실패: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final embeddings = data['data'] as List<dynamic>;
    return embeddings
        .map((e) => ((e as Map)['embedding'] as List<dynamic>)
            .map((v) => (v as num).toDouble())
            .toList())
        .toList();
  }

  void dispose() => _client.close();
}
DART_EOF

# ──── rag/vector_store.dart ────
cat > lib/rag/vector_store.dart << 'DART_EOF'
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'embeddings_service.dart';

class VectorDocument {
  final String id;
  final String content;
  final Map<String, dynamic> metadata;
  final List<double>? embedding;

  const VectorDocument({
    required this.id,
    required this.content,
    this.metadata = const {},
    this.embedding,
  });
}

class SearchResult {
  final VectorDocument document;
  final double score;

  const SearchResult({required this.document, required this.score});
}

/// Qdrant 벡터 DB 클라이언트 (HNSW 인덱싱)
class VectorStore {
  final String baseUrl;
  final String? apiKey;
  final String collectionName;
  final int dimension;
  final EmbeddingsService embeddings;
  final http.Client _client;

  VectorStore({
    String? baseUrl,
    String? apiKey,
    String? collectionName,
    int? dimension,
    required this.embeddings,
    http.Client? client,
  })  : baseUrl = baseUrl ?? AppConfig.qdrantUrl,
        apiKey = apiKey ?? AppConfig.qdrantApiKey,
        collectionName = collectionName ?? AppConfig.collectionName,
        dimension = dimension ?? AppConfig.embeddingDimension,
        _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
      };

  /// 컬렉션 생성 (HNSW 인덱싱 설정)
  Future<void> createCollection() async {
    final response = await _client.put(
      Uri.parse('$baseUrl/collections/$collectionName'),
      headers: _headers,
      body: jsonEncode({
        'vectors': {
          'size': dimension,
          'distance': 'Cosine',
        },
        'hnsw_config': {
          'm': 16,                    // HNSW 그래프 연결 수
          'ef_construct': 200,        // 구축 시 탐색 범위
          'full_scan_threshold': 10000,
          'max_indexing_threads': 0,  // 자동 설정
          'on_disk': false,           // 메모리 내 인덱싱
        },
        'optimizers_config': {
          'indexing_threshold': 20000,
        },
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 409) {
      throw Exception('컬렉션 생성 실패: ${response.statusCode} ${response.body}');
    }
  }

  /// 문서 추가 (자동 임베딩 + HNSW 인덱싱)
  Future<void> addDocuments(List<VectorDocument> documents) async {
    if (documents.isEmpty) return;

    final texts = documents.map((d) => d.content).toList();
    final vectors = await embeddings.embedBatch(texts);

    final points = <Map<String, dynamic>>[];
    for (var i = 0; i < documents.length; i++) {
      points.add({
        'id': documents[i].id.hashCode.abs(),
        'vector': vectors[i],
        'payload': {
          'content': documents[i].content,
          'doc_id': documents[i].id,
          ...documents[i].metadata,
        },
      });
    }

    final response = await _client.put(
      Uri.parse('$baseUrl/collections/$collectionName/points'),
      headers: _headers,
      body: jsonEncode({'points': points}),
    );

    if (response.statusCode != 200) {
      throw Exception('문서 추가 실패: ${response.statusCode}');
    }
  }

  /// 고밀도 유사도 검색 (HNSW 기반)
  Future<List<SearchResult>> search(
    String query, {
    int topK = 5,
    int efSearch = 128, // HNSW 검색 시 탐색 범위
    Map<String, dynamic>? filter,
  }) async {
    final queryVector = await embeddings.embed(query);

    final body = <String, dynamic>{
      'vector': queryVector,
      'limit': topK,
      'with_payload': true,
      'params': {
        'hnsw_ef': efSearch,  // 검색 정확도 파라미터
        'exact': false,        // 근사 최근접 이웃 검색
      },
    };

    if (filter != null) body['filter'] = filter;

    final response = await _client.post(
      Uri.parse('$baseUrl/collections/$collectionName/points/search'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('검색 실패: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['result'] as List<dynamic>?) ?? [];

    return results.map((r) {
      final payload = r['payload'] as Map<String, dynamic>;
      return SearchResult(
        document: VectorDocument(
          id: payload['doc_id'] ?? '',
          content: payload['content'] ?? '',
          metadata: Map.from(payload)
            ..remove('content')
            ..remove('doc_id'),
        ),
        score: (r['score'] as num).toDouble(),
      );
    }).toList();
  }

  /// 컬렉션 삭제
  Future<void> deleteCollection() async {
    await _client.delete(
      Uri.parse('$baseUrl/collections/$collectionName'),
      headers: _headers,
    );
  }

  void dispose() => _client.close();
}
DART_EOF

# ──── services/llm_service.dart ────
cat > lib/services/llm_service.dart << 'DART_EOF'
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class LlmMessage {
  final String role; // system, user, assistant
  final String content;

  const LlmMessage({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class LlmService {
  final String apiKey;
  final String model;
  final http.Client _client;

  LlmService({
    String? apiKey,
    String? model,
    http.Client? client,
  })  : apiKey = apiKey ?? AppConfig.openAiApiKey,
        model = model ?? AppConfig.defaultModel,
        _client = client ?? http.Client();

  /// 단일 완성 요청
  Future<String> complete(
    List<LlmMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('LLM 요청 실패: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['choices'][0]['message']['content'] as String;
  }

  /// 스트리밍 완성 요청
  Stream<String> streamComplete(
    List<LlmMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('https://api.openai.com/v1/chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });
    request.body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,
    });

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw Exception('스트리밍 요청 실패: ${response.statusCode}');
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ') && !line.contains('[DONE]')) {
          try {
            final json = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta != null) yield delta as String;
          } catch (_) {}
        }
      }
    }
  }

  void dispose() => _client.close();
}
DART_EOF

# ──── agents/react_loop.dart ────
cat > lib/agents/react_loop.dart << 'DART_EOF'
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
DART_EOF

# ──── agents/research_agent.dart ────
cat > lib/agents/research_agent.dart << 'DART_EOF'
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
DART_EOF

# ──── services/research_provider.dart (Riverpod) ────
cat > lib/services/research_provider.dart << 'DART_EOF'
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../agents/research_agent.dart';
import '../models/research_task.dart';

// 연구 에이전트 Provider
final researchAgentProvider = Provider<ResearchAgent>((ref) {
  final agent = ResearchAgent.create();
  ref.onDispose(() => agent.dispose());
  return agent;
});

// 현재 연구 태스크 상태
final currentTaskProvider = StateNotifierProvider<ResearchTaskNotifier, ResearchTask?>(
  (ref) => ResearchTaskNotifier(ref.read(researchAgentProvider)),
);

// 연구 이력
final researchHistoryProvider = StateProvider<List<ResearchTask>>((ref) => []);

class ResearchTaskNotifier extends StateNotifier<ResearchTask?> {
  final ResearchAgent _agent;
  StreamSubscription<ResearchTask>? _subscription;

  ResearchTaskNotifier(this._agent) : super(null);

  /// 새 연구 시작
  void startResearch(String topic) {
    _subscription?.cancel();
    state = ResearchTask(topic: topic, status: TaskStatus.planning);

    _subscription = _agent.research(topic).listen(
      (task) => state = task,
      onError: (e) {
        state = state?.copyWith(
          status: TaskStatus.error,
          errorMessage: e.toString(),
        );
      },
    );
  }

  /// 연구 중단
  void cancel() {
    _subscription?.cancel();
    if (state != null) {
      state = state!.copyWith(status: TaskStatus.idle);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
DART_EOF

# ──── widgets/research_input.dart ────
cat > lib/widgets/research_input.dart << 'DART_EOF'
import 'package:flutter/material.dart';

class ResearchInput extends StatefulWidget {
  final void Function(String topic) onSubmit;
  final bool isLoading;

  const ResearchInput({
    super.key,
    required this.onSubmit,
    this.isLoading = false,
  });

  @override
  State<ResearchInput> createState() => _ResearchInputState();
}

class _ResearchInputState extends State<ResearchInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '연구 주제 입력',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: !widget.isLoading,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              hintText: '예: "2024년 대형 언어 모델의 추론 능력 발전 동향"',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.isLoading ? null : _submit,
              icon: widget.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science),
              label: Text(widget.isLoading ? '연구 진행 중...' : '연구 시작'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
DART_EOF

# ──── widgets/progress_timeline.dart ────
cat > lib/widgets/progress_timeline.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import '../models/research_task.dart';

class ProgressTimeline extends StatelessWidget {
  final ResearchTask task;

  const ProgressTimeline({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 상태바
          Row(
            children: [
              _StatusBadge(status: task.status),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.topic,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 진행률 바
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: task.progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(task.progress * 100).toInt()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // 단계별 타임라인
          ...task.steps.map((step) => _TimelineItem(step: step)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TaskStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      TaskStatus.idle      => ('대기', Colors.grey, Icons.hourglass_empty),
      TaskStatus.planning  => ('계획', Colors.blue, Icons.lightbulb_outline),
      TaskStatus.searching => ('검색', Colors.orange, Icons.search),
      TaskStatus.analyzing => ('분석', Colors.purple, Icons.analytics),
      TaskStatus.writing   => ('작성', Colors.teal, Icons.edit_note),
      TaskStatus.completed => ('완료', Colors.green, Icons.check_circle),
      TaskStatus.error     => ('오류', Colors.red, Icons.error_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final AgentStep step;

  const _TimelineItem({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (step.type) {
      'thought'     => (Icons.psychology, Colors.blue),
      'action'      => (Icons.play_circle_outline, Colors.orange),
      'observation' => (Icons.visibility, Colors.purple),
      'report'      => (Icons.description, Colors.green),
      _             => (Icons.circle, Colors.grey),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 20, color: color),
              Container(
                width: 2,
                height: 24,
                color: theme.colorScheme.outlineVariant,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      step.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (step.toolName != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          step.toolName!,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.content.length > 200
                      ? '${step.content.substring(0, 200)}...'
                      : step.content,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
DART_EOF

# ──── widgets/report_viewer.dart ────
cat > lib/widgets/report_viewer.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ReportViewer extends StatelessWidget {
  final String markdown;

  const ReportViewer({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '연구 보고서',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: '보고서 복사',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: markdown));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('보고서가 클립보드에 복사되었습니다')),
                  );
                },
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          MarkdownBody(
            data: markdown,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              h1: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              h2: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              h3: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              blockquote: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              code: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
DART_EOF

# ──── screens/dashboard_screen.dart ────
cat > lib/screens/dashboard_screen.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/research_task.dart';
import '../services/research_provider.dart';
import '../widgets/research_input.dart';
import '../widgets/progress_timeline.dart';
import '../widgets/report_viewer.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(currentTaskProvider);
    final theme = Theme.of(context);
    final isRunning = task != null &&
        task.status != TaskStatus.idle &&
        task.status != TaskStatus.completed &&
        task.status != TaskStatus.error;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'ResearchArch',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
            actions: [
              if (isRunning)
                TextButton.icon(
                  onPressed: () => ref.read(currentTaskProvider.notifier).cancel(),
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('중단'),
                ),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: '연구 이력',
                onPressed: () => _showHistory(context, ref),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Body
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 입력 카드
                ResearchInput(
                  isLoading: isRunning,
                  onSubmit: (topic) {
                    ref.read(currentTaskProvider.notifier).startResearch(topic);
                  },
                ),
                const SizedBox(height: 24),

                // 에러 표시
                if (task?.status == TaskStatus.error) ...[
                  _ErrorCard(message: task!.errorMessage ?? '알 수 없는 오류'),
                  const SizedBox(height: 24),
                ],

                // 진행 상황 타임라인
                if (task != null && task.steps.isNotEmpty) ...[
                  ProgressTimeline(task: task),
                  const SizedBox(height: 24),
                ],

                // 보고서 뷰어
                if (task?.report != null) ...[
                  ReportViewer(markdown: task!.report!),
                  const SizedBox(height: 24),
                ],

                // 빈 상태
                if (task == null)
                  _EmptyState(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    final history = ref.read(researchHistoryProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '연구 이력',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (history.isEmpty)
              const Center(child: Text('아직 완료된 연구가 없습니다'))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return ListTile(
                      leading: const Icon(Icons.article),
                      title: Text(item.topic),
                      subtitle: Text(
                        '${item.createdAt.toString().substring(0, 16)} | '
                        '${item.steps.length} 단계',
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.biotech,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'AI 연구 에이전트',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '연구 주제를 입력하면 자동으로\n논문 검색, 분석, 보고서 작성을 수행합니다',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              children: [
                _FeatureChip(icon: Icons.search, label: '웹 검색 (Tavily)'),
                _FeatureChip(icon: Icons.picture_as_pdf, label: 'PDF 분석'),
                _FeatureChip(icon: Icons.calculate, label: '계산기'),
                _FeatureChip(icon: Icons.storage, label: 'RAG (Qdrant)'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
DART_EOF

# ──── main.dart ────
cat > lib/main.dart << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const ProviderScope(child: ResearchArchApp()));
}

class ResearchArchApp extends StatelessWidget {
  const ResearchArchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResearchArch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
    );
  }
}
DART_EOF

# ──── .env.example ────
cat > .env.example << 'DART_EOF'
# ResearchArch 환경변수 설정
# 이 파일을 .env로 복사한 후 실제 키를 입력하세요

OPENAI_API_KEY=sk-your-openai-api-key-here
TAVILY_API_KEY=tvly-your-tavily-api-key-here
QDRANT_URL=http://localhost:6333
QDRANT_API_KEY=your-qdrant-api-key-here
DART_EOF

# ──── assets/.gitkeep ────
touch assets/.gitkeep

echo "  ✓ 총 15개 Dart 소스 파일 생성 완료"

# ─────────────────────────────────────────────
# 4. 의존성 설치
# ─────────────────────────────────────────────
echo ""
echo "[4/4] flutter pub get 실행 중..."
flutter pub get

echo ""
echo "============================================"
echo "  셋업 완료!"
echo "============================================"
echo ""
echo "프로젝트 구조:"
echo "  lib/"
echo "  ├── main.dart                     # 앱 진입점"
echo "  ├── config/"
echo "  │   └── app_config.dart           # API 키 설정"
echo "  ├── agents/"
echo "  │   ├── research_agent.dart       # 자율 연구 에이전트"
echo "  │   └── react_loop.dart           # ReAct 루프 엔진"
echo "  ├── tools/"
echo "  │   ├── tavily_search_tool.dart   # 웹 검색 (Tavily)"
echo "  │   ├── pdf_parser_tool.dart      # PDF 텍스트 추출"
echo "  │   └── calculator_tool.dart      # 수학 계산기"
echo "  ├── rag/"
echo "  │   ├── vector_store.dart         # Qdrant 벡터 DB (HNSW)"
echo "  │   └── embeddings_service.dart   # OpenAI 임베딩"
echo "  ├── models/"
echo "  │   ├── research_task.dart        # 연구 태스크 모델"
echo "  │   └── research_report.dart      # 보고서 모델"
echo "  ├── services/"
echo "  │   ├── llm_service.dart          # LLM 서비스 (스트리밍)"
echo "  │   └── research_provider.dart    # Riverpod 상태관리"
echo "  ├── screens/"
echo "  │   └── dashboard_screen.dart     # 대시보드 화면"
echo "  └── widgets/"
echo "      ├── research_input.dart       # 연구 주제 입력"
echo "      ├── progress_timeline.dart    # 진행상황 타임라인"
echo "      └── report_viewer.dart        # 마크다운 보고서 뷰어"
echo ""
echo "실행 방법:"
echo "  1. API 키 설정:"
echo "     flutter run --dart-define=OPENAI_API_KEY=sk-xxx \\"
echo "                 --dart-define=TAVILY_API_KEY=tvly-xxx \\"
echo "                 --dart-define=QDRANT_URL=http://localhost:6333"
echo ""
echo "  2. Qdrant 로컬 실행 (Docker):"
echo "     docker run -p 6333:6333 qdrant/qdrant"
echo ""
echo "  3. 앱 실행:"
echo "     flutter run -d chrome   # 웹"
echo "     flutter run -d macos    # macOS"
echo ""
