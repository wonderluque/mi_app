import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/task.dart';

class TasksStorage {
  static const _kKey = 'tasks_v1';

  Future<List<Task>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_kKey);
    if (data == null || data.isEmpty) return <Task>[];
    final raw = jsonDecode(data) as List<dynamic>;
    return raw.map((e) => Task.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(tasks.map((t) => t.toMap()).toList());
    await prefs.setString(_kKey, json);
  }
}
