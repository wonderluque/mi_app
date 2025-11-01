// lib/features/tasks/ui/widgets/task_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../app/ui/tokens.dart';
import '../../domain/task.dart';
import '../../../types/domain/task_type.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
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

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final dueText = task.dueDate != null
        ? 'Vence ${task.dueDate!.toLocal().toString().split(' ').first}'
        : null;

    final prioColor = priorityColor(s, task.priority);

    return Slidable(
      key: ValueKey('slidable-${task.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.66,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            icon: Icons.edit_outlined,
            label: 'Editar',
            backgroundColor: s.secondaryContainer,
            foregroundColor: s.onSecondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          SlidableAction(
            onPressed: (_) => onToggle(!task.done),
            icon: task.done ? Icons.undo : Icons.check_circle,
            label: task.done ? 'Deshacer' : 'Hecha',
            backgroundColor: s.primaryContainer,
            foregroundColor: s.onPrimaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            icon: Icons.delete_outline,
            label: 'Borrar',
            backgroundColor: s.errorContainer,
            foregroundColor: s.onErrorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Card(
        elevation: Elev.card,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox estilizado
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Transform.scale(
                    scale: 1.1,
                    child: Checkbox(
                      value: task.done,
                      onChanged: (v) => onToggle(v ?? false),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),

                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título + prioridad
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: t.titleMedium?.copyWith(
                                decoration: task.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Spacing.xs),
                          // Punto de prioridad
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: prioColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: Spacing.xs),

                      // Notas + fecha
                      if (task.notes != null || dueText != null)
                        Opacity(
                          opacity: 0.9,
                          child: Text(
                            [
                              if (task.notes != null) task.notes!,
                              if (dueText != null) dueText,
                            ].join(' · '),
                            style: t.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      const SizedBox(height: Spacing.sm),

                      // Chips: tipo + prioridad
                      Wrap(
                        spacing: Spacing.xs,
                        runSpacing: -Spacing.xxs,
                        children: [
                          if (type != null)
                            Chip(
                              label: Text(type!.name),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              avatar: CircleAvatar(
                                radius: 6,
                                backgroundColor: type!.colorAsColor,
                              ),
                            ),
                          Chip(
                            label: Text(
                              switch (task.priority) {
                                3 => 'Alta',
                                1 => 'Baja',
                                _ => 'Media'
                              },
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            side: BorderSide(
                                color: prioColor.withValues(alpha: .4)),
                            backgroundColor: prioColor.withValues(alpha: .12),
                          ),
                          if (task.reminderMinutes != null &&
                              task.dueDate != null)
                            Chip(
                              label:
                                  Text(_reminderLabel(task.reminderMinutes!)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              avatar: const Icon(Icons.alarm, size: 16),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _reminderLabel(int minutes) {
    if (minutes == 0) return 'A la hora';
    if (minutes == 15) return '15 min antes';
    if (minutes == 60) return '1 h antes';
    if (minutes == 1440) return '1 día antes';
    return '$minutes min antes';
  }
}
