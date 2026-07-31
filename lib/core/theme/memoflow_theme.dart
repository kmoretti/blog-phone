import 'package:flutter/material.dart';

abstract final class MemoFlowTheme {
  static const _terracotta = Color(0xFFB76045);
  static const _lightBackground = Color(0xFFF5F2ED);
  static const _darkBackground = Color(0xFF242321);

  static final light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: _lightBackground,
    colorScheme: const ColorScheme.light(primary: _terracotta),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: _darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _terracotta,
      brightness: Brightness.dark,
    ),
  );
}
