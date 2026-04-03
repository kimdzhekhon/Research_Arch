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
