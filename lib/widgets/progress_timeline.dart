import 'package:flutter/material.dart';
import '../models/research_task.dart';

class ProgressTimeline extends StatelessWidget {
  final ResearchTask task;

  const ProgressTimeline({super.key, required this.task});

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
          // 상단 상태바
          Row(
            children: [
              _StatusBadge(status: task.status),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.topic,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 진행률 바
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: task.progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(task.progress * 100).toInt()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // 단계별 타임라인
          ...task.steps.map((step) => _TimelineItem(step: step)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TaskStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      TaskStatus.idle      => ('대기', Colors.grey, Icons.hourglass_empty),
      TaskStatus.planning  => ('계획', Colors.blue, Icons.lightbulb_outline),
      TaskStatus.searching => ('검색', Colors.orange, Icons.search),
      TaskStatus.analyzing => ('분석', Colors.purple, Icons.analytics),
      TaskStatus.writing   => ('작성', Colors.teal, Icons.edit_note),
      TaskStatus.completed => ('완료', Colors.green, Icons.check_circle),
      TaskStatus.error     => ('오류', Colors.red, Icons.error_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final AgentStep step;

  const _TimelineItem({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (step.type) {
      'thought'     => (Icons.psychology, Colors.blue),
      'action'      => (Icons.play_circle_outline, Colors.orange),
      'observation' => (Icons.visibility, Colors.purple),
      'report'      => (Icons.description, Colors.green),
      _             => (Icons.circle, Colors.grey),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 20, color: color),
              Container(
                width: 2,
                height: 24,
                color: theme.colorScheme.outlineVariant,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      step.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (step.toolName != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          step.toolName!,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.content.length > 200
                      ? '${step.content.substring(0, 200)}...'
                      : step.content,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
