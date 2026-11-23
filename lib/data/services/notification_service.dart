import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';

/// Dịch vụ thông báo đẩy cục bộ chính xác theo giây trên Android, hỗ trợ nhắc lại nhiều lần.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int maxRepeatOccurrences = 10;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _isEnabled = true;

  bool get isEnabled => _isEnabled;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'smart_todo_reminders_v2',
    'Nhắc hạn chót công việc',
    channelDescription: 'Thông báo nhắc nhở chính xác trước hạn chót công việc',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(settings: initSettings);

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();

      _initialized = true;
    } catch (e) {
      debugPrint('Không thể khởi tạo NotificationService: $e');
    }
  }

  /// Bật hoặc tắt toàn bộ thông báo cục bộ theo cài đặt trong Hồ sơ -> Hệ thống.
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!enabled && _initialized) {
      try {
        await _plugin.cancelAll();
      } catch (e) {
        debugPrint('Lỗi hủy toàn bộ thông báo: $e');
      }
    }
  }

  /// Tạo notification ID ổn định cho từng lần nhắc (0 .. maxRepeatOccurrences - 1).
  int _notificationIdFor(String taskId, int occurrenceIndex) {
    final base = (taskId.hashCode & 0x07FFFFFF) * maxRepeatOccurrences;
    return base + occurrenceIndex;
  }

  /// Đặt lịch thông báo nhắc trước hạn chót + chuỗi nhắc lại (repeatCount lần, cách nhau repeatIntervalSeconds).
  Future<void> scheduleTaskReminder(TaskModel task) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    // Luôn hủy toàn bộ chuỗi cũ của công việc này trước khi đặt lịch mới
    await cancelTaskReminder(task.id);

    if (!_isEnabled ||
        task.isCompleted ||
        task.isDeleted ||
        task.dueDate == null ||
        task.remindBeforeMinutes <= 0) {
      return;
    }

    final now = DateTime.now();
    final dueDateTime = DateTime.fromMillisecondsSinceEpoch(task.dueDate!);
    var firstRemindTime = dueDateTime.subtract(
      Duration(minutes: task.remindBeforeMinutes),
    );

    // Nếu thời điểm nhắc trước đã lỡ qua nhưng hạn chót vẫn ở tương lai, nhắc đúng hạn chót
    if (firstRemindTime.isBefore(now)) {
      if (dueDateTime.isAfter(now)) {
        firstRemindTime = dueDateTime;
      } else {
        return;
      }
    }

    final totalCount = task.repeatCount.clamp(1, maxRepeatOccurrences);
    final intervalSeconds =
        task.repeatIntervalSeconds > 0 ? task.repeatIntervalSeconds : 60;

    for (var i = 0; i < totalCount; i++) {
      final scheduledTime = i == 0
          ? firstRemindTime
          : firstRemindTime.add(Duration(seconds: intervalSeconds * i));

      if (scheduledTime.isBefore(DateTime.now())) continue;

      final title = i == 0
          ? 'Sắp đến hạn: ${task.title}'
          : 'Nhắc lại (${i + 1}/$totalCount): ${task.title}';
      final body = i == 0
          ? 'Công việc "${task.title}" (${task.category}) sắp đến hạn chót.'
          : 'Đừng quên hoàn thành "${task.title}" (${task.category}).';

      await _scheduleSingle(
        id: _notificationIdFor(task.id, i),
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        payload: task.id,
      );
    }
  }

  Future<void> _scheduleSingle({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledTime, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      // Dự phòng nếu thiết bị chưa cấp quyền Exact Alarm
      debugPrint('Exact alarm không khả dụng, chuyển sang inexact: $e');
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDate,
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (fallbackError) {
        debugPrint('Lỗi đặt lịch nhắc việc: $fallbackError');
      }
    }
  }

  /// Hủy toàn bộ chuỗi thông báo (kể cả các lần nhắc lại) khi hoàn thành hoặc xóa công việc.
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_initialized) return;
    try {
      for (var i = 0; i < maxRepeatOccurrences; i++) {
        await _plugin.cancel(id: _notificationIdFor(taskId, i));
      }
    } catch (e) {
      debugPrint('Lỗi hủy thông báo: $e');
    }
  }

  /// Bắn ngay 1 thông báo mẫu để kiểm thử trên máy thật / Emulator.
  Future<void> showInstantTestNotification() async {
    if (!_isEnabled) return;
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;
    await _plugin.show(
      id: 999001,
      title: 'Smart Todo — Kiểm thử thông báo',
      body: 'Hệ thống nhắc hạn chót cục bộ đang hoạt động bình thường!',
      notificationDetails: _notificationDetails,
    );
  }
}
