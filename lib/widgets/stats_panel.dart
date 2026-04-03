import 'package:flutter/material.dart';
import '../models/research_task.dart';

class StatsPanel extends StatelessWidget {
  final ResearchTask task;

  const StatsPanel({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final thoughts = task.steps.where((s) => s.type == 'thought').length;
    final actions = task.steps.where((s) => s.type == 'action').length;
    final observations = task.steps.where((s) => s.type == 'observation').length;
    final searchCount = task.steps.where((s) => s.toolName == 'web_search').length;
    final storeCount = task.steps.where((s) => s.toolName == 'store_document').length;

    final elapsed = task.steps.isNotEmpty
        ? task.steps.last.timestamp.difference(task.steps.first.timestamp)
        : Duration.zero;

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
              Icon(Icons.analytics_outlined, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '연구 통계',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatChip(
                icon: Icons.psychology,
                label: '사고',
                value: '$thoughts',
                color: Colors.blue,
              ),
              _StatChip(
                icon: Icons.play_circle_outline,
                label: '행동',
                value: '$actions',
                color: Colors.orange,
              ),
              _StatChip(
                icon: Icons.visibility,
                label: '관찰',
                value: '$observations',
                color: Colors.purple,
              ),
              _StatChip(
                icon: Icons.search,
                label: '웹 검색',
                value: '$searchCount',
                color: Colors.teal,
              ),
              _StatChip(
                icon: Icons.save,
                label: 'DB 저장',
                value: '$storeCount',
                color: Colors.indigo,
              ),
              _StatChip(
                icon: Icons.timer_outlined,
                label: '소요 시간',
                value: _formatDuration(elapsed),
                color: Colors.deepOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}분 ${d.inSeconds % 60}초';
    }
    return '${d.inSeconds}초';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
