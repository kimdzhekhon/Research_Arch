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
    buf.writeln('\n_Generated at: ${generatedAt}_');
    return buf.toString();
  }
}
