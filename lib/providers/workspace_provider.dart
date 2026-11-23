import 'package:flutter/foundation.dart';

import '../core/constants/api_constants.dart';
import '../data/models/schedule_model.dart';
import '../data/models/workspace_models.dart';
import '../data/remote/workspace_api_service.dart';
import 'schedule_provider.dart';

/// Quản lý trạng thái Không gian Chia sẻ Nhóm (Shared Workspace) kết nối .NET Web API.
class WorkspaceProvider extends ChangeNotifier {
  final WorkspaceApiService _api;

  List<WorkspaceSummary> _workspaces = [];
  final Map<String, WorkspaceOverview> _overviewCache = {};
  WorkspaceOverview? _activeOverview;
  bool _isLoading = false;
  String? _errorMessage;

  WorkspaceProvider({WorkspaceApiService? api})
      : _api = api ?? WorkspaceApiService();

  List<WorkspaceSummary> get workspaces => List.unmodifiable(_workspaces);
  WorkspaceOverview? get activeOverview => _activeOverview;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => ApiConstants.isDotNetConfigured;

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

  Future<void> loadMyWorkspaces(String userUid) async {
    if (!isConfigured || userUid == 'local_guest_user') return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _workspaces = await _api.getMyWorkspaces(userUid);
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOverview(String workspaceId) async {
    if (!isConfigured || workspaceId == ScheduleProvider.personalWorkspace.id) {
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
      _overviewCache[workspaceId] = fresh;
      _activeOverview = fresh;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
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
    await loadOverview(created.id);
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
    await loadMyWorkspaces(userUid);
    await loadOverview(joined.id);
    return joined;
  }

  Future<void> leaveWorkspace({
    required String workspaceId,
    required String userUid,
  }) async {
    await _api.leaveWorkspace(workspaceId: workspaceId, userUid: userUid);
    _overviewCache.remove(workspaceId);
    if (_activeOverview?.workspace.id == workspaceId) {
      _activeOverview = null;
    }
    await loadMyWorkspaces(userUid);
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
    await _api.createSchedule(
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
    await loadOverview(workspaceId);
  }

  Future<void> deleteSchedule({
    required String workspaceId,
    required String scheduleId,
  }) async {
    await _api.deleteSchedule(workspaceId: workspaceId, scheduleId: scheduleId);
    await loadOverview(workspaceId);
  }

  Future<void> addTask({
    required String workspaceId,
    String? scheduleId,
    required String title,
    String description = '',
    int priority = 1,
    int? dueDate,
    String? assigneeUid,
    String? assigneeName,
  }) async {
    await _api.createTask(
      workspaceId: workspaceId,
      scheduleId: scheduleId,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      assigneeUid: assigneeUid,
      assigneeName: assigneeName,
    );
    await loadOverview(workspaceId);
  }

  Future<void> toggleTask({
    required String workspaceId,
    required String taskId,
  }) async {
    await _api.toggleTask(workspaceId: workspaceId, taskId: taskId);
    await loadOverview(workspaceId);
  }

  Future<void> deleteTask({
    required String workspaceId,
    required String taskId,
  }) async {
    await _api.deleteTask(workspaceId: workspaceId, taskId: taskId);
    await loadOverview(workspaceId);
  }

  Future<void> addNote({
    required String workspaceId,
    required DateTime date,
    required String title,
    String content = '',
    String colorHex = '#FEF3C7',
    required String authorName,
  }) async {
    await _api.createNote(
      workspaceId: workspaceId,
      scheduleDate: ScheduleModel.formatIsoDate(date),
      title: title,
      content: content,
      colorHex: colorHex,
      authorName: authorName,
    );
    await loadOverview(workspaceId);
  }

  Future<void> deleteNote({
    required String workspaceId,
    required String noteId,
  }) async {
    await _api.deleteNote(workspaceId: workspaceId, noteId: noteId);
    await loadOverview(workspaceId);
  }
}
