/// 재귀적 텍스트 분할기 (Recursive Character Text Splitter)
///
/// 긴 문서를 의미 있는 단위로 나누어 벡터 DB에 저장할 수 있도록 청킹합니다.
/// 문단 → 줄바꿈 → 문장 → 공백 순으로 분할 우선순위를 적용하여
/// 의미적 맥락을 최대한 보존합니다.
class TextChunker {
  final int chunkSize;
  final int chunkOverlap;
  final List<String> separators;

  const TextChunker({
    this.chunkSize = 500,
    this.chunkOverlap = 50,
    this.separators = const ['\n\n', '\n', '. ', ' '],
  });

  /// 텍스트를 청크 목록으로 분할
  List<TextChunk> split(String text, {Map<String, dynamic>? metadata}) {
    final chunks = <TextChunk>[];
    final rawChunks = _splitRecursive(text, 0);

    for (var i = 0; i < rawChunks.length; i++) {
      final content = rawChunks[i].trim();
      if (content.isEmpty) continue;

      chunks.add(TextChunk(
        content: content,
        index: i,
        metadata: {
          ...?metadata,
          'chunk_index': i,
          'total_chunks': rawChunks.length,
        },
      ));
    }

    return chunks;
  }

  List<String> _splitRecursive(String text, int separatorIndex) {
    if (text.length <= chunkSize) return [text];
    if (separatorIndex >= separators.length) {
      return _splitBySize(text);
    }

    final sep = separators[separatorIndex];
    final parts = text.split(sep);

    if (parts.length == 1) {
      return _splitRecursive(text, separatorIndex + 1);
    }

    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final part in parts) {
      final candidate = buffer.isEmpty ? part : '$buffer$sep$part';

      if (candidate.length > chunkSize && buffer.isNotEmpty) {
        chunks.add(buffer.toString());

        // 오버랩 적용: 이전 청크의 마지막 부분을 다음 청크 시작에 포함
        final prevText = buffer.toString();
        buffer.clear();
        if (chunkOverlap > 0 && prevText.length > chunkOverlap) {
          buffer.write(prevText.substring(prevText.length - chunkOverlap));
          buffer.write(sep);
        }
        buffer.write(part);
      } else {
        if (buffer.isNotEmpty) buffer.write(sep);
        buffer.write(part);
      }
    }

    if (buffer.isNotEmpty) {
      final remaining = buffer.toString();
      if (remaining.length > chunkSize) {
        chunks.addAll(_splitRecursive(remaining, separatorIndex + 1));
      } else {
        chunks.add(remaining);
      }
    }

    return chunks;
  }

  List<String> _splitBySize(String text) {
    final chunks = <String>[];
    var start = 0;
    while (start < text.length) {
      var end = start + chunkSize;
      if (end > text.length) end = text.length;
      chunks.add(text.substring(start, end));
      start = end - chunkOverlap;
      if (start <= 0 && chunks.isNotEmpty) break;
    }
    return chunks;
  }
}

class TextChunk {
  final String content;
  final int index;
  final Map<String, dynamic> metadata;

  const TextChunk({
    required this.content,
    required this.index,
    this.metadata = const {},
  });
}
