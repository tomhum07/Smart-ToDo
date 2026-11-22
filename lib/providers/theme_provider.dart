import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../data/services/notification_service.dart';

/// Quản lý chế độ Sáng / Tối / Hệ thống, bảng màu giao diện và bật/tắt thông báo.
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode_v2';
  static const String _paletteKey = 'color_palette';
  static const String _notificationsEnabledKey = 'notifications_enabled';

  ThemeMode _themeMode = ThemeMode.system;
  AppColorPalette _palette = AppColorPalette.zinc;
  bool _notificationsEnabled = true;

  ThemeMode get themeMode => _themeMode;
  AppColorPalette get palette => _palette;
  bool get notificationsEnabled => _notificationsEnabled;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Brightness resolveBrightness(Brightness platformBrightness) {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return platformBrightness;
    }
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final modeStr = prefs.getString(_themeModeKey);
    switch (modeStr) {
      case 'light':
        _themeMode = ThemeMode.light;
      case 'dark':
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }

    _palette = AppColorPalette.fromName(prefs.getString(_paletteKey));
    _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? true;
    await NotificationService.instance.setEnabled(_notificationsEnabled);

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, value);
  }

  /// Nút đổi nhanh Sáng/Tối trên thanh AppBar.
  Future<void> toggleTheme([bool? enableDark]) async {
    final nextDark = enableDark ?? (_themeMode != ThemeMode.dark);
    await setThemeMode(nextDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setPalette(AppColorPalette palette) async {
    if (_palette == palette) return;
    _palette = palette;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paletteKey, palette.name);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    await NotificationService.instance.setEnabled(enabled);
  }
}
