import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../types/domain/task_type.dart';

class TaskTypesStorage {
  static const _kKey = 'task_types_v1';

  Future<List<TaskType>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_kKey);
    if (data == null || data.isEmpty) {
      // Tipos por defecto si el usuario aún no ha creado ninguno
      return const [
        TaskType(id: 'default_personal', name: 'Personal', color: 0xFF2196F3),
        TaskType(id: 'default_trabajo', name: 'Trabajo', color: 0xFF4CAF50),
        TaskType(id: 'default_urgente', name: 'Urgente', color: 0xFFF44336),
      ];
    }
    final raw = jsonDecode(data) as List<dynamic>;
    return raw.map((e) => TaskType.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<TaskType> types) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(types.map((t) => t.toMap()).toList());
    await prefs.setString(_kKey, json);
  }
}
