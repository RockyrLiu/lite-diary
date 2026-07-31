import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
final themeColorIndexProvider = StateProvider<int>((ref) => 0);

class ThemeColors {
  static const presetColors = <Color>[
    Colors.transparent,
    Color(0xFF2196F3),
    Color(0xFF607D8B),
    Color(0xFF4CAF50),
    Color(0xFF795548),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFFFF9800),
  ];
}

class AppTheme {
  static ThemeData _base(ThemeData base, ColorScheme colorScheme) {
    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0.5,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
      ),
      cardTheme: CardThemeData(
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData lightTheme(Color? seed) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed ?? Colors.lightBlue,
      brightness: Brightness.light,
    );
    return _base(ThemeData(useMaterial3: true, colorScheme: colorScheme), colorScheme);
  }

  static ThemeData darkTheme(Color? seed) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed ?? Colors.lightBlue,
      brightness: Brightness.dark,
    );
    return _base(ThemeData(useMaterial3: true, colorScheme: colorScheme), colorScheme);
  }

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('theme_mode') == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<int> loadColorIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('theme_color_index') ?? 1;
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  static Future<void> saveColorIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color_index', index);
  }

  static Color? seedColorFromIndex(int index) {
    if (index <= 0 || index >= ThemeColors.presetColors.length) return null;
    return ThemeColors.presetColors[index];
  }
}
