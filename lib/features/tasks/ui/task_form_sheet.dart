import 'package:flutter/material.dart';
import '../../types/data/task_types_storage.dart';
import '../../types/domain/task_type.dart';
import '../domain/task.dart';

class TaskFormSheet extends StatefulWidget {
  const TaskFormSheet({super.key, this.initial});
  final Task? initial;

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _typesStorage = TaskTypesStorage();
  List<TaskType> _types = [];
  String? _selectedTypeId;
  DateTime? _due;

  // 1=Baja, 2=Media, 3=Alta
  int _priority = 2;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _titleCtrl.text = t.title;
      _notesCtrl.text = t.notes ?? '';
      _due = t.dueDate;
      _selectedTypeId = t.typeId;
      _priority = t.priority;
    }
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    final list = await _typesStorage.load();
    setState(() => _types = list);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initial == null ? 'Nueva tarea' : 'Editar tarea',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej: Enviar informe semanal',
              ),
              autofocus: true,
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Mínimo 3 caracteres'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Detalles, enlaces, etc.',
              ),
              minLines: 1,
              maxLines: 4,
            ),
            const SizedBox(height: 8),

            // Tipo
            DropdownButtonFormField<String?>(
              value: _selectedTypeId,
              items: _types
                  .map(
                    (t) => DropdownMenuItem<String?>(
                      value: t.id,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: t.colorAsColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(t.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              hint: const Text('Sin tipo'),
              decoration: const InputDecoration(labelText: 'Tipo de tarea'),
              onChanged: (v) => setState(() => _selectedTypeId = v),
            ),

            const SizedBox(height: 8),

            // Prioridad
            DropdownButtonFormField<int>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Prioridad'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Baja')),
                DropdownMenuItem(value: 2, child: Text('Media')),
                DropdownMenuItem(value: 3, child: Text('Alta')),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 2),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _due == null
                        ? 'Sin fecha límite'
                        : 'Vence: ${_due!.toLocal().toString().split(" ").first}',
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 3),
                      initialDate: _due ?? now,
                    );
                    setState(() => _due = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: const Text('Elegir fecha'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.of(context).pop((
                    title: _titleCtrl.text,
                    notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
                    due: _due,
                    typeId: _selectedTypeId,
                    priority: _priority, // 👈 devolvemos prioridad
                  ));
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
