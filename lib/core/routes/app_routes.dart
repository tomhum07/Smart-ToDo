import 'package:flutter/material.dart';

import '../../data/models/note_model.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/task_model.dart';
import '../../presentation/screens/auth/auth_gate.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/main_shell_screen.dart';
import '../../presentation/screens/notes/note_editor_screen.dart';
import '../../presentation/screens/schedule/schedule_form_screen.dart';
import '../../presentation/screens/tasks/task_form_screen.dart';

/// Danh sách route đặt tên phục vụ điều hướng Navigator.pushNamed.
class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String taskForm = '/task-form';
  static const String noteEditor = '/note-editor';
  static const String scheduleForm = '/schedule-form';

  static Map<String, WidgetBuilder> get routes => {
        root: (_) => const AuthGate(),
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        home: (_) => const MainShellScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case taskForm:
        final task = settings.arguments as TaskModel?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TaskFormScreen(task: task),
        );
      case noteEditor:
        final note = settings.arguments as NoteModel?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => NoteEditorScreen(note: note),
        );
      case scheduleForm:
        final schedule = settings.arguments as ScheduleModel?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ScheduleFormScreen(schedule: schedule),
        );
      default:
        return null;
    }
  }
}
