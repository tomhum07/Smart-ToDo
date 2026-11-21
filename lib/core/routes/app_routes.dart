import 'package:flutter/material.dart';

import '../../presentation/screens/auth/auth_gate.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/main_shell_screen.dart';

/// Danh sách route đặt tên phục vụ điều hướng Navigator.pushNamed.
class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';

  static Map<String, WidgetBuilder> get routes => {
        root: (_) => const AuthGate(),
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        home: (_) => const MainShellScreen(),
      };
}
