import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/research_task.dart';

/// 연구 이력을 로컬에 영구 저장하는 서비스
class StorageService {
  static const _historyKey = 'research_history';
  static const _settingsPrefix = 'settings_';
  static const _maxHistory = 50;

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // ─── 연구 이력 ───

  List<ResearchTask> loadHistory() {
    final jsonList = _prefs.getStringList(_historyKey);
    if (jsonList == null) return [];
    return jsonList.map((json) {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return _taskFromJson(map);
    }).toList();
  }

  Future<void> saveHistory(List<ResearchTask> tasks) async {
    final trimmed = tasks.take(_maxHistory).toList();
    final jsonList = trimmed.map((t) => jsonEncode(_taskToJson(t))).toList();
    await _prefs.setStringList(_historyKey, jsonList);
  }

  Future<void> addToHistory(ResearchTask task) async {
    final history = loadHistory();
    history.insert(0, task);
    await saveHistory(history);
  }

  Future<void> removeFromHistory(String id) async {
    final history = loadHistory().where((t) => t.id != id).toList();
    await saveHistory(history);
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
  }

  // ─── 설정 ───

  String? getSetting(String key) => _prefs.getString('$_settingsPrefix$key');

  Future<void> setSetting(String key, String value) async {
    await _prefs.setString('$_settingsPrefix$key', value);
  }

  Future<void> removeSetting(String key) async {
    await _prefs.remove('$_settingsPrefix$key');
  }

  // ─── JSON 변환 ───

  Map<String, dynamic> _taskToJson(ResearchTask task) => {
        'id': task.id,
        'topic': task.topic,
        'status': task.status.index,
        'report': task.report,
        'createdAt': task.createdAt.toIso8601String(),
        'progress': task.progress,
        'steps': task.steps
            .map((s) => {
                  'type': s.type,
                  'content': s.content,
                  'timestamp': s.timestamp.toIso8601String(),
                  'toolName': s.toolName,
                })
            .toList(),
      };

  ResearchTask _taskFromJson(Map<String, dynamic> map) => ResearchTask(
        id: map['id'] as String,
        topic: map['topic'] as String,
        status: TaskStatus.values[map['status'] as int],
        report: map['report'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        progress: (map['progress'] as num).toDouble(),
        steps: (map['steps'] as List)
            .map((s) => AgentStep(
                  type: s['type'] as String,
                  content: s['content'] as String,
                  timestamp: DateTime.parse(s['timestamp'] as String),
                  toolName: s['toolName'] as String?,
                ))
            .toList(),
      );
}
