import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import '../data/models/schedule_model.dart';
import '../data/models/workspace_models.dart';
import '../data/remote/workspace_api_service.dart';
import '../data/services/notification_service.dart';
import 'schedule_provider.dart';

/// Quản lý trạng thái Không gian Chia sẻ Nhóm (Shared Workspace) kết nối .NET Web API,
/// hỗ trợ đồng bộ Realtime (Firebase Realtime DB signal + polling dự phòng) và thông báo hạn chót việc nhóm.
class WorkspaceProvider extends ChangeNotifier {
  final WorkspaceApiService _api;
  final NotificationService _notifications;

  List<WorkspaceSummary> _workspaces = [];
  final Map<String, WorkspaceOverview> _overviewCache = {};
  final Map<String, String> _overviewSignatures = {};
  final Map<String, Set<String>> _knownTaskIdsByWorkspace = {};
  final Map<String, int> _taskRemindMinutes = {};
  final Map<String, String> _scheduledTaskSignatures = {};

  WorkspaceOverview? _activeOverview;
  bool _isLoading = false;
  String? _errorMessage;

  String? _currentUserUid;
  String? _realtimeWorkspaceId;
  bool _isRealtimeActive = false;
  bool _isRefreshingSilently = false;
  Timer? _pollingTimer;
  StreamSubscription<DatabaseEvent>? _rtdbSignalSub;
  int _lastSignalTimestamp = 0;

  WorkspaceProvider({
    WorkspaceApiService? api,
    NotificationService? notifications,
  })  : _api = api ?? WorkspaceApiService(),
        _notifications = notifications ?? NotificationService.instance;

  List<WorkspaceSummary> get workspaces => List.unmodifiable(_workspaces);
  WorkspaceOverview? get activeOverview => _activeOverview;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => ApiConstants.isDotNetConfigured;
  bool get isRealtimeActive => _isRealtimeActive;

  List<WorkspaceOption> toWorkspaceOptions() => _workspaces
      .map(
        (w) => WorkspaceOption(
          id: w.id,
          name: w.name,
          inviteCode: w.inviteCode,
          isPersonal: false,
        ),
      )
      .toList();

  static String _cacheKey(String userUid) => 'cached_workspaces_$userUid';

