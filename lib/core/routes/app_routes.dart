import 'package:flutter/material.dart';

import '../../data/models/note_model.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/task_model.dart';
import '../../presentation/screens/auth/auth_gate.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/home/main_shell_screen.dart';
import '../../presentation/screens/notes/note_editor_screen.dart';
import '../../presentation/screens/schedule/schedule_detail_screen.dart';
import '../../presentation/screens/schedule/schedule_form_screen.dart';
import '../../presentation/screens/tasks/task_form_screen.dart';

/// Tham số truyền vào TaskFormScreen (hỗ trợ cả tạo việc nhỏ gắn sẵn vào Mục lớn).
class TaskFormArgs {
  final TaskModel? task;
  final String? initialScheduleId;

  const TaskFormArgs({this.task, this.initialScheduleId});
}

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
  static const String scheduleDetail = '/schedule-detail';

  static Map<String, WidgetBuilder> get routes => {
        root: (_) => const AuthGate(),
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        home: (_) => const MainShellScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case taskForm:
        final args = settings.arguments;
        if (args is TaskFormArgs) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => TaskFormScreen(
              task: args.task,
              initialScheduleId: args.initialScheduleId,
            ),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TaskFormScreen(task: args as TaskModel?),
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
      case scheduleDetail:
        final scheduleId = settings.arguments as String;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ScheduleDetailScreen(scheduleId: scheduleId),
        );
      default:
        return null;
    }
  }
}
