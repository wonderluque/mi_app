import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../tasks/data/tasks_storage.dart';
import '../tasks/domain/task.dart';
import '../types/data/task_types_storage.dart';
import '../types/domain/task_type.dart';

class BackupExportResult {
  final XFile xfile;
  final int tasksCount;
  final int typesCount;
  BackupExportResult(
      {required this.xfile,
      required this.tasksCount,
      required this.typesCount});
}

class BackupImportResult {
  final bool cancelled;
  final int tasksCount;
  final int typesCount;
  final String? error;

  const BackupImportResult._(
      {required this.cancelled,
      required this.tasksCount,
      required this.typesCount,
      this.error});

  factory BackupImportResult.cancelled() =>
      const BackupImportResult._(cancelled: true, tasksCount: 0, typesCount: 0);
  factory BackupImportResult.success(
          {required int tasksCount, required int typesCount}) =>
      BackupImportResult._(
          cancelled: false, tasksCount: tasksCount, typesCount: typesCount);
  factory BackupImportResult.failure(String msg) => BackupImportResult._(
      cancelled: false, tasksCount: 0, typesCount: 0, error: msg);
}

class BackupService {
  final _tasksStorage = TasksStorage();
  final _typesStorage = TaskTypesStorage();

  /// Crea un archivo JSON temporal con tasks+types y lo devuelve para compartir.
  Future<BackupExportResult> createExportFile() async {
    final tasks = await _tasksStorage.load();
    final types = await _typesStorage.load();

    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'types': types.map((t) => t.toMap()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/mi_app_backup.json');
    await file.writeAsString(jsonStr);

    final x = XFile(file.path,
        mimeType: 'application/json', name: 'mi_app_backup.json');
    return BackupExportResult(
        xfile: x, tasksCount: tasks.length, typesCount: types.length);
  }

  /// Abre el selector de archivos, valida e importa. NO usa BuildContext.
  Future<BackupImportResult> pickAndImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return BackupImportResult.cancelled();
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        return BackupImportResult.failure('No se pudo leer el archivo.');
      }

      final file = File(filePath);
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic>) {
        return BackupImportResult.failure(
            'Formato inválido: JSON raíz debe ser un objeto.');
      }

      final tasksRaw = decoded['tasks'];
      final typesRaw = decoded['types'];
      if (tasksRaw is! List || typesRaw is! List) {
        return BackupImportResult.failure(
            'Formato inválido: faltan listas "tasks" o "types".');
      }

      final types = typesRaw
          .map((e) => TaskType.fromMap((e as Map).cast<String, dynamic>()))
          .toList()
          .cast<TaskType>();
      final tasks = tasksRaw
          .map((e) => Task.fromMap((e as Map).cast<String, dynamic>()))
          .toList()
          .cast<Task>();

      await _typesStorage.save(types);
      await _tasksStorage.save(tasks);

      return BackupImportResult.success(
          tasksCount: tasks.length, typesCount: types.length);
    } catch (e) {
      return BackupImportResult.failure('Error al importar: $e');
    }
  }
}
