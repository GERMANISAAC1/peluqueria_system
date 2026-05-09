import 'package:flutter/material.dart';

class AppTheme {
  static const gold = Color(0xFFB8860B);

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: gold),
       cardTheme: const CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark),
  );
}
