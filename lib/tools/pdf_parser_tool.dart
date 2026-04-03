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
