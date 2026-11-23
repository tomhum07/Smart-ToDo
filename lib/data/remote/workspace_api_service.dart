import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/workspace_models.dart';

/// REST API Client kết nối tới ASP.NET Core Web API (Render + Supabase PostgreSQL).
class WorkspaceApiService {
  final http.Client _client;

  WorkspaceApiService({http.Client? client})
      : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 20);
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  Future<List<WorkspaceSummary>> getMyWorkspaces(String userUid) async {
    _ensureConfigured();
    final res = await _client
        .get(Uri.parse(ApiConstants.myWorkspacesUrl(userUid)))
        .timeout(_timeout);
    _throwIfError(res, 'Không thể tải danh sách Workspace');
    final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return decoded
        .map((e) => WorkspaceSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkspaceSummary> createWorkspace({
    required String name,
    String description = '',
    required String ownerUid,
    required String ownerName,
    String ownerEmail = '',
  }) async {
    _ensureConfigured();
    final res = await _client
        .post(
          Uri.parse(ApiConstants.workspacesUrl),
          headers: _jsonHeaders,
          body: jsonEncode({
            'name': name,
            'description': description,
            'ownerUid': ownerUid,
            'ownerName': ownerName,
            'ownerEmail': ownerEmail,
          }),
        )
        .timeout(_timeout);
    _throwIfError(res, 'Tạo Workspace thất bại');
    return WorkspaceSummary.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<WorkspaceSummary> joinByCode({
    required String inviteCode,
    required String userUid,
    required String displayName,
    String email = '',
  }) async {
    _ensureConfigured();
    final res = await _client
        .post(
          Uri.parse(ApiConstants.joinWorkspaceUrl),
          headers: _jsonHeaders,
          body: jsonEncode({
            'inviteCode': inviteCode.trim().toUpperCase(),
            'userUid': userUid,
            'displayName': displayName,
            'email': email,
          }),
        )
        .timeout(_timeout);
    _throwIfError(res, 'Không thể tham gia Workspace');
    return WorkspaceSummary.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> leaveWorkspace({
    required String workspaceId,
    required String userUid,
  }) async {
    _ensureConfigured();
    final res = await _client
        .delete(Uri.parse(ApiConstants.leaveWorkspaceUrl(workspaceId, userUid)))
        .timeout(_timeout);
    _throwIfError(res, 'Không thể rời Workspace');
  }

  Future<WorkspaceOverview> getOverview(String workspaceId) async {
    _ensureConfigured();
    final res = await _client
        .get(Uri.parse(ApiConstants.workspaceOverviewUrl(workspaceId)))
        .timeout(_timeout);
    _throwIfError(res, 'Không thể tải dữ liệu Workspace');
    return WorkspaceOverview.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<WorkspaceSchedule> createSchedule({
    required String workspaceId,
    required String title,
    required int dayOfWeek,
    String? scheduleDate,
    bool isRecurring = false,
    required String startTime,
    required String endTime,
    String location = '',
    String note = '',
    String colorHex = '#DBEAFE',
    String createdByName = '',
  }) async {
    _ensureConfigured();
    final res = await _client
        .post(
          Uri.parse(ApiConstants.workspaceSchedulesUrl(workspaceId)),
          headers: _jsonHeaders,
          body: jsonEncode({
            'title': title,
            'dayOfWeek': dayOfWeek,
            'scheduleDate': scheduleDate,
            'isRecurring': isRecurring,
            'startTime': startTime,
            'endTime': endTime,
            'location': location,
            'note': note,
            'colorHex': colorHex,
            'createdByName': createdByName,
          }),
        )
        .timeout(_timeout);
    _throwIfError(res, 'Thêm mục lớn thất bại');
    return WorkspaceSchedule.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> deleteSchedule({
    required String workspaceId,
    required String scheduleId,
  }) async {
    _ensureConfigured();
    final res = await _client
        .delete(
          Uri.parse(ApiConstants.workspaceScheduleItemUrl(workspaceId, scheduleId)),
        )
        .timeout(_timeout);
    _throwIfError(res, 'Xóa mục lớn thất bại');
  }

  Future<WorkspaceTask> createTask({
    required String workspaceId,
    String? scheduleId,
    required String title,
    String description = '',
    int priority = 1,
    int? dueDate,
    String? assigneeUid,
    String? assigneeName,
  }) async {
    _ensureConfigured();
    final res = await _client
        .post(
          Uri.parse(ApiConstants.workspaceTasksUrl(workspaceId)),
          headers: _jsonHeaders,
          body: jsonEncode({
            'scheduleId': scheduleId,
            'title': title,
            'description': description,
            'priority': priority,
            'isCompleted': false,
            'dueDate': dueDate,
            'assigneeUid': assigneeUid,
            'assigneeName': assigneeName,
          }),
        )
        .timeout(_timeout);
    _throwIfError(res, 'Thêm công việc nhóm thất bại');
    return WorkspaceTask.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<WorkspaceTask> toggleTask({
    required String workspaceId,
    required String taskId,
  }) async {
    _ensureConfigured();
    final res = await _client
        .patch(
          Uri.parse(ApiConstants.workspaceTaskToggleUrl(workspaceId, taskId)),
        )
        .timeout(_timeout);
    _throwIfError(res, 'Cập nhật trạng thái công việc thất bại');
    return WorkspaceTask.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> deleteTask({
    required String workspaceId,
    required String taskId,
  }) async {
    _ensureConfigured();
    final res = await _client
        .delete(
          Uri.parse(ApiConstants.workspaceTaskItemUrl(workspaceId, taskId)),
        )
        .timeout(_timeout);
    _throwIfError(res, 'Xóa công việc nhóm thất bại');
  }

  Future<WorkspaceNote> createNote({
    required String workspaceId,
    String? scheduleDate,
    required String title,
    String content = '',
    String colorHex = '#FEF3C7',
    String authorName = '',
  }) async {
    _ensureConfigured();
    final res = await _client
        .post(
          Uri.parse(ApiConstants.workspaceNotesUrl(workspaceId)),
          headers: _jsonHeaders,
          body: jsonEncode({
            'scheduleDate': scheduleDate,
            'title': title,
            'content': content,
            'colorHex': colorHex,
            'authorName': authorName,
          }),
        )
        .timeout(_timeout);
    _throwIfError(res, 'Thêm ghi chú nhóm thất bại');
    return WorkspaceNote.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> deleteNote({
    required String workspaceId,
    required String noteId,
  }) async {
    _ensureConfigured();
    final res = await _client
        .delete(
          Uri.parse(ApiConstants.workspaceNoteItemUrl(workspaceId, noteId)),
        )
        .timeout(_timeout);
    _throwIfError(res, 'Xóa ghi chú nhóm thất bại');
  }

  void _ensureConfigured() {
    if (!ApiConstants.isDotNetConfigured) {
      throw Exception(
        'Chưa gắn URL .NET Web API (Render). Hãy cập nhật DOTNET_API_URL trong api_constants.dart sau khi deploy.',
      );
    }
  }

  void _throwIfError(http.Response res, String fallbackMessage) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map && decoded['message'] != null) {
        throw Exception(decoded['message'].toString());
      }
    } catch (_) {}
    throw Exception('$fallbackMessage (${res.statusCode}).');
  }
}
