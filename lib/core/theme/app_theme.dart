import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Cấu hình giao diện Sáng / Tối đồng bộ giữa shadcn_ui (Zinc palette) và Material 3.
class AppTheme {
  AppTheme._();

  static const ShadZincColorScheme _lightColors = ShadZincColorScheme.light();
  static const ShadZincColorScheme _darkColors = ShadZincColorScheme.dark();

  static ShadThemeData get lightTheme => ShadThemeData(
        brightness: Brightness.light,
        colorScheme: _lightColors,
      );

  static ShadThemeData get darkTheme => ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: _darkColors,
      );

  static ThemeData get materialLightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _lightColors.background,
        colorScheme: ColorScheme.light(
          primary: _lightColors.primary,
          onPrimary: _lightColors.primaryForeground,
          secondary: _lightColors.secondary,
          onSecondary: _lightColors.secondaryForeground,
          surface: _lightColors.background,
          onSurface: _lightColors.foreground,
          error: _lightColors.destructive,
          onError: _lightColors.destructiveForeground,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _lightColors.background,
          foregroundColor: _lightColors.foreground,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _lightColors.card,
          indicatorColor: _lightColors.secondary,
        ),
      );

  static ThemeData get materialDarkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _darkColors.background,
        colorScheme: ColorScheme.dark(
          primary: _darkColors.primary,
          onPrimary: _darkColors.primaryForeground,
          secondary: _darkColors.secondary,
          onSecondary: _darkColors.secondaryForeground,
          surface: _darkColors.background,
          onSurface: _darkColors.foreground,
          error: _darkColors.destructive,
          onError: _darkColors.destructiveForeground,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _darkColors.background,
          foregroundColor: _darkColors.foreground,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: _darkColors.card,
          indicatorColor: _darkColors.secondary,
        ),
      );
}
