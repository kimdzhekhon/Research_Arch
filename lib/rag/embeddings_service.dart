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
