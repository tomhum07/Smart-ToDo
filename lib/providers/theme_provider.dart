import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý chế độ Sáng / Tối (Dark/Light Theme Toggle) với Provider & ChangeNotifier.
class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'is_dark_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDark = prefs.getBool(_themePrefKey) ?? false;
    _themeMode = savedDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme([bool? enableDark]) async {
    final nextDark = enableDark ?? !isDarkMode;
    _themeMode = nextDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themePrefKey, nextDark);
  }
}
