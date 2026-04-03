import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum TaskStatus { idle, planning, searching, analyzing, writing, completed, error }

class AgentStep extends Equatable {
  final String type; // thought, action, observation
  final String content;
  final DateTime timestamp;
  final String? toolName;

  const AgentStep({
    required this.type,
    required this.content,
    required this.timestamp,
    this.toolName,
  });

  @override
  List<Object?> get props => [type, content, timestamp, toolName];
}

class ResearchTask extends Equatable {
  final String id;
  final String topic;
  final TaskStatus status;
  final List<AgentStep> steps;
  final String? report;
  final String? errorMessage;
  final DateTime createdAt;
  final double progress;

  ResearchTask({
    String? id,
    required this.topic,
    this.status = TaskStatus.idle,
    this.steps = const [],
    this.report,
    this.errorMessage,
    DateTime? createdAt,
    this.progress = 0.0,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  ResearchTask copyWith({
    TaskStatus? status,
    List<AgentStep>? steps,
    String? report,
    String? errorMessage,
    double? progress,
  }) {
    return ResearchTask(
      id: id,
      topic: topic,
      status: status ?? this.status,
      steps: steps ?? this.steps,
      report: report ?? this.report,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      progress: progress ?? this.progress,
    );
  }

  @override
  List<Object?> get props => [id, topic, status, steps, report, errorMessage, createdAt, progress];
}
