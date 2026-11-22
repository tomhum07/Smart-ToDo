import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/local/database_helper.dart';
import '../data/models/schedule_model.dart';
import '../data/remote/firebase_sync_service.dart';

/// Quản lý Thời khóa biểu / Lịch trình hằng ngày (Thứ 2 -> Chủ nhật) + đồng bộ Firebase & Import mã chia sẻ.
class ScheduleProvider extends ChangeNotifier {
  final DatabaseHelper _db;
  final Uuid _uuid = const Uuid();

  List<ScheduleModel> _schedules = [];
  bool _isLoading = false;
  String? _loadedUserId;
  int _selectedDayOfWeek = DateTime.now().weekday; // 1 = T2 -> 7 = CN

  ScheduleProvider({DatabaseHelper? db}) : _db = db ?? DatabaseHelper.instance;

  bool get isLoading => _isLoading;
  List<ScheduleModel> get allSchedules => List.unmodifiable(_schedules);
  int get totalCount => _schedules.length;
  int get selectedDayOfWeek => _selectedDayOfWeek;

  /// Danh sách lịch trình của ngày đang chọn, sắp xếp theo giờ bắt đầu.
  List<ScheduleModel> get schedulesForSelectedDay {
    final list = _schedules
        .where((s) => s.dayOfWeek == _selectedDayOfWeek)
        .toList();
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

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
    required String startTime,
    required String endTime,
    String location = '',
    String note = '',
    required String colorHex,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final schedule = ScheduleModel(
      id: existing?.id ?? _uuid.v4(),
      userId: userId,
      title: title.trim(),
      dayOfWeek: dayOfWeek,
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
    _selectedDayOfWeek = dayOfWeek;
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
