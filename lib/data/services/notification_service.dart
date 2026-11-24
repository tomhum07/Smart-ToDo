import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';
import '../models/workspace_models.dart';

/// Dịch vụ thông báo đẩy cục bộ chính xác theo giây trên Android, hỗ trợ nhắc lại nhiều lần.
/// Kết hợp Android AlarmManager (khi app ở nền/tắt) + Timer chính xác (khi app đang mở)
/// để chống bị Doze mode / OEM (Xiaomi/Samsung/Oppo/Vivo) chặn hoặc trễ popup.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int maxRepeatOccurrences = 10;
  static const String _channelId = 'smart_todo_reminders_v3';
  static const String _channelName = 'Nhắc hạn chót công việc';
  static const String _channelDescription =
      'Thông báo nhắc nhở chính xác trước hạn chót công việc cá nhân & nhóm';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Map<int, Timer> _foregroundTimers = {};

  bool _initialized = false;
  bool _isEnabled = true;
  int _instantCounter = 0;

  bool get isEnabled => _isEnabled;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDescription,
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    onlyAlertOnce: false,
    channelShowBadge: true,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.alarm,
    ticker: 'Nhắc hạn chót Smart Todo',
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

      // Tạo kênh thông báo mức Importance.max tường minh để đảm bảo popup heads-up luôn bật.
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await androidPlugin?.requestNotificationsPermission();
      final canExact = await androidPlugin?.canScheduleExactNotifications();
      if (canExact == false) {
        await androidPlugin?.requestExactAlarmsPermission();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Không thể khởi tạo NotificationService: $e');
    }
  }

  /// Bật hoặc tắt toàn bộ thông báo cục bộ theo cài đặt trong Hồ sơ -> Hệ thống.
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!enabled) {
      for (final timer in _foregroundTimers.values) {
        timer.cancel();
      }
      _foregroundTimers.clear();
      if (_initialized) {
        try {
          await _plugin.cancelAll();
        } catch (e) {
          debugPrint('Lỗi hủy toàn bộ thông báo: $e');
        }
      }
    }
  }

  /// Băm FNV-1a 32-bit ổn định giữa các lần khởi động lại app.
  int _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Tạo notification ID ổn định cho từng lần nhắc (0 .. maxRepeatOccurrences - 1).
  int _notificationIdFor(String key, int occurrenceIndex) {
    final base = (_stableHash(key) % 200000000) * maxRepeatOccurrences;
    return base + occurrenceIndex;
  }

  /// Đặt lịch thông báo nhắc trước hạn chót + chuỗi nhắc lại cho Công việc Cá nhân.
  Future<void> scheduleTaskReminder(TaskModel task) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

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
    if (!firstRemindTime.isAfter(now)) {
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

      if (!scheduledTime.isAfter(DateTime.now())) continue;

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

  /// Đặt lịch thông báo hạn chót cho Công việc Nhóm (Shared Workspace).
  Future<void> scheduleWorkspaceTaskReminder(
    WorkspaceTask task, {
    required String workspaceName,
    int remindBeforeMinutes = 10,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    final key = 'ws_${task.id}';
    await cancelTaskReminder(key);

    if (!_isEnabled || task.isCompleted || task.dueDate == null) {
      return;
    }

    final now = DateTime.now();
    final dueDateTime = DateTime.fromMillisecondsSinceEpoch(task.dueDate!);
    if (!dueDateTime.isAfter(now)) return;

    final reminders = <({DateTime time, String title, String body})>[];

    if (remindBeforeMinutes > 0) {
      final beforeTime = dueDateTime.subtract(
        Duration(minutes: remindBeforeMinutes),
      );
      if (beforeTime.isAfter(now)) {
        reminders.add((
          time: beforeTime,
          title: '[$workspaceName] Sắp đến hạn: ${task.title}',
          body: task.assigneeName != null && task.assigneeName!.isNotEmpty
              ? 'Phụ trách: ${task.assigneeName} • Còn $remindBeforeMinutes phút đến hạn.'
              : 'Việc nhóm "${task.title}" còn $remindBeforeMinutes phút đến hạn.',
        ));
      }
    }

    // Luôn có 1 lời nhắc đúng thời điểm hạn chót
    reminders.add((
      time: dueDateTime,
      title: '[$workspaceName] Đến hạn: ${task.title}',
      body: task.assigneeName != null && task.assigneeName!.isNotEmpty
          ? 'Đã đến hạn chót công việc giao cho ${task.assigneeName}.'
          : 'Đã đến hạn chót công việc nhóm "${task.title}".',
    ));

    for (var i = 0; i < reminders.length && i < maxRepeatOccurrences; i++) {
      final item = reminders[i];
      await _scheduleSingle(
        id: _notificationIdFor(key, i),
        title: item.title,
        body: item.body,
        scheduledTime: item.time,
        payload: key,
      );
    }
  }

  /// Hủy thông báo của 1 công việc nhóm.
  Future<void> cancelWorkspaceTaskReminder(String taskId) =>
      cancelTaskReminder('ws_$taskId');

  /// Thông báo ngay khi có thành viên vừa giao việc nhóm mới cho người dùng hiện tại.
  Future<void> showWorkspaceTaskAssignedNotification(
    WorkspaceTask task, {
    required String workspaceName,
  }) async {
    if (!_isEnabled) return;
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    _instantCounter = (_instantCounter + 1) % 100000;
    final id = 880000 + _instantCounter;
    await _plugin.show(
      id: id,
      title: '[$workspaceName] Việc nhóm mới',
      body: 'Bạn được giao: "${task.title}"',
      notificationDetails: _notificationDetails,
      payload: 'ws_${task.id}',
    );
  }

  Future<void> _scheduleSingle({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    final delay = scheduledTime.difference(DateTime.now());
    if (delay <= Duration.zero) return;

    // 1. Đặt lịch ở mức OS (chạy khi app ở nền hoặc đã tắt)
    final tzDate = tz.TZDateTime.from(scheduledTime, tz.local);
    final modes = <AndroidScheduleMode>[
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];

    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDate,
          notificationDetails: _notificationDetails,
          androidScheduleMode: mode,
          payload: payload,
        );
        break;
      } catch (e) {
        debugPrint('Không đặt được lịch với chế độ $mode: $e');
      }
    }

    // 2. Đặt thêm Timer chính xác trong RAM cho các lịch trong vòng 24 giờ tới:
    // Khi app đang mở, Timer sẽ hủy lịch OS cùng ID rồi bắn _plugin.show() ngay lập tức
    // để đảm bảo 100% đúng giây & không bị OEM hoãn/chặn.
    _foregroundTimers[id]?.cancel();
    if (delay <= const Duration(hours: 24)) {
      _foregroundTimers[id] = Timer(delay, () async {
        _foregroundTimers.remove(id);
        if (!_isEnabled || !_initialized) return;
        try {
          await _plugin.cancel(id: id);
          await _plugin.show(
            id: id,
            title: title,
            body: body,
            notificationDetails: _notificationDetails,
            payload: payload,
          );
        } catch (e) {
          debugPrint('Lỗi bắn thông báo đúng giờ: $e');
        }
      });
    }
  }

  /// Hủy toàn bộ chuỗi thông báo (cả OS lẫn foreground Timer) khi hoàn thành hoặc xóa công việc.
  Future<void> cancelTaskReminder(String taskId) async {
    for (var i = 0; i < maxRepeatOccurrences; i++) {
      final id = _notificationIdFor(taskId, i);
      _foregroundTimers.remove(id)?.cancel();
      if (_initialized) {
        try {
          await _plugin.cancel(id: id);
        } catch (e) {
          debugPrint('Lỗi hủy thông báo: $e');
        }
      }
    }
  }

  /// Bắn ngay 1 thông báo mẫu với ID mới mỗi lần bấm để luôn hiện popup heads-up trên mọi máy Android.
  Future<void> showInstantTestNotification() async {
    if (!_isEnabled) return;
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    _instantCounter = (_instantCounter + 1) % 100000;
    final uniqueId = 900000 + _instantCounter;
    await _plugin.show(
      id: uniqueId,
      title: 'Smart Todo — Kiểm thử thông báo',
      body: 'Hệ thống nhắc hạn chót cục bộ đang hoạt động bình thường!',
      notificationDetails: _notificationDetails,
    );
  }
}
