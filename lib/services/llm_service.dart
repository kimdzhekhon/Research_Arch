import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
  final int maxRetries;
  final Duration timeout;

  LlmService({
    String? apiKey,
    String? model,
    http.Client? client,
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 60),
  })  : apiKey = apiKey ?? AppConfig.openAiApiKey,
        model = model ?? AppConfig.defaultModel,
        _client = client ?? http.Client();

  /// 단일 완성 요청 (지수 백오프 재시도 포함)
  Future<String> complete(
    List<LlmMessage> messages, {
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _client
            .post(
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
            )
            .timeout(timeout);

        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt < maxRetries) {
            await _backoff(attempt);
            continue;
          }
        }

        if (response.statusCode != 200) {
          throw LlmException(
            'LLM 요청 실패',
            statusCode: response.statusCode,
            body: response.body,
          );
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['choices'][0]['message']['content'] as String;
      } on TimeoutException {
        if (attempt < maxRetries) {
          await _backoff(attempt);
          continue;
        }
        throw LlmException('LLM 요청 타임아웃 (${timeout.inSeconds}초)', statusCode: 408);
      }
    }
    throw LlmException('최대 재시도 횟수 초과 ($maxRetries회)', statusCode: 0);
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

    final response = await _client.send(request).timeout(timeout);
    if (response.statusCode != 200) {
      throw LlmException('스트리밍 요청 실패', statusCode: response.statusCode);
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

  /// 지수 백오프 대기 (jitter 포함)
  Future<void> _backoff(int attempt) async {
    final baseMs = math.pow(2, attempt) * 1000;
    final jitter = math.Random().nextInt(500);
    await Future.delayed(Duration(milliseconds: baseMs.toInt() + jitter));
  }

  void dispose() => _client.close();
}

class LlmException implements Exception {
  final String message;
  final int statusCode;
  final String? body;

  const LlmException(this.message, {required this.statusCode, this.body});

  @override
  String toString() => 'LlmException($statusCode): $message${body != null ? '\n$body' : ''}';
}
