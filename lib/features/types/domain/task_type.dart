import 'dart:convert';
import 'package:flutter/material.dart';

class TaskType {
  final String id;
  final String name;
  final int color; // ARGB

  const TaskType({required this.id, required this.name, required this.color});

  Color get colorAsColor => Color(color);

  TaskType copyWith({String? id, String? name, int? color}) => TaskType(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'color': color};

  factory TaskType.fromMap(Map<String, dynamic> m) => TaskType(
        id: m['id'] as String,
        name: m['name'] as String,
        color: (m['color'] as num).toInt(),
      );

  String toJson() => jsonEncode(toMap());
  factory TaskType.fromJson(String s) =>
      TaskType.fromMap(jsonDecode(s) as Map<String, dynamic>);
}
