import 'dart:convert';

class Task {
  final String id;
  final String title;
  final String? notes;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool done;
  final String? typeId;

  /// Orden persistente (para arrastre)
  final int order;

  /// Prioridad (1=Baja, 2=Media, 3=Alta)
  final int priority;

  /// Minutos de antelación del recordatorio respecto a dueDate.
  /// null = sin recordatorio.
  final int? reminderMinutes;

  Task({
    required this.id,
    required this.title,
    this.notes,
    required this.createdAt,
    this.dueDate,
    this.done = false,
    this.typeId,
    required this.order,
    this.priority = 2,
    this.reminderMinutes,
  });

  Task copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? createdAt,
    DateTime? dueDate,
    bool? done,
    String? typeId,
    int? order,
    int? priority,
    int? reminderMinutes,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      done: done ?? this.done,
      typeId: typeId ?? this.typeId,
      order: order ?? this.order,
      priority: priority ?? this.priority,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'done': done,
        'typeId': typeId,
        'order': order,
        'priority': priority,
        'reminderMinutes': reminderMinutes,
      };

  factory Task.fromMap(Map<String, dynamic> m) {
    final ord = (m['order'] as num?)?.toInt() ?? 0;
    final prio = (m['priority'] as num?)?.toInt() ?? 2;
    final rem = (m['reminderMinutes'] as num?)?.toInt();

    return Task(
      id: m['id'] as String,
      title: m['title'] as String,
      notes: m['notes'] as String?,
      createdAt: DateTime.parse(m['createdAt'] as String),
      dueDate: m['dueDate'] != null ? DateTime.parse(m['dueDate']) : null,
      done: m['done'] as bool? ?? false,
      typeId: m['typeId'] as String?,
      order: ord,
      priority: prio,
      reminderMinutes: rem,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory Task.fromJson(String s) => Task.fromMap(jsonDecode(s));
}
