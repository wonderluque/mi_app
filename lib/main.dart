// lib/main.dart
import 'package:flutter/material.dart';
import 'app/theme.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi primera app',
      theme: buildTheme(), // 👈 tema claro
      darkTheme: buildTheme(dark: true), // 👈 tema oscuro
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi primera app')),
      body: const Center(
        child: Text(
          '¡Hola, Alberto! 🎉\nTu app Flutter está viva.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
