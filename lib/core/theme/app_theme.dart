import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Các bảng màu chủ đạo của shadcn_ui để người dùng tùy biến trong mục Hồ sơ -> Hệ thống.
enum AppColorPalette {
  zinc('Zinc', Color(0xFF18181B)),
  blue('Xanh dương', Color(0xFF2563EB)),
  green('Xanh lá', Color(0xFF16A34A)),
  rose('Hồng đỏ', Color(0xFFE11D48)),
  orange('Cam', Color(0xFFEA580C)),
  violet('Tím', Color(0xFF7C3AED));

  final String label;
  final Color previewColor;

  const AppColorPalette(this.label, this.previewColor);

  static AppColorPalette fromName(String? name) {
    return AppColorPalette.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AppColorPalette.zinc,
    );
  }
}

/// Cấu hình giao diện Sáng / Tối đồng bộ giữa shadcn_ui và Material 3 theo bảng màu đã chọn.
class AppTheme {
  AppTheme._();

  static ShadColorScheme colorSchemeFor(
    AppColorPalette palette,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    switch (palette) {
      case AppColorPalette.zinc:
        return isDark
            ? const ShadZincColorScheme.dark()
            : const ShadZincColorScheme.light();
      case AppColorPalette.blue:
        return isDark
            ? const ShadBlueColorScheme.dark()
            : const ShadBlueColorScheme.light();
      case AppColorPalette.green:
        return isDark
            ? const ShadGreenColorScheme.dark()
            : const ShadGreenColorScheme.light();
      case AppColorPalette.rose:
        return isDark
            ? const ShadRoseColorScheme.dark()
            : const ShadRoseColorScheme.light();
      case AppColorPalette.orange:
        return isDark
            ? const ShadOrangeColorScheme.dark()
            : const ShadOrangeColorScheme.light();
      case AppColorPalette.violet:
        return isDark
            ? const ShadVioletColorScheme.dark()
            : const ShadVioletColorScheme.light();
    }
  }

  static ShadThemeData shadTheme(
    AppColorPalette palette,
    Brightness brightness,
  ) {
    return ShadThemeData(
      brightness: brightness,
      colorScheme: colorSchemeFor(palette, brightness),
    );
  }

  static ThemeData materialTheme(
    AppColorPalette palette,
    Brightness brightness,
  ) {
    final colors = colorSchemeFor(palette, brightness);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: colors.primary,
              onPrimary: colors.primaryForeground,
              secondary: colors.secondary,
              onSecondary: colors.secondaryForeground,
              surface: colors.background,
              onSurface: colors.foreground,
              error: colors.destructive,
              onError: colors.destructiveForeground,
            )
          : ColorScheme.light(
              primary: colors.primary,
              onPrimary: colors.primaryForeground,
              secondary: colors.secondary,
              onSecondary: colors.secondaryForeground,
              surface: colors.background,
              onSurface: colors.foreground,
              error: colors.destructive,
              onError: colors.destructiveForeground,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.card,
        indicatorColor: colors.secondary,
      ),
    );
  }
}
