import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'widgets/task_tile.dart';
import '../../../app/ui/tokens.dart';

import '../data/tasks_storage.dart';
import '../domain/task.dart';
import 'task_form_sheet.dart';

// Tipos de tarea (configuración)
import '../../types/ui/task_types_screen.dart';
import '../../types/data/task_types_storage.dart';
import '../../types/domain/task_type.dart';
import '../../backup/backup_service.dart';
import '../../stats/ui/stats_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/notifications/notification_service.dart';

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
  DateTime? _reminderDateFrom(Task t) {
    if (t.dueDate == null || t.reminderMinutes == null) return null;
    return t.dueDate!.subtract(Duration(minutes: t.reminderMinutes!));
  }

  Future<void> _scheduleIfNeeded(Task t) async {
    final when = _reminderDateFrom(t);
    if (when == null) return;
    // Si la tarea está hecha o la fecha ya pasó, no programamos
    if (t.done || when.isBefore(DateTime.now())) return;
    await NotificationService.instance.scheduleTaskReminder(
      taskId: t.id,
      title: t.title,
      body: t.notes,
      when: when,
    );
  }

  Future<void> _cancelIfScheduled(Task t) async {
    await NotificationService.instance.cancelTaskReminder(t.id);
  }

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
      int priority,
      int? reminderMinutes
    })?;

    if (result != null) {
      final t = Task(
        id: const Uuid().v4(),
        title: result.title.trim(),
        notes: result.notes?.trim(),
        createdAt: DateTime.now(),
        dueDate: result.due,
        typeId: result.typeId,
        order: _nextOrder(),
        priority: result.priority,
        reminderMinutes: result.reminderMinutes,
      );
      setState(() => _tasks = [..._tasks, t]);
      await _persist();
      await _scheduleIfNeeded(t); // 👈 programa notificación
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
      int priority,
      int? reminderMinutes
    })?;

    if (result != null) {
      final updated = task.copyWith(
        title: result.title,
        notes: result.notes,
        dueDate: result.due,
        typeId: result.typeId,
        priority: result.priority,
        reminderMinutes: result.reminderMinutes,
      );
      setState(() {
        _tasks = [
          for (final t in _tasks)
            if (t.id == task.id) updated else t,
        ];
      });
      await _persist();
      // Resetea notificación
      await _cancelIfScheduled(task);
      await _scheduleIfNeeded(updated);
    }
  }

  Future<void> _toggle(Task task, bool done) async {
    final old = task;
    final updated = task.copyWith(done: done);
    setState(() {
      _tasks = [
        for (final t in _tasks)
          if (t.id == task.id) updated else t,
      ];
    });
    await _persist();

    if (done) {
      await _cancelIfScheduled(old);
    } else {
      await _scheduleIfNeeded(updated);
    }
  }

  Future<void> _delete(Task task) async {
    setState(() => _tasks = _tasks.where((t) => t.id != task.id).toList());
    await _persist();
    await _cancelIfScheduled(task);
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
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) async {
              if (value == 'export') {
                try {
                  final res = await BackupService().createExportFile();
                  if (!context.mounted) return; // 👈 guarda tras await
                  await Share.shareXFiles([res.xfile],
                      text: 'Backup de mi_app');
                  if (!context.mounted) return; // 👈 otro await, otra guarda
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Exportado: ${res.tasksCount} tareas, ${res.typesCount} tipos')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al exportar: $e')),
                  );
                }
              } else if (value == 'import') {
                final res = await BackupService().pickAndImport();
                if (!context.mounted) return;
                if (res.cancelled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Importación cancelada')),
                  );
                } else if (res.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res.error!)),
                  );
                } else {
                  await _load(); // recarga almacenamiento
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Importadas ${res.tasksCount} tareas y ${res.typesCount} tipos')),
                  );
                }
              } else if (value == 'stats') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                );
                if (!context.mounted) return;
                // no hacemos nada más aquí
              } else if (value == 'types') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TaskTypesScreen()),
                );
                if (!context.mounted) return;
                _types = await TaskTypesStorage().load();
                if (!context.mounted) return;
                setState(() {});
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('Exportar backup')),
              PopupMenuItem(value: 'import', child: Text('Importar backup')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'stats', child: Text('Estadísticas')),
              PopupMenuItem(value: 'types', child: Text('Configurar tipos')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador arriba
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.md, Spacing.sm, Spacing.md, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por título o notas…',
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
                padding:
                    const EdgeInsets.fromLTRB(Spacing.sm, 0, Spacing.sm, 96),
                itemCount: list.length,
                onReorder: _onReorder,
                proxyDecorator: (child, index, animation) => Material(
                  elevation: Elev.floating,
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
                itemBuilder: (context, i) {
                  final task = list[i];
                  return TaskTile(
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
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: s.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child:
              Icon(Icons.inbox_outlined, size: 72, color: s.onSurfaceVariant),
        ),
        const SizedBox(height: Spacing.md),
        Text('Todo listo ✨', style: t.titleMedium),
        const SizedBox(height: Spacing.xs),
        Opacity(
          opacity: .85,
          child: Text(
            'Crea tu primera tarea con el botón de abajo',
            style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
