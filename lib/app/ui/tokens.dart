// lib/app/ui/tokens.dart
import 'package:flutter/material.dart';

/// Espaciado
class Spacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Radios
class Corners {
  static const sm = Radius.circular(8);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(16);
  static const xl = Radius.circular(20);
}

/// Duraciones y curvas
class Motion {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 340);

  static const easeOut = Curves.easeOutCubic;
  static const easeIn = Curves.easeInCubic;
  static const smooth = Curves.easeInOutCubic;
}

/// Elevaciones
class Elev {
  static const card = 1.0;
  static const raised = 2.0;
  static const floating = 6.0;
}

/// Helpers de color
Color priorityColor(ColorScheme s, int priority) {
  switch (priority) {
    case 3:
      return s.error;
    case 1:
      return s.outline;
    default:
      return s.primary;
  }
}
