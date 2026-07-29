import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

/// 0=浅蓝, 1=白色, 2=浅绿
final themeColorIndexProvider = StateProvider<int>((ref) => 0);

class ThemeColors {
  static const colors = [Colors.lightBlue, Colors.grey, Colors.teal];
  static const names = ['浅蓝', '白色', '浅绿'];
}

class AppTheme {
  static Color _seedColor(int index) => ThemeColors.colors[index.clamp(0, 2)];

  static ThemeData lightTheme(int colorIndex) {
    final seed = _seedColor(colorIndex);
    final isWhite = colorIndex == 1;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: isWhite ? Colors.blueGrey : seed,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  static ThemeData darkTheme(int colorIndex) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor(colorIndex), brightness: Brightness.dark),
      useMaterial3: true,
    );
  }

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode') ?? 'light';
    return mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<int> loadColorIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('theme_color_index') ?? 0;
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  static Future<void> saveColorIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color_index', index);
  }
}
