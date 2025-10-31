import 'dart:convert';

class Task {
  final String id;
  final String title;
  final String? notes;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool done;

  Task({
    required this.id,
    required this.title,
    this.notes,
    required this.createdAt,
    this.dueDate,
    this.done = false,
  });

  Task copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? createdAt,
    DateTime? dueDate,
    bool? done,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'done': done,
      };

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        dueDate: m['dueDate'] != null ? DateTime.parse(m['dueDate']) : null,
        done: m['done'] as bool? ?? false,
      );

  String toJson() => jsonEncode(toMap());
  factory Task.fromJson(String s) => Task.fromMap(jsonDecode(s));
}
