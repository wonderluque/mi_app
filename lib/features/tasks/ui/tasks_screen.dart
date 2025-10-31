import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/tasks_storage.dart';
import '../domain/task.dart';
import 'task_form_sheet.dart';

enum TaskFilter { all, pending, done }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _storage = TasksStorage();
  List<Task> _tasks = [];
  TaskFilter _filter = TaskFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _tasks = await _storage.load();
    setState(() {});
  }

  Future<void> _persist() async => _storage.save(_tasks);

  Future<void> _add() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const TaskFormSheet(),
    ) as ({String title, String? notes, DateTime? due})?;
    if (result != null) {
      final t = Task(
        id: const Uuid().v4(),
        title: result.title.trim(),
        notes: result.notes?.trim(),
        createdAt: DateTime.now(),
        dueDate: result.due,
      );
      setState(() => _tasks = [..._tasks, t]);
      await _persist();
    }
  }

  Future<void> _edit(Task task) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => TaskFormSheet(initial: task),
    ) as ({String title, String? notes, DateTime? due})?;
    if (result != null) {
      final updated = task.copyWith(
        title: result.title,
        notes: result.notes,
        dueDate: result.due,
      );
      setState(() => _tasks = [
            for (final t in _tasks)
              if (t.id == task.id) updated else t
          ]);
      await _persist();
    }
  }

  Future<void> _toggle(Task task, bool done) async {
    setState(() => _tasks = [
          for (final t in _tasks)
            if (t.id == task.id) t.copyWith(done: done) else t
        ]);
    await _persist();
  }

  Future<void> _delete(Task task) async {
    setState(() => _tasks = _tasks.where((t) => t.id != task.id).toList());
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    Iterable<Task> filtered = _tasks;
    if (_filter == TaskFilter.pending) {
      filtered = filtered.where((t) => !t.done);
    }
    if (_filter == TaskFilter.done) filtered = filtered.where((t) => t.done);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered.where((t) =>
          t.title.toLowerCase().contains(q) ||
          (t.notes ?? '').toLowerCase().contains(q));
    }
    final list = filtered.toList();
    final done = _tasks.where((t) => t.done).length;
    final pending = _tasks.length - done;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis tareas'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Buscar tareas…',
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Todas (${_tasks.length})'),
                        selected: _filter == TaskFilter.all,
                        onSelected: (_) =>
                            setState(() => _filter = TaskFilter.all),
                      ),
                      ChoiceChip(
                        label: Text('Pendientes ($pending)'),
                        selected: _filter == TaskFilter.pending,
                        onSelected: (_) =>
                            setState(() => _filter = TaskFilter.pending),
                      ),
                      ChoiceChip(
                        label: Text('Hechas ($done)'),
                        selected: _filter == TaskFilter.done,
                        onSelected: (_) =>
                            setState(() => _filter = TaskFilter.done),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverList.separated(
              itemCount: list.length,
              itemBuilder: (_, i) => _TaskTile(
                task: list[i],
                onToggle: (v) => _toggle(list[i], v),
                onEdit: () => _edit(list[i]),
                onDelete: () => _delete(list[i]),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 4),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Añadir tarea'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 72, color: scheme.outline),
          const SizedBox(height: 12),
          Text('Sin tareas todavía',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Crea tu primera tarea con el botón de abajo',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = task.notes != null || task.dueDate != null
        ? [
            if (task.notes != null) task.notes!,
            if (task.dueDate != null)
              'Vence: ${task.dueDate!.toLocal().toString().split(" ").first}',
          ].join(' · ')
        : null;

    return Dismissible(
      key: ValueKey('dismiss-${task.id}'),
      background: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      child: Card(
        child: ListTile(
          leading: Checkbox(
            value: task.done,
            onChanged: (v) => onToggle(v ?? false),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.done ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          onTap: onEdit,
        ),
      ),
    );
  }
}
