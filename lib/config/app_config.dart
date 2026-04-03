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
