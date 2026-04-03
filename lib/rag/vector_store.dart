import 'dart:convert';
import 'package:http/http.dart' as http;
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