  Future<void> _restoreCachedWorkspaces(String userUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(userUid));
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => WorkspaceSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (list.isNotEmpty) {
        _workspaces = list;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Bỏ qua lỗi đọc cache Workspace: $e');
    }
  }

  Future<void> _saveCachedWorkspaces(String userUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_workspaces.map((w) => w.toJson()).toList());
      await prefs.setString(_cacheKey(userUid), encoded);
    } catch (e) {
      debugPrint('Bỏ qua lỗi lưu cache Workspace: $e');
    }
  }

  Future<void> loadMyWorkspaces(String userUid) async {
    _currentUserUid = userUid;
    if (!isConfigured || userUid == 'local_guest_user') return;

    // Hiển thị ngay danh sách Workspace đã cache cục bộ (0ms) trong lúc chờ server Render thức dậy
    if (_workspaces.isEmpty) {
      await _restoreCachedWorkspaces(userUid);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _workspaces = await _api.getMyWorkspaces(userUid);
      await _saveCachedWorkspaces(userUid);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOverview(String workspaceId, {String? currentUserUid}) async {
    if (currentUserUid != null) {
      _currentUserUid = currentUserUid;
    }
    if (!isConfigured || workspaceId == ScheduleProvider.personalWorkspace.id) {
      stopRealtimeSync();
      _activeOverview = null;
      notifyListeners();
      return;
    }

    // Hiển thị ngay dữ liệu đã cache để chuyển Workspace mượt 0ms, sau đó làm mới ngầm
    final cached = _overviewCache[workspaceId];
    if (cached != null) {
      _activeOverview = cached;
      _errorMessage = null;
      notifyListeners();
    } else {
      _activeOverview = null;
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final fresh = await _api.getOverview(workspaceId);
      _applyOverview(fresh, isRealtimeUpdate: false);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Bắt đầu đồng bộ Realtime cho 1 Shared Workspace (Firebase RTDB pulse + polling 4 giây).
  void startRealtimeSync(String workspaceId, {required String currentUserUid}) {
    _currentUserUid = currentUserUid;
    if (!isConfigured || workspaceId == ScheduleProvider.personalWorkspace.id) {
      stopRealtimeSync();
      return;
    }
    if (_realtimeWorkspaceId == workspaceId && _isRealtimeActive) return;

    stopRealtimeSync(notify: false);
    _realtimeWorkspaceId = workspaceId;
    _isRealtimeActive = true;
    _lastSignalTimestamp = 0;

    // 1. Lắng nghe xung báo thay đổi tức thì qua Firebase Realtime Database (< 300ms)
    if (Firebase.apps.isNotEmpty) {
      try {
        _rtdbSignalSub = FirebaseDatabase.instance
            .ref('workspaces_sync/$workspaceId/lastUpdated')
            .onValue
            .listen(
          (event) {
            final value = event.snapshot.value;
            final ts = value is num ? value.toInt() : 0;
            if (ts > 0 && ts != _lastSignalTimestamp) {
              final wasInitialized = _lastSignalTimestamp != 0;
              _lastSignalTimestamp = ts;
              if (wasInitialized) {
                _silentRefresh(workspaceId);
              }
            }
          },
          onError: (Object e) {
            debugPrint('Firebase RTDB workspace pulse không khả dụng, dùng polling: $e');
          },
        );
      } catch (e) {
        debugPrint('Bỏ qua RTDB listener cho workspace: $e');
      }
    }

    // 2. Polling dự phòng mỗi 4 giây (chỉ notifyListeners nếu dữ liệu thực sự thay đổi)
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _silentRefresh(workspaceId);
    });

    notifyListeners();
  }

  /// Tạm dừng polling khi app vào nền để tiết kiệm pin/mạng.
  void pauseRealtimeSync() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Tiếp tục polling và làm mới ngay khi app quay lại foreground.
  void resumeRealtimeSync() {
    final wsId = _realtimeWorkspaceId;
    if (!_isRealtimeActive || wsId == null) return;
    _pollingTimer?.cancel();
    _silentRefresh(wsId);
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _silentRefresh(wsId);
    });
  }

  /// Dừng đồng bộ Realtime (có thể giới hạn chỉ dừng nếu vẫn đang đồng bộ đúng workspaceId đó).
  void stopRealtimeSync({String? onlyIfWorkspaceId, bool notify = true}) {
    if (onlyIfWorkspaceId != null &&
        _realtimeWorkspaceId != onlyIfWorkspaceId) {
      return;
    }
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _rtdbSignalSub?.cancel();
    _rtdbSignalSub = null;
    _realtimeWorkspaceId = null;
    if (_isRealtimeActive) {
      _isRealtimeActive = false;
      if (notify) notifyListeners();
    }
  }

  Future<void> _silentRefresh(String workspaceId) async {
    if (_isRefreshingSilently || !isConfigured) return;
    if (_realtimeWorkspaceId != workspaceId) return;

    _isRefreshingSilently = true;
    try {
      final fresh = await _api.getOverview(workspaceId);
      if (_realtimeWorkspaceId != workspaceId) return;
      final changed = _applyOverview(fresh, isRealtimeUpdate: true);
      if (changed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Làm mới ngầm Workspace tạm hoãn: $e');
    } finally {
      _isRefreshingSilently = false;
    }
  }

  /// Phát xung báo thay đổi lên Firebase Realtime DB để các máy khác trong nhóm cập nhật ngay lập tức.
  Future<void> _broadcastWorkspacePulse(String workspaceId) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      _lastSignalTimestamp = now;
      await FirebaseDatabase.instance
          .ref('workspaces_sync/$workspaceId/lastUpdated')
          .set(now)
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Bỏ qua gửi xung RTDB workspace: $e');
    }
  }

  bool _applyOverview(
    WorkspaceOverview fresh, {
    required bool isRealtimeUpdate,
  }) {
    final wsId = fresh.workspace.id;
    final newSig = _computeSignature(fresh);
    final oldSig = _overviewSignatures[wsId];
    final previousTaskIds = _knownTaskIdsByWorkspace[wsId];

    _overviewCache[wsId] = fresh;
    _overviewSignatures[wsId] = newSig;
    if (_activeOverview == null || _activeOverview!.workspace.id == wsId) {
      _activeOverview = fresh;
    }

    final changed = oldSig != newSig;
    // Chỉ đồng bộ lại lịch thông báo khi dữ liệu thực sự thay đổi (tránh hủy & đặt lại báo thức mỗi 4 giây!)
    if (changed || previousTaskIds == null) {
      _syncWorkspaceTaskNotifications(
        fresh,
        previousTaskIds: previousTaskIds,
        notifyNewAssignments: isRealtimeUpdate && previousTaskIds != null,
      );
      _knownTaskIdsByWorkspace[wsId] = fresh.tasks.map((t) => t.id).toSet();
    }

    return changed;
  }

  String _computeSignature(WorkspaceOverview o) {
    final buf = StringBuffer()
      ..write(o.workspace.id)
      ..write('|m:')
      ..write(o.members.length);
    for (final m in o.members) {
      buf.write(',${m.id}:${m.displayName}');
    }
    buf.write('|s:${o.schedules.length}');
    for (final s in o.schedules) {
      buf.write(',${s.id}:${s.updatedAt}');
    }
    buf.write('|t:${o.tasks.length}');
    for (final t in o.tasks) {
      buf.write(',${t.id}:${t.isCompleted}:${t.dueDate}:${t.updatedAt}');
    }
    buf.write('|n:${o.notes.length}');
    for (final n in o.notes) {
      buf.write(',${n.id}:${n.updatedAt}');
    }
    return buf.toString();
  }

  void _syncWorkspaceTaskNotifications(
    WorkspaceOverview overview, {
    Set<String>? previousTaskIds,
    required bool notifyNewAssignments,
  }) {
    final uid = _currentUserUid;
    final currentIds = overview.tasks.map((t) => t.id).toSet();

    // Hủy thông báo của các công việc đã bị xóa khỏi workspace
    if (previousTaskIds != null) {
      for (final oldId in previousTaskIds) {
        if (!currentIds.contains(oldId)) {
          _scheduledTaskSignatures.remove(oldId);
          _notifications.cancelWorkspaceTaskReminder(oldId);
        }
      }
    }

    for (final task in overview.tasks) {
      final isForMe = uid == null ||
          task.assigneeUid == null ||
          task.assigneeUid!.isEmpty ||
          task.assigneeUid == uid;

      if (task.isCompleted || !isForMe) {
        if (_scheduledTaskSignatures.remove(task.id) != null) {
          _notifications.cancelWorkspaceTaskReminder(task.id);
        }
        continue;
      }

      // Nếu có việc mới được giao cho mình qua realtime sync -> bắn thông báo ngay
      if (notifyNewAssignments &&
          previousTaskIds != null &&
          !previousTaskIds.contains(task.id) &&
          uid != null &&
          task.assigneeUid == uid) {
        _notifications.showWorkspaceTaskAssignedNotification(
          task,
          workspaceName: overview.workspace.name,
        );
      }

      // Chỉ đặt lại lịch thông báo hạn chót nếu cấu hình hạn chót/nhắc trước của task này thay đổi
      if (task.dueDate != null) {
        final remindMins = _taskRemindMinutes[task.id] ?? 10;
        final taskSig = '${task.dueDate}|${task.title}|$remindMins';
        if (_scheduledTaskSignatures[task.id] != taskSig) {
          _scheduledTaskSignatures[task.id] = taskSig;
          _notifications.scheduleWorkspaceTaskReminder(
            task,
            workspaceName: overview.workspace.name,
            remindBeforeMinutes: remindMins,
          );
        }
      } else if (_scheduledTaskSignatures.remove(task.id) != null) {
        _notifications.cancelWorkspaceTaskReminder(task.id);
      }
    }
  }

  Future<WorkspaceSummary> createWorkspace({
    required String name,
    String description = '',
    required String ownerUid,
    required String ownerName,
    String ownerEmail = '',
  }) async {
    final created = await _api.createWorkspace(
      name: name,
      description: description,
      ownerUid: ownerUid,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
    );
    await loadMyWorkspaces(ownerUid);
    await loadOverview(created.id, currentUserUid: ownerUid);
    return created;
  }

  Future<WorkspaceSummary> joinByCode({
    required String inviteCode,
    required String userUid,
    required String displayName,
    String email = '',
  }) async {
    final joined = await _api.joinByCode(
      inviteCode: inviteCode,
      userUid: userUid,
      displayName: displayName,
      email: email,
    );
    await _broadcastWorkspacePulse(joined.id);
    await loadMyWorkspaces(userUid);
    await loadOverview(joined.id, currentUserUid: userUid);
    return joined;
  }

  Future<void> leaveWorkspace({
    required String workspaceId,
    required String userUid,
  }) async {
    await _api.leaveWorkspace(workspaceId: workspaceId, userUid: userUid);
    await _broadcastWorkspacePulse(workspaceId);
    _overviewCache.remove(workspaceId);
    _overviewSignatures.remove(workspaceId);
    if (_activeOverview?.workspace.id == workspaceId) {
      stopRealtimeSync();
      _activeOverview = null;
    }
    await loadMyWorkspaces(userUid);
  }

  /// Cập nhật cache cục bộ ngay lập tức (Optimistic UI) để thao tác mượt 0ms,
  /// không cần chờ gọi lại GET /overview.
  void _updateCachedOverview(
    String workspaceId,
    WorkspaceOverview Function(WorkspaceOverview current) transform,
  ) {
    final current = _overviewCache[workspaceId] ??
        (_activeOverview?.workspace.id == workspaceId ? _activeOverview : null);
    if (current == null) return;
    final updated = transform(current);
    _overviewCache[workspaceId] = updated;
    _overviewSignatures[workspaceId] = _computeSignature(updated);
    _knownTaskIdsByWorkspace[workspaceId] =
        updated.tasks.map((t) => t.id).toSet();
    if (_activeOverview?.workspace.id == workspaceId) {
      _activeOverview = updated;
    }
    notifyListeners();
  }

  /// Phát xung RTDB ngầm (fire-and-forget) để không bao giờ chặn UI.
  void _broadcastWorkspacePulseInBackground(String workspaceId) {
    unawaited(_broadcastWorkspacePulse(workspaceId));
  }

  Future<void> addSchedule({
    required String workspaceId,
    required String title,
    required DateTime date,
    bool isRecurring = false,
    required String startTime,
    required String endTime,
    String location = '',
    String note = '',
    String colorHex = '#DBEAFE',
    required String createdByName,
  }) async {
    final created = await _api.createSchedule(
      workspaceId: workspaceId,
      title: title,
      dayOfWeek: date.weekday,
      scheduleDate: ScheduleModel.formatIsoDate(date),
      isRecurring: isRecurring,
      startTime: startTime,
      endTime: endTime,
      location: location,
      note: note,
      colorHex: colorHex,
      createdByName: createdByName,
    );
    _updateCachedOverview(workspaceId, (cur) {
      final list = [...cur.schedules, created]
        ..sort((a, b) {
          final d = a.dayOfWeek.compareTo(b.dayOfWeek);
          return d != 0 ? d : a.startTime.compareTo(b.startTime);
        });
      return cur.copyWith(schedules: list);
    });
    _broadcastWorkspacePulseInBackground(workspaceId);
  }

  Future<void> deleteSchedule({
    required String workspaceId,
    required String scheduleId,
  }) async {
    final previous = _overviewCache[workspaceId];
    // Xóa ngay trên UI (Optimistic)
    _updateCachedOverview(
      workspaceId,
      (cur) => cur.copyWith(
        schedules: cur.schedules.where((s) => s.id != scheduleId).toList(),
        tasks: cur.tasks.where((t) => t.scheduleId != scheduleId).toList(),
      ),
    );
    try {
      await _api.deleteSchedule(
        workspaceId: workspaceId,
        scheduleId: scheduleId,
      );
      _broadcastWorkspacePulseInBackground(workspaceId);
    } catch (e) {
      // Hoàn tác nếu server lỗi
      if (previous != null) {
        _overviewCache[workspaceId] = previous;
        _overviewSignatures[workspaceId] = _computeSignature(previous);
        if (_activeOverview?.workspace.id == workspaceId) {
          _activeOverview = previous;
        }
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> addTask({
    required String workspaceId,
    String? scheduleId,
    required String title,
    String description = '',
    int priority = 1,
    int? dueDate,
    int remindBeforeMinutes = 10,
    String? assigneeUid,
    String? assigneeName,
  }) async {
    final created = await _api.createTask(
      workspaceId: workspaceId,
      scheduleId: scheduleId,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      assigneeUid: assigneeUid,
      assigneeName: assigneeName,
    );

    if (dueDate != null) {
      _taskRemindMinutes[created.id] = remindBeforeMinutes;
      _scheduledTaskSignatures[created.id] =
          '${created.dueDate}|${created.title}|$remindBeforeMinutes';
      final wsName = _activeOverview?.workspace.name ?? 'Nhóm';
      unawaited(
        _notifications.scheduleWorkspaceTaskReminder(
          created,
          workspaceName: wsName,
          remindBeforeMinutes: remindBeforeMinutes,
        ),
      );
    }

    _updateCachedOverview(workspaceId, (cur) {
      final list = [...cur.tasks, created]..sort(_compareWorkspaceTasks);
      return cur.copyWith(tasks: list);
    });
    _broadcastWorkspacePulseInBackground(workspaceId);
  }

  Future<void> toggleTask({
    required String workspaceId,
    required String taskId,
  }) async {
    final previous = _overviewCache[workspaceId];
    WorkspaceTask? optimisticTask;

    // Lật trạng thái checkbox ngay lập tức (0ms)
    _updateCachedOverview(workspaceId, (cur) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final list = cur.tasks.map((t) {
        if (t.id != taskId) return t;
        optimisticTask = t.copyWith(isCompleted: !t.isCompleted, updatedAt: now);
        return optimisticTask!;
      }).toList()
        ..sort(_compareWorkspaceTasks);
      return cur.copyWith(tasks: list);
    });

    if (optimisticTask != null) {
      if (optimisticTask!.isCompleted) {
        _scheduledTaskSignatures.remove(taskId);
        unawaited(_notifications.cancelWorkspaceTaskReminder(taskId));
      } else if (optimisticTask!.dueDate != null) {
        final wsName = _activeOverview?.workspace.name ?? 'Nhóm';
        final remindMins = _taskRemindMinutes[taskId] ?? 10;
        _scheduledTaskSignatures[taskId] =
            '${optimisticTask!.dueDate}|${optimisticTask!.title}|$remindMins';
        unawaited(
          _notifications.scheduleWorkspaceTaskReminder(
            optimisticTask!,
            workspaceName: wsName,
            remindBeforeMinutes: remindMins,
          ),
        );
      }
    }

    try {
      final updated = await _api.toggleTask(
        workspaceId: workspaceId,
        taskId: taskId,
      );
      _updateCachedOverview(workspaceId, (cur) {
        final list = cur.tasks
            .map((t) => t.id == taskId ? updated : t)
            .toList()
          ..sort(_compareWorkspaceTasks);
        return cur.copyWith(tasks: list);
      });
      _broadcastWorkspacePulseInBackground(workspaceId);
    } catch (e) {
      if (previous != null) {
        _overviewCache[workspaceId] = previous;
        _overviewSignatures[workspaceId] = _computeSignature(previous);
        if (_activeOverview?.workspace.id == workspaceId) {
          _activeOverview = previous;
        }
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> deleteTask({
    required String workspaceId,
    required String taskId,
  }) async {
    final previous = _overviewCache[workspaceId];
    _scheduledTaskSignatures.remove(taskId);
    _taskRemindMinutes.remove(taskId);
    unawaited(_notifications.cancelWorkspaceTaskReminder(taskId));

    // Xóa ngay trên UI (0ms)
    _updateCachedOverview(
      workspaceId,
      (cur) => cur.copyWith(
        tasks: cur.tasks.where((t) => t.id != taskId).toList(),
      ),
    );

    try {
      await _api.deleteTask(workspaceId: workspaceId, taskId: taskId);
      _broadcastWorkspacePulseInBackground(workspaceId);
    } catch (e) {
      if (previous != null) {
        _overviewCache[workspaceId] = previous;
        _overviewSignatures[workspaceId] = _computeSignature(previous);
        if (_activeOverview?.workspace.id == workspaceId) {
          _activeOverview = previous;
        }
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> addNote({
    required String workspaceId,
    required DateTime date,
    required String title,
    String content = '',
    String colorHex = '#FEF3C7',
    required String authorName,
  }) async {
    final created = await _api.createNote(
      workspaceId: workspaceId,
      scheduleDate: ScheduleModel.formatIsoDate(date),
      title: title,
      content: content,
      colorHex: colorHex,
      authorName: authorName,
    );
    _updateCachedOverview(
      workspaceId,
      (cur) => cur.copyWith(notes: [created, ...cur.notes]),
    );
    _broadcastWorkspacePulseInBackground(workspaceId);
  }

  Future<void> deleteNote({
    required String workspaceId,
    required String noteId,
  }) async {
    final previous = _overviewCache[workspaceId];
    _updateCachedOverview(
      workspaceId,
      (cur) => cur.copyWith(
        notes: cur.notes.where((n) => n.id != noteId).toList(),
      ),
    );
    try {
      await _api.deleteNote(workspaceId: workspaceId, noteId: noteId);
      _broadcastWorkspacePulseInBackground(workspaceId);
    } catch (e) {
      if (previous != null) {
        _overviewCache[workspaceId] = previous;
        _overviewSignatures[workspaceId] = _computeSignature(previous);
        if (_activeOverview?.workspace.id == workspaceId) {
          _activeOverview = previous;
        }
        notifyListeners();
      }
      rethrow;
    }
  }

  static int _compareWorkspaceTasks(WorkspaceTask a, WorkspaceTask b) {
    if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    if (a.dueDate != null && b.dueDate != null) {
      return a.dueDate!.compareTo(b.dueDate!);
    }
    if (a.dueDate != null) return -1;
    if (b.dueDate != null) return 1;
    return b.updatedAt.compareTo(a.updatedAt);
  }

  void reset() {
    stopRealtimeSync(notify: false);
    _workspaces = [];
    _overviewCache.clear();
    _overviewSignatures.clear();
    _knownTaskIdsByWorkspace.clear();
    _taskRemindMinutes.clear();
    _scheduledTaskSignatures.clear();
    _activeOverview = null;
    _isLoading = false;
    _errorMessage = null;
    _currentUserUid = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopRealtimeSync(notify: false);
    super.dispose();
  }
}
