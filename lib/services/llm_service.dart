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
