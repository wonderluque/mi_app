import 'package:flutter/material.dart';
import '../../tasks/data/tasks_storage.dart';
import '../../tasks/domain/task.dart';
import '../../types/data/task_types_storage.dart';
import '../../types/domain/task_type.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _tasksStorage = TasksStorage();
  final _typesStorage = TaskTypesStorage();

  List<Task> _tasks = [];
  List<TaskType> _types = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _tasks = await _tasksStorage.load();
    _types = await _typesStorage.load();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = _tasks.length;
    final done = _tasks.where((t) => t.done).length;
    final pending = total - done;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Lunes
    final endOfWeek = startOfWeek
        .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    bool isThisWeek(DateTime d) =>
        !d.isBefore(
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day)) &&
        !d.isAfter(endOfWeek);

    final createdThisWeek = _tasks.where((t) => isThisWeek(t.createdAt)).length;
    final doneThisWeek =
        _tasks.where((t) => t.done && isThisWeek(t.createdAt)).length;

    final overdue = _tasks.where((t) {
      if (t.done) return false;
      final d = t.dueDate;
      if (d == null) return false;
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return d.isBefore(todayEnd);
    }).length;

    final byPriority = <int, int>{1: 0, 2: 0, 3: 0};
    for (final t in _tasks) {
      byPriority[t.priority] = (byPriority[t.priority] ?? 0) + 1;
    }

    final byType = <String, int>{};
    for (final t in _tasks) {
      final key = t.typeId ?? '_none';
      byType[key] = (byType[key] ?? 0) + 1;
    }

    String typeName(String? id) {
      if (id == null) return 'Sin tipo';
      final found = _types.where((e) => e.id == id);
      return found.isEmpty ? 'Sin tipo' : found.first.name;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(
            title: 'Resumen',
            children: [
              _StatTile(
                  label: 'Total',
                  value: '$total',
                  icon: Icons.format_list_bulleted),
              _StatTile(
                  label: 'Hechas', value: '$done', icon: Icons.check_circle),
              _StatTile(
                  label: 'Pendientes',
                  value: '$pending',
                  icon: Icons.radio_button_unchecked),
              _StatTile(
                  label: 'Atrasadas',
                  value: '$overdue',
                  icon: Icons.warning_amber_rounded),
            ],
          ),
          _Section(
            title: 'Semana actual',
            children: [
              _StatTile(
                  label: 'Creadas', value: '$createdThisWeek', icon: Icons.add),
              _StatTile(
                  label: 'Completadas',
                  value: '$doneThisWeek',
                  icon: Icons.task_alt),
              _ProgressTile(
                label: 'Cumplimiento',
                numerator: doneThisWeek,
                denominator: createdThisWeek == 0 ? 1 : createdThisWeek,
              ),
            ],
          ),
          _Section(
            title: 'Por prioridad',
            children: [
              _StatTile(
                  label: 'Alta',
                  value: '${byPriority[3]}',
                  icon: Icons.priority_high),
              _StatTile(
                  label: 'Media', value: '${byPriority[2]}', icon: Icons.flag),
              _StatTile(
                  label: 'Baja',
                  value: '${byPriority[1]}',
                  icon: Icons.low_priority),
            ],
          ),
          _Section(
            title: 'Por tipo',
            children: [
              for (final entry in byType.entries)
                ListTile(
                  leading: const Icon(Icons.label),
                  title:
                      Text(typeName(entry.key == '_none' ? null : entry.key)),
                  trailing: Text('${entry.value}'),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                child:
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile(
      {required this.label,
      required this.numerator,
      required this.denominator});
  final String label;
  final int numerator;
  final int denominator;

  @override
  Widget build(BuildContext context) {
    final ratio =
        (numerator / (denominator == 0 ? 1 : denominator)).clamp(0.0, 1.0);
    return ListTile(
      leading: const Icon(Icons.timeline),
      title: Text(label),
      subtitle: LinearProgressIndicator(value: ratio),
      trailing: Text('$numerator/$denominator'),
    );
  }
}
