// lib/app/theme.dart
import 'package:flutter/material.dart';

ThemeData buildTheme({bool dark = false}) {
  final base = dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);

  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0EA5A5), // color base
    brightness: dark ? Brightness.dark : Brightness.light,
  );

  return base.copyWith(
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 3,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
  );
}
