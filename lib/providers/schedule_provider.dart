import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/local/database_helper.dart';
import '../data/models/schedule_model.dart';
import '../data/remote/firebase_sync_service.dart';

/// Mô hình lựa chọn Không gian làm việc (Cá nhân hoặc Không gian nhóm từ .NET Web API ở Phase 4).
class WorkspaceOption {
  final String id;
  final String name;
  final String? inviteCode;
  final bool isPersonal;

  const WorkspaceOption({
    required this.id,
    required this.name,
    this.inviteCode,
    this.isPersonal = false,
  });
}

/// Quản lý Thời khóa biểu theo tuần (< > tuần cũ/tương lai, ngày cụ thể + lặp tuần), chọn Workspace & đồng bộ Firebase.
class ScheduleProvider extends ChangeNotifier {
  final DatabaseHelper _db;
  final Uuid _uuid = const Uuid();

  static const WorkspaceOption personalWorkspace = WorkspaceOption(
    id: 'personal',
    name: 'Không gian Cá nhân',
    isPersonal: true,
  );

  List<ScheduleModel> _schedules = [];
  bool _isLoading = false;
  String? _loadedUserId;

  late DateTime _focusedWeekStart; // Thứ 2 của tuần đang xem
  int _selectedDayOfWeek = DateTime.now().weekday; // 1 = T2 -> 7 = CN

  String _activeWorkspaceId = personalWorkspace.id;
  final List<WorkspaceOption> _workspaces = [personalWorkspace];

  ScheduleProvider({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance {
    _focusedWeekStart = _mondayOf(DateTime.now());
  }

  static DateTime _mondayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  bool get isLoading => _isLoading;
  List<ScheduleModel> get allSchedules => List.unmodifiable(_schedules);
  int get totalCount => _schedules.length;
  int get selectedDayOfWeek => _selectedDayOfWeek;

  DateTime get focusedWeekStart => _focusedWeekStart;
  DateTime get selectedDate =>
      _focusedWeekStart.add(Duration(days: _selectedDayOfWeek - 1));

  /// 7 ngày (Thứ 2 -> Chủ nhật) của tuần đang xem.
  List<DateTime> get currentWeekDates => List.generate(
        7,
        (i) => _focusedWeekStart.add(Duration(days: i)),
      );

  bool get isCurrentWeek {
    final thisMonday = _mondayOf(DateTime.now());
    return _focusedWeekStart.year == thisMonday.year &&
        _focusedWeekStart.month == thisMonday.month &&
        _focusedWeekStart.day == thisMonday.day;
  }

  List<WorkspaceOption> get workspaces => List.unmodifiable(_workspaces);

  WorkspaceOption get activeWorkspace => _workspaces.firstWhere(
        (w) => w.id == _activeWorkspaceId,
        orElse: () => personalWorkspace,
      );

  void selectWorkspace(String workspaceId) {
    if (_activeWorkspaceId == workspaceId) return;
    _activeWorkspaceId = workspaceId;
    notifyListeners();
  }

  void setSharedWorkspaces(List<WorkspaceOption> shared) {
    _workspaces
      ..clear()
      ..add(personalWorkspace)
      ..addAll(shared);
    if (!_workspaces.any((w) => w.id == _activeWorkspaceId)) {
      _activeWorkspaceId = personalWorkspace.id;
    }
    notifyListeners();
  }

  void previousWeek() {
    _focusedWeekStart = _focusedWeekStart.subtract(const Duration(days: 7));
    notifyListeners();
  }

  void nextWeek() {
    _focusedWeekStart = _focusedWeekStart.add(const Duration(days: 7));
    notifyListeners();
  }

  void jumpToToday() {
    final now = DateTime.now();
    _focusedWeekStart = _mondayOf(now);
    _selectedDayOfWeek = now.weekday;
    notifyListeners();
  }

  /// Danh sách lịch trình của đúng ngày đang chọn (lọc theo ngày cụ thể & lịch lặp tuần).
  List<ScheduleModel> get schedulesForSelectedDay =>
      schedulesForDate(selectedDate);

  List<ScheduleModel> schedulesForDate(DateTime date) {
    final list = _schedules.where((s) => s.occursOnDate(date)).toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  /// Đếm số lịch trình của đúng ngày [date] (dùng cho dấu chấm . trên thanh tuần).
  int countForDate(DateTime date) =>
      _schedules.where((s) => s.occursOnDate(date)).length;

  int countForDay(int dayOfWeek) =>
      _schedules.where((s) => s.dayOfWeek == dayOfWeek).length;

  void selectDay(int dayOfWeek) {
    if (_selectedDayOfWeek == dayOfWeek) return;
    _selectedDayOfWeek = dayOfWeek;
    notifyListeners();
  }

  Future<void> loadSchedules(String userId, {bool force = false}) async {
    if (!force && _loadedUserId == userId) return;
    _isLoading = true;
    _loadedUserId = userId;
    notifyListeners();

    try {
      _schedules = await _db.getSchedulesByUser(userId);
    } catch (e) {
      debugPrint('Lỗi tải lịch trình: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSchedule({
    ScheduleModel? existing,
    required String userId,
    required String title,
    required int dayOfWeek,
    DateTime? scheduleDate,
    bool isRecurring = false,
    required String startTime,
    required String endTime,
    String location = '',
    String note = '',
    required String colorHex,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final targetDate = scheduleDate ?? selectedDate;
    final isoDate = ScheduleModel.formatIsoDate(targetDate);

    final schedule = ScheduleModel(
      id: existing?.id ?? _uuid.v4(),
      userId: userId,
      title: title.trim(),
      dayOfWeek: targetDate.weekday,
      scheduleDate: isoDate,
      isRecurring: isRecurring,
      startTime: startTime,
      endTime: endTime,
      location: location.trim(),
      note: note.trim(),
      colorHex: colorHex,
      updatedAt: now,
      isDeleted: false,
      isSynced: false,
    );

    await _db.upsertSchedule(schedule);
    _focusedWeekStart = _mondayOf(targetDate);
    _selectedDayOfWeek = targetDate.weekday;
    await loadSchedules(userId, force: true);
    _syncInBackground(userId);
  }

  Future<void> deleteSchedule(ScheduleModel schedule) async {
    await _db.softDeleteSchedule(schedule.id);
    await loadSchedules(schedule.userId, force: true);
    _syncInBackground(schedule.userId);
  }

  /// Nhập hàng loạt tiết học từ mã chia sẻ 6 ký tự (.NET Web API) vào SQLite & đồng bộ Firebase.
  Future<int> importSchedulesFromShare({
    required String userId,
    required List<Map<String, dynamic>> rawItems,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var imported = 0;

    for (final raw in rawItems) {
      final parsed = ScheduleModel.fromJson(raw, idOverride: _uuid.v4())
          .copyWith(
        userId: userId,
        updatedAt: now,
        isDeleted: false,
        isSynced: false,
      );
      if (parsed.title.trim().isEmpty) continue;
      await _db.upsertSchedule(parsed);
      imported++;
    }

    if (imported > 0) {
      await loadSchedules(userId, force: true);
      _syncInBackground(userId);
    }
    return imported;
  }

  void _syncInBackground(String userId) {
    FirebaseSyncService.instance.pushUnsyncedData(userId).catchError((Object e) {
      debugPrint('Đồng bộ ngầm Schedule tạm hoãn (offline): $e');
      return 0;
    });
  }
}
