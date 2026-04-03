import 'dart:async';
import 'package:flutter/material.dart';
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
  (ref) => ResearchTaskNotifier(ref.read(researchAgentProvider), ref),
);

// 연구 이력
final researchHistoryProvider = StateNotifierProvider<ResearchHistoryNotifier, List<ResearchTask>>(
  (ref) => ResearchHistoryNotifier(),
);

// 테마 모드
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class ResearchTaskNotifier extends StateNotifier<ResearchTask?> {
  final ResearchAgent _agent;
  final Ref _ref;
  StreamSubscription<ResearchTask>? _subscription;

  ResearchTaskNotifier(this._agent, this._ref) : super(null);

  /// 새 연구 시작
  void startResearch(String topic) {
    _subscription?.cancel();
    state = ResearchTask(topic: topic, status: TaskStatus.planning);

    _subscription = _agent.research(topic).listen(
      (task) {
        state = task;
        // 완료 시 이력에 추가
        if (task.status == TaskStatus.completed) {
          _ref.read(researchHistoryProvider.notifier).add(task);
        }
      },
      onError: (e) {
        state = state?.copyWith(
          status: TaskStatus.error,
          errorMessage: e.toString(),
        );
      },
    );
  }

  /// 이력에서 태스크 로드
  void loadTask(ResearchTask task) {
    _subscription?.cancel();
    state = task;
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

class ResearchHistoryNotifier extends StateNotifier<List<ResearchTask>> {
  ResearchHistoryNotifier() : super([]);

  void add(ResearchTask task) {
    state = [task, ...state];
  }

  void remove(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void clear() {
    state = [];
  }
}
