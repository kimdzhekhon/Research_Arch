import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/research_task.dart';
import '../services/research_provider.dart';
import '../widgets/research_input.dart';
import '../widgets/progress_timeline.dart';
import '../widgets/report_viewer.dart';
import '../widgets/stats_panel.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(currentTaskProvider);
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isRunning = task != null &&
        task.status != TaskStatus.idle &&
        task.status != TaskStatus.completed &&
        task.status != TaskStatus.error;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'ResearchArch',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
            actions: [
              if (isRunning)
                TextButton.icon(
                  onPressed: () => ref.read(currentTaskProvider.notifier).cancel(),
                  icon: const Icon(Icons.stop_circle),
                  label: const Text('중단'),
                ),
              // 테마 토글
              IconButton(
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : themeMode == ThemeMode.light
                          ? Icons.dark_mode
                          : Icons.brightness_auto,
                ),
                tooltip: '테마 변경',
                onPressed: () {
                  final next = switch (themeMode) {
                    ThemeMode.system => ThemeMode.light,
                    ThemeMode.light => ThemeMode.dark,
                    ThemeMode.dark => ThemeMode.system,
                  };
                  ref.read(themeModeProvider.notifier).state = next;
                },
              ),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: '연구 이력',
                onPressed: () => _showHistory(context, ref),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Body
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 입력 카드
                ResearchInput(
                  isLoading: isRunning,
                  onSubmit: (topic) {
                    ref.read(currentTaskProvider.notifier).startResearch(topic);
                  },
                ),
                const SizedBox(height: 24),

                // 에러 표시
                if (task?.status == TaskStatus.error) ...[
                  _ErrorCard(message: task!.errorMessage ?? '알 수 없는 오류'),
                  const SizedBox(height: 24),
                ],

                // 연구 통계 패널
                if (task != null && task.steps.length >= 2) ...[
                  StatsPanel(task: task),
                  const SizedBox(height: 16),
                ],

                // 진행 상황 타임라인
                if (task != null && task.steps.isNotEmpty) ...[
                  ProgressTimeline(task: task),
                  const SizedBox(height: 24),
                ],

                // 보고서 뷰어
                if (task?.report != null) ...[
                  ReportViewer(markdown: task!.report!),
                  const SizedBox(height: 24),
                ],

                // 빈 상태
                if (task == null)
                  const _EmptyState(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    final history = ref.read(researchHistoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '연구 이력',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (history.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(researchHistoryProvider.notifier).clear();
                        Navigator.pop(context);
                      },
                      child: const Text('전체 삭제'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (history.isEmpty)
                const Expanded(
                  child: Center(child: Text('아직 완료된 연구가 없습니다')),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final stepCount = item.steps.length;
                      final sourceCount = item.steps
                          .where((s) => s.toolName == 'web_search')
                          .length;
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.article,
                            size: 20,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          item.topic,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${item.createdAt.toString().substring(0, 16)} | '
                          '$stepCount단계 | $sourceCount개 출처',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          ref.read(currentTaskProvider.notifier).loadTask(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.red.shade700 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.biotech,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'AI 연구 에이전트',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '연구 주제를 입력하면 자동으로\n논문 검색, 분석, 보고서 작성을 수행합니다',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _FeatureChip(icon: Icons.search, label: '웹 검색 (Tavily)'),
                _FeatureChip(icon: Icons.picture_as_pdf, label: 'PDF 분석'),
                _FeatureChip(icon: Icons.calculate, label: '계산기'),
                _FeatureChip(icon: Icons.storage, label: 'RAG (Qdrant)'),
                _FeatureChip(icon: Icons.auto_awesome, label: 'ReAct Agent'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
