import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase an toàn: không làm crash app khi nhóm chưa thêm
  // google-services.json / firebase_options.dart ở bước Setup bên ngoài.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase chưa được cấu hình: $e');
  }

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(SmartTodoApp(themeProvider: themeProvider));
}

class SmartTodoApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const SmartTodoApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final activeShadTheme =
              theme.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

          return ShadApp.custom(
            theme: activeShadTheme,
            darkTheme: activeShadTheme,
            appBuilder: (context) {
              return MaterialApp(
                title: 'Smart Todo',
                debugShowCheckedModeBanner: false,
                themeMode: theme.themeMode,
                theme: AppTheme.materialLightTheme,
                darkTheme: AppTheme.materialDarkTheme,
                initialRoute: AppRoutes.root,
                routes: AppRoutes.routes,
                builder: (context, child) {
                  return ShadAppBuilder(child: child!);
                },
              );
            },
          );
        },
      ),
    );
  }
}
