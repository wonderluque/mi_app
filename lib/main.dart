// lib/main.dart
import 'package:flutter/material.dart';
import 'app/theme.dart';
import 'features/tasks/ui/tasks_screen.dart'; // 👈 NUEVO: importamos la pantalla
import 'core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init(); // 👈 init notificaciones
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi App de Productividad',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(), // Tema claro
      darkTheme: buildTheme(dark: true), // Tema oscuro
      home:
          const TasksScreen(), // 👈 NUEVO: usamos TasksScreen como pantalla inicial
    );
  }
}
