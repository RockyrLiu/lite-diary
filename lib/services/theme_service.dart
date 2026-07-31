import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
final themeColorIndexProvider = StateProvider<int>((ref) => 0);

class ThemeColors {
  // 预置色板 — seedColor 列表，0 号位留空给"系统默认"
  static const presetColors = <Color>[
    Colors.transparent, // 占位，表示系统默认
    Color(0xFF2196F3),  // 蓝色
    Color(0xFF607D8B),  // 蓝灰
    Color(0xFF4CAF50),  // 绿色
    Color(0xFF795548),  // 棕色
    Color(0xFF9C27B0),  // 紫色
    Color(0xFFE91E63),  // 粉色
    Color(0xFFFF9800),  // 橙色
  ];

}

class AppTheme {
  static ThemeData lightTheme(Color? seed) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed ?? Colors.lightBlue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: seed?.withAlpha(160) ?? Colors.lightBlue.shade200,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  static ThemeData darkTheme(Color? seed) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed ?? Colors.lightBlue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('theme_mode') == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<int> loadColorIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('theme_color_index') ?? 1; // 默认蓝色 = index 1
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  static Future<void> saveColorIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color_index', index);
  }

  /// 获取当前选中的 seedColor（return null if auto/system default）
  static Color? seedColorFromIndex(int index) {
    if (index <= 0 || index >= ThemeColors.presetColors.length) return null;
    return ThemeColors.presetColors[index];
  }
}
