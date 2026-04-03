import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../agents/research_agent.dart';
import '../models/research_task.dart';

// 연구 에이전트 Provider
final researchAgentProvider = Provider<ResearchAgent>((ref) {
  final agent = ResearchAgent.create();
  ref.onDispose(() => agent.dispose());
  return agent;
});

// 현재 연구 태스크 상태
final currentTaskProvider = StateNotifierProvider<ResearchTaskNotifier, ResearchTask?>(
  (ref) => ResearchTaskNotifier(ref.read(researchAgentProvider)),
);

// 연구 이력
final researchHistoryProvider = StateProvider<List<ResearchTask>>((ref) => []);

class ResearchTaskNotifier extends StateNotifier<ResearchTask?> {
  final ResearchAgent _agent;
  StreamSubscription<ResearchTask>? _subscription;

  ResearchTaskNotifier(this._agent) : super(null);

  /// 새 연구 시작
  void startResearch(String topic) {
    _subscription?.cancel();
    state = ResearchTask(topic: topic, status: TaskStatus.planning);

    _subscription = _agent.research(topic).listen(
      (task) => state = task,
      onError: (e) {
        state = state?.copyWith(
          status: TaskStatus.error,
          errorMessage: e.toString(),
        );
      },
    );
  }

  /// 연구 중단
  void cancel() {
    _subscription?.cancel();
    if (state != null) {
      state = state!.copyWith(status: TaskStatus.idle);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
