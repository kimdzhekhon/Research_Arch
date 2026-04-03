import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../models/research_task.dart';

class ReportDetailScreen extends StatelessWidget {
  final ResearchTask task;

  const ReportDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final hasReport = task.report != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          task.topic,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (hasReport) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: '복사',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: task.report!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('보고서가 클립보드에 복사되었습니다'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: '공유',
              onPressed: () => _shareReport(context),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: hasReport
          ? _ReportBody(task: task)
          : _ErrorBody(task: task),
    );
  }

  void _shareReport(BuildContext context) {
    Share.share(task.report!);
  }
}

class _ReportBody extends StatelessWidget {
  final ResearchTask task;

  const _ReportBody({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        // 메타 정보
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _MetaStat(
                  icon: Icons.route,
                  label: '단계',
                  value: '${task.steps.length}',
                ),
                const SizedBox(width: 24),
                _MetaStat(
                  icon: Icons.search,
                  label: '검색',
                  value: '${task.steps.where((s) => s.toolName == 'web_search').length}',
                ),
                const SizedBox(width: 24),
                _MetaStat(
                  icon: Icons.timer,
                  label: '소요',
                  value: _elapsed(),
                ),
                const SizedBox(width: 24),
                _MetaStat(
                  icon: Icons.calendar_today,
                  label: '날짜',
                  value: '${task.createdAt.month}/${task.createdAt.day}',
                ),
              ],
            ),
          ),
        ),

        // 보고서 마크다운
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: MarkdownBody(
              data: task.report!,
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
                p: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                blockquote: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                code: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                listBullet: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ),

        // 에이전트 단계 확장 섹션
        SliverToBoxAdapter(
          child: _StepExpansion(steps: task.steps),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  String _elapsed() {
    if (task.steps.length < 2) return '-';
    final d = task.steps.last.timestamp.difference(task.steps.first.timestamp);
    if (d.inMinutes > 0) return '${d.inMinutes}분';
    return '${d.inSeconds}초';
  }
}

class _MetaStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _StepExpansion extends StatelessWidget {
  final List<AgentStep> steps;

  const _StepExpansion({required this.steps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ExpansionTile(
        leading: Icon(Icons.timeline, color: theme.colorScheme.primary),
        title: Text('에이전트 추론 과정 (${steps.length}단계)',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        children: steps.map((step) {
          final (icon, color) = switch (step.type) {
            'thought' => (Icons.psychology, Colors.blue),
            'action' => (Icons.play_circle_outline, Colors.orange),
            'observation' => (Icons.visibility, Colors.purple),
            'report' => (Icons.description, Colors.green),
            _ => (Icons.circle, Colors.grey),
          };

          return ListTile(
            dense: true,
            leading: Icon(icon, size: 18, color: color),
            title: Row(
              children: [
                Text(
                  step.type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (step.toolName != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(step.toolName!,
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSecondaryContainer)),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                step.content.length > 300
                    ? '${step.content.substring(0, 300)}...'
                    : step.content,
                style: theme.textTheme.bodySmall,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final ResearchTask task;

  const _ErrorBody({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              '보고서가 생성되지 않았습니다',
              style: theme.textTheme.titleMedium,
            ),
            if (task.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                task.errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (task.steps.isNotEmpty) ...[
              const SizedBox(height: 24),
              _StepExpansion(steps: task.steps),
            ],
          ],
        ),
      ),
    );
  }
}
