import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/note_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/theme_provider.dart';
import '../dashboard/stats_tab.dart';
import '../notes/notes_tab.dart';
import '../profile/profile_tab.dart';
import '../schedule/schedule_tab.dart';
import '../tasks/tasks_tab.dart';

/// Khung giao diện chính gồm 5 Tab: Công việc, Ghi chú, Lịch trình, Thống kê, Hồ sơ.
/// Tự động thích ứng xoay dọc (NavigationBar) / xoay ngang (NavigationRail) qua OrientationBuilder.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  String? _loadedForUserId;

  static const _titles = [
    'Công việc',
    'Ghi chú',
    'Lịch trình',
    'Thống kê',
    'Hồ sơ',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().effectiveUserId;
    if (_loadedForUserId != userId) {
      _loadedForUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TaskProvider>().loadTasks(userId);
        context.read<NoteProvider>().loadNotes(userId);
        context.read<ScheduleProvider>().loadSchedules(userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isCurrentlyDark = Theme.of(context).brightness == Brightness.dark;

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final bodyContent = _buildCurrentTab();

        return Scaffold(
          appBar: AppBar(
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_titles[_selectedIndex]),
            ),
            actions: [
              IconButton(
                tooltip: isCurrentlyDark
                    ? 'Chuyển sang giao diện Sáng'
                    : 'Chuyển sang giao diện Tối',
                onPressed: () => themeProvider.toggleTheme(!isCurrentlyDark),
                icon: Icon(
                  isCurrentlyDark ? LucideIcons.sun : LucideIcons.moon,
                ),
              ),
            ],
          ),
          body: isLandscape
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (i) =>
                          setState(() => _selectedIndex = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.listTodo),
                          label: Text('Công việc'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.stickyNote),
                          label: Text('Ghi chú'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.calendarDays),
                          label: Text('Lịch trình'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.chartColumn),
                          label: Text('Thống kê'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.user),
                          label: Text('Hồ sơ'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: bodyContent),
                  ],
                )
              : bodyContent,
          bottomNavigationBar: isLandscape
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(LucideIcons.listTodo),
                      label: 'Công việc',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.stickyNote),
                      label: 'Ghi chú',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.calendarDays),
                      label: 'Lịch trình',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.chartColumn),
                      label: 'Thống kê',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.user),
                      label: 'Hồ sơ',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return const TasksTab();
      case 1:
        return const NotesTab();
      case 2:
        return const ScheduleTab();
      case 3:
        return const StatsTab();
      default:
        return const ProfileTab();
    }
  }
}
