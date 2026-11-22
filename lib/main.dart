import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'data/services/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/note_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase an toàn: không làm crash app khi chưa gắn google-services.json.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase chưa được cấu hình: $e');
  }

  // Khởi tạo dịch vụ thông báo cục bộ Android (timezone Asia/Ho_Chi_Minh).
  await NotificationService.instance.initialize();

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
        ChangeNotifierProvider<TaskProvider>(create: (_) => TaskProvider()),
        ChangeNotifierProvider<NoteProvider>(create: (_) => NoteProvider()),
        ChangeNotifierProvider<ScheduleProvider>(
          create: (_) => ScheduleProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final platformBrightness = MediaQuery.platformBrightnessOf(context);
          final resolvedBrightness =
              theme.resolveBrightness(platformBrightness);
          final activeShadTheme =
              AppTheme.shadTheme(theme.palette, resolvedBrightness);

          return ShadApp.custom(
            theme: activeShadTheme,
            darkTheme: activeShadTheme,
            appBuilder: (context) {
              return MaterialApp(
                title: 'Smart Todo',
                debugShowCheckedModeBanner: false,
                themeMode: theme.themeMode,
                theme: AppTheme.materialTheme(theme.palette, Brightness.light),
                darkTheme:
                    AppTheme.materialTheme(theme.palette, Brightness.dark),
                initialRoute: AppRoutes.root,
                routes: AppRoutes.routes,
                onGenerateRoute: AppRoutes.onGenerateRoute,
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
