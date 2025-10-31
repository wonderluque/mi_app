import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../types/data/task_types_storage.dart';
import '../../types/domain/task_type.dart';
import '../../tasks/data/tasks_storage.dart'; // para bloquear borrado si está en uso
import '../../tasks/domain/task.dart';

class TaskTypesScreen extends StatefulWidget {
  const TaskTypesScreen({super.key});

  @override
  State<TaskTypesScreen> createState() => _TaskTypesScreenState();
}

class _TaskTypesScreenState extends State<TaskTypesScreen> {
  final _storage = TaskTypesStorage();
  final _tasksStorage = TasksStorage();

  List<TaskType> _types = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _types = await _storage.load();
    setState(() {});
  }

  Future<void> _persist() async => _storage.save(_types);

  Future<void> _addOrEdit({TaskType? initial}) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _TypeFormSheet(initial: initial),
    ) as ({String name, int color})?;
    if (result == null) return;

    if (initial == null) {
      final t = TaskType(
        id: const Uuid().v4(),
        name: result.name.trim(),
        color: result.color,
      );
      setState(() => _types = [..._types, t]);
    } else {
      setState(() => _types = [
            for (final t in _types)
              if (t.id == initial.id)
                initial.copyWith(name: result.name, color: result.color)
              else
                t
          ]);
    }
    await _persist();
  }

  Future<void> _delete(TaskType type) async {
    // Bloquear borrado si hay tareas usando este tipo
    final tasks = await _tasksStorage.load();
    final used = tasks.any((Task t) => t.typeId == type.id);
    if (used) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No puedes borrar un tipo que está en uso')),
      );
      return;
    }

    setState(() => _types = _types.where((t) => t.id != type.id).toList());
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración · Tipos de tarea')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _types.length,
        itemBuilder: (_, i) {
          final t = _types[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: t.colorAsColor),
              title: Text(t.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _addOrEdit(initial: t),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(t),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Añadir tipo'),
      ),
    );
  }
}

class _TypeFormSheet extends StatefulWidget {
  const _TypeFormSheet({this.initial});
  final TaskType? initial;

  @override
  State<_TypeFormSheet> createState() => _TypeFormSheetState();
}

class _TypeFormSheetState extends State<_TypeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  int _color = 0xFF2196F3;

  static const _palette = <int>[
    0xFF2196F3,
    0xFF4CAF50,
    0xFFF44336,
    0xFFFF9800,
    0xFF9C27B0,
    0xFF00BCD4,
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _nameCtrl.text = t.name;
      _color = t.color;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: insets.add(const EdgeInsets.all(16)),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.initial == null ? 'Nuevo tipo' : 'Editar tipo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              autofocus: true,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Mínimo 2 caracteres'
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _palette.map((c) {
                final selected = c == _color;
                return ChoiceChip(
                  selected: selected,
                  label: const Text(''),
                  selectedColor: Color(c).withValues(alpha: 0.8),
                  backgroundColor: Color(c).withValues(alpha: 0.35),
                  onSelected: (_) => setState(() => _color = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.of(context)
                      .pop((name: _nameCtrl.text, color: _color));
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
