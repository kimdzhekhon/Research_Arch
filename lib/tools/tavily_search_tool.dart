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
