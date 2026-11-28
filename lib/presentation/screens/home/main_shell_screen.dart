import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../data/remote/firebase_sync_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/note_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/workspace_provider.dart';
import '../dashboard/stats_tab.dart';
import '../notes/notes_tab.dart';
import '../profile/profile_tab.dart';
import '../schedule/schedule_tasks_tab.dart';

/// Khung giao diện chính gồm 4 Tab: Lịch & Việc (hợp nhất Cha->Con), Ghi chú, Thống kê, Hồ sơ.
/// Tự động kích hoạt đồng bộ 2 chiều Firebase Realtime DB & đồng bộ lại khi có mạng.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  String? _loadedForUserId;
  StreamSubscription<DatabaseEvent>? _realtimeSyncSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  static const _titles = [
    'Lịch & Công việc',
    'Ghi chú',
    'Thống kê',
    'Hồ sơ',
  ];

  static const _tabs = <Widget>[
    ScheduleTasksTab(),
    NotesTab(),
    StatsTab(),
    ProfileTab(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.effectiveUserId;

    if (_loadedForUserId != userId) {
      _loadedForUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initializeUserDataAndSync(userId, auth.isFirebaseReady);
      });
    }
  }

  Future<void> _initializeUserDataAndSync(
    String userId,
    bool isFirebaseReady,
  ) async {
    final taskProvider = context.read<TaskProvider>();
    final noteProvider = context.read<NoteProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();
    final workspaceProvider = context.read<WorkspaceProvider>();

    await Future.wait([
      taskProvider.loadTasks(userId, force: true),
      noteProvider.loadNotes(userId, force: true),
      scheduleProvider.loadSchedules(userId, force: true),
      workspaceProvider.restoreCachedWorkspaces(userId),
    ]);

    if (!mounted) return;
    // Đồng bộ ngay các Workspace từ cache cục bộ vào ScheduleProvider (0ms)
    if (workspaceProvider.workspaces.isNotEmpty) {
      scheduleProvider.setSharedWorkspaces(
        workspaceProvider.toWorkspaceOptions(),
      );
    }

    // Sau đó tải mới danh sách Shared Workspace từ .NET Web API (có tự động retry)
    workspaceProvider.loadMyWorkspaces(userId).then((_) {
      if (!mounted) return;
      scheduleProvider.setSharedWorkspaces(
        workspaceProvider.toWorkspaceOptions(),
      );
    });

    await _realtimeSyncSub?.cancel();
    await _connectivitySub?.cancel();

    if (!isFirebaseReady || userId == 'local_guest_user') return;

    final changed = await FirebaseSyncService.instance.syncAll(userId);
    if (changed && mounted) {
      await _reloadAllProviders(userId);
    }

    _realtimeSyncSub = FirebaseSyncService.instance.listenRealtimeUpdates(
      userId,
      () async {
        if (!mounted) return;
        await _reloadAllProviders(userId);
      },
    );

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork && mounted) {
        FirebaseSyncService.instance.syncAll(userId).then((didChange) {
          if (didChange && mounted) {
            _reloadAllProviders(userId);
          }
        });
        workspaceProvider.loadMyWorkspaces(userId).then((_) {
          if (!mounted) return;
          scheduleProvider.setSharedWorkspaces(
            workspaceProvider.toWorkspaceOptions(),
          );
        });
      }
    });
  }

  Future<void> _reloadAllProviders(String userId) async {
    await Future.wait([
      context.read<TaskProvider>().loadTasks(userId, force: true),
      context.read<NoteProvider>().loadNotes(userId, force: true),
      context.read<ScheduleProvider>().loadSchedules(userId, force: true),
    ]);
  }

  @override
  void dispose() {
    _realtimeSyncSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isCurrentlyDark = Theme.of(context).brightness == Brightness.dark;

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final bodyContent = IndexedStack(
          index: _selectedIndex,
          children: _tabs,
        );

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
                          icon: Icon(LucideIcons.calendarCheck2),
                          label: Text('Lịch & Việc'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.stickyNote),
                          label: Text('Ghi chú'),
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
                      icon: Icon(LucideIcons.calendarCheck2),
                      label: 'Lịch & Việc',
                      tooltip: '',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.stickyNote),
                      label: 'Ghi chú',
                      tooltip: '',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.chartColumn),
                      label: 'Thống kê',
                      tooltip: '',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.user),
                      label: 'Hồ sơ',
                      tooltip: '',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
