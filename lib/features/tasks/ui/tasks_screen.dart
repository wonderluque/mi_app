import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/tasks_storage.dart';
import '../domain/task.dart';
import 'task_form_sheet.dart';

// Tipos de tarea (configuración)
import '../../types/ui/task_types_screen.dart';
import '../../types/data/task_types_storage.dart';
import '../../types/domain/task_type.dart';

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

  // Tipos y filtros
  List<TaskType> _types = [];
  String? _selectedTypeId;
  DateTimeRange? _dateRangeFilter;
  int? _priorityFilter; // 1,2,3 o null (todas)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _tasks = await _storage.load();
    _types = await TaskTypesStorage().load();

    // Normaliza 'order' si hay tareas antiguas sin valor (0)
    _tasks = _normalizeOrder(_tasks);

    setState(() {});
  }

  List<Task> _normalizeOrder(List<Task> items) {
    final sorted = [...items]..sort((a, b) => a.order.compareTo(b.order));
    // Si todos tienen 0, generamos orden secuencial
    if (sorted.every((t) => t.order == 0)) {
      for (var i = 0; i < sorted.length; i++) {
        sorted[i] = sorted[i].copyWith(order: i);
      }
    }
    return sorted;
  }

  Future<void> _persist() async => _storage.save(_tasks);

  int _nextOrder() {
    if (_tasks.isEmpty) return 0;
    return _tasks.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> _add() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const TaskFormSheet(),
    ) as ({
      String title,
      String? notes,
      DateTime? due,
      String? typeId,
      int priority
    })?;

    if (result != null) {
      final t = Task(
        id: const Uuid().v4(),
        title: result.title.trim(),
        notes: result.notes?.trim(),
        createdAt: DateTime.now(),
        dueDate: result.due,
        typeId: result.typeId,
        order: _nextOrder(), // 👈 al final
        priority: result.priority, // 👈 prioridad elegida
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
    ) as ({
      String title,
      String? notes,
      DateTime? due,
      String? typeId,
      int priority
    })?;

    if (result != null) {
      final updated = task.copyWith(
        title: result.title,
        notes: result.notes,
        dueDate: result.due,
        typeId: result.typeId,
        priority: result.priority,
      );
      setState(() {
        _tasks = [
          for (final t in _tasks)
            if (t.id == task.id) updated else t,
        ];
      });
      await _persist();
    }
  }

  Future<void> _toggle(Task task, bool done) async {
    setState(() {
      _tasks = [
        for (final t in _tasks)
          if (t.id == task.id) t.copyWith(done: done) else t,
      ];
    });
    await _persist();
  }

  Future<void> _delete(Task task) async {
    setState(() {
      _tasks = _tasks.where((t) => t.id != task.id).toList();
    });
    await _persist();
  }

  // Reordenar por arrastre
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final list = [..._sortedByOrder(_applyFilters(_tasks))];
    if (newIndex > oldIndex) newIndex -= 1;

    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    // Reasigna 'order' secuencial sólo a los elementos visibles reordenados
    // y luego mezcla con los que no estaban visibles por filtros/búsqueda.
    final visibleIds = list.map((t) => t.id).toSet();
    final others = _tasks.where((t) => !visibleIds.contains(t.id)).toList();

    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(order: i);
    }

    // Para no romper el orden de "otros", los ponemos detrás
    final baseOrder = list.length;
    final othersSorted = [...others]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (var i = 0; i < othersSorted.length; i++) {
      // si ya tenían order no 0, lo respetamos; si eran 0, secuencial detrás
      final o = othersSorted[i];
      final newOrd = o.order == 0 ? baseOrder + i : o.order;
      othersSorted[i] = o.copyWith(order: newOrd);
    }

    setState(() => _tasks = [...list, ...othersSorted]);
    await _persist();
  }

  List<Task> _sortedByOrder(List<Task> items) {
    final list = [...items]..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  // ==== Filtros y búsqueda aplicados (reutilizable) ====
  List<Task> _applyFilters(List<Task> input) {
    Iterable<Task> filtered = input;

    if (_filter == TaskFilter.pending) {
      filtered = filtered.where((t) => !t.done);
    }
    if (_filter == TaskFilter.done) {
      filtered = filtered.where((t) => t.done);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered.where(
        (t) =>
            t.title.toLowerCase().contains(q) ||
            (t.notes ?? '').toLowerCase().contains(q),
      );
    }
    if (_selectedTypeId != null) {
      filtered = filtered.where((t) => t.typeId == _selectedTypeId);
    }
    if (_priorityFilter != null) {
      filtered = filtered.where((t) => t.priority == _priorityFilter);
    }
    if (_dateRangeFilter != null) {
      final start = DateTime(
        _dateRangeFilter!.start.year,
        _dateRangeFilter!.start.month,
        _dateRangeFilter!.start.day,
      );
      final end = DateTime(
        _dateRangeFilter!.end.year,
        _dateRangeFilter!.end.month,
        _dateRangeFilter!.end.day,
        23,
        59,
        59,
      );
      bool inRange(Task t) {
        final d = t.dueDate ?? t.createdAt;
        return !d.isBefore(start) && !d.isAfter(end);
      }

      filtered = filtered.where(inRange);
    }
    return filtered.toList();
  }

  TaskType? _findType(String? id) {
    if (id == null) return null;
    try {
      return _types.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  String _formatRange(DateTimeRange r) {
    String d(DateTime x) => x.toLocal().toString().split(' ').first;
    return '${d(r.start)} → ${d(r.end)}';
  }

  Future<void> _openFilters() async {
    var tempFilter = _filter;
    String? tempType = _selectedTypeId;
    DateTimeRange? tempRange = _dateRangeFilter;
    int? tempPrio = _priorityFilter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets.add(const EdgeInsets.all(16)),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final total = _tasks.length;
              final done = _tasks.where((t) => t.done).length;
              final pending = total - done;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Filtrar', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 12),

                    // Estado
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Estado',
                          style: Theme.of(ctx).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Todas ($total)'),
                          selected: tempFilter == TaskFilter.all,
                          onSelected: (_) =>
                              setSheetState(() => tempFilter = TaskFilter.all),
                        ),
                        ChoiceChip(
                          label: Text('Pendientes ($pending)'),
                          selected: tempFilter == TaskFilter.pending,
                          onSelected: (_) => setSheetState(
                              () => tempFilter = TaskFilter.pending),
                        ),
                        ChoiceChip(
                          label: Text('Hechas ($done)'),
                          selected: tempFilter == TaskFilter.done,
                          onSelected: (_) =>
                              setSheetState(() => tempFilter = TaskFilter.done),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Prioridad
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Prioridad',
                          style: Theme.of(ctx).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: tempPrio == null,
                          onSelected: (_) =>
                              setSheetState(() => tempPrio = null),
                        ),
                        ChoiceChip(
                          label: const Text('Baja'),
                          selected: tempPrio == 1,
                          onSelected: (_) => setSheetState(() => tempPrio = 1),
                        ),
                        ChoiceChip(
                          label: const Text('Media'),
                          selected: tempPrio == 2,
                          onSelected: (_) => setSheetState(() => tempPrio = 2),
                        ),
                        ChoiceChip(
                          label: const Text('Alta'),
                          selected: tempPrio == 3,
                          onSelected: (_) => setSheetState(() => tempPrio = 3),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tipo
                    if (_types.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Tipo',
                            style: Theme.of(ctx).textTheme.labelLarge),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos los tipos'),
                            selected: tempType == null,
                            onSelected: (_) =>
                                setSheetState(() => tempType = null),
                          ),
                          ..._types.map(
                            (t) => ChoiceChip(
                              label: Text(t.name),
                              selected: tempType == t.id,
                              onSelected: (_) =>
                                  setSheetState(() => tempType = t.id),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Rango fechas
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Fecha (vencimiento o creación)',
                          style: Theme.of(ctx).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final initial = tempRange ??
                                  DateTimeRange(
                                    start:
                                        now.subtract(const Duration(days: 7)),
                                    end: now,
                                  );
                              final picked = await showDateRangePicker(
                                context: ctx,
                                firstDate: DateTime(now.year - 2),
                                lastDate: DateTime(now.year + 2),
                                initialDateRange: initial,
                              );
                              if (picked != null) {
                                setSheetState(() => tempRange = picked);
                              }
                            },
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              tempRange == null
                                  ? 'Rango de fechas'
                                  : _formatRange(tempRange!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Limpiar fecha',
                          onPressed: () =>
                              setSheetState(() => tempRange = null),
                          icon: const Icon(Icons.filter_alt_off),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botonera
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx), // cancelar
                          child: const Text('Cancelar'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempFilter = TaskFilter.all;
                              tempType = null;
                              tempRange = null;
                              tempPrio = null;
                            });
                          },
                          child: const Text('Limpiar todo'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _filter = tempFilter;
                              _selectedTypeId = tempType;
                              _dateRangeFilter = tempRange;
                              _priorityFilter = tempPrio;
                            });
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Siempre trabajamos con la lista ordenada por 'order'
    final afterFilters = _applyFilters(_tasks);
    final list = _sortedByOrder(afterFilters);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis tareas'),
        actions: [
          IconButton(
            tooltip: 'Filtrar',
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilters,
          ),
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskTypesScreen()),
              );
              final ts = await TaskTypesStorage().load();
              setState(() => _types = ts);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador arriba
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar tareas…',
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Lista: Reorderable o Estado vacío
          if (list.isEmpty)
            const Expanded(
              child: Center(child: _EmptyState()),
            )
          else
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
                itemCount: list.length,
                onReorder: _onReorder,
                proxyDecorator: (child, index, animation) => Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
                itemBuilder: (context, i) {
                  final task = list[i];
                  return _TaskTile(
                    key: ValueKey('tile-${task.id}'),
                    task: task,
                    type: _findType(task.typeId),
                    onToggle: (v) => _toggle(task, v),
                    onEdit: () => _edit(task),
                    onDelete: () => _delete(task),
                  );
                },
              ),
            ),
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
    return Column(
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
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.type,
  });

  final Task task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final TaskType? type;

  Color _priorityColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (task.priority) {
      case 3:
        return scheme.error; // Alta → más llamativo
      case 1:
        return scheme.outline; // Baja → discreto
      case 2:
      default:
        return scheme.primary; // Media
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseSubtitle = task.notes != null || task.dueDate != null
        ? [
            if (task.notes != null) task.notes!,
            if (task.dueDate != null)
              'Vence: ${task.dueDate!.toLocal().toString().split(" ").first}',
          ].join(' · ')
        : null;

    return Card(
      key: key,
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
        subtitle: (baseSubtitle != null || type != null)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (baseSubtitle != null) Text(baseSubtitle),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: -8,
                    children: [
                      // Chip de prioridad
                      Chip(
                        label: Text(
                          switch (task.priority) {
                            3 => 'Alta',
                            1 => 'Baja',
                            _ => 'Media',
                          },
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        backgroundColor:
                            _priorityColor(context).withValues(alpha: 0.15),
                        side: BorderSide(
                            color:
                                _priorityColor(context).withValues(alpha: 0.6)),
                      ),
                      // Chip de tipo (si existe)
                      if (type != null)
                        Chip(
                          label: Text(type!.name),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          avatar: CircleAvatar(
                            backgroundColor: type!.colorAsColor,
                            radius: 6,
                          ),
                        ),
                    ],
                  ),
                ],
              )
            : null,
        trailing: IconButton(
          tooltip: 'Editar',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        onLongPress: onDelete, // atajo: long-press para borrar
        onTap: onEdit,
      ),
    );
  }
}
