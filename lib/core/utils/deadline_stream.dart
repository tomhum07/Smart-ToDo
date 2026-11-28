import 'dart:async';

import '../../data/models/task_model.dart';
import '../../data/models/workspace_models.dart';

/// Ảnh chụp trạng thái hạn chót và tiến độ công việc tại thời điểm hiện tại.
class DeadlineSummary {
  final int totalCount;
  final int completedCount;
  final int overdueCount;
  final int dueSoonCount; // trong vòng 24 giờ tới
  final TaskModel? mostUrgentTask;
  final DateTime evaluatedAt;

  const DeadlineSummary({
    required this.totalCount,
    required this.completedCount,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.mostUrgentTask,
    required this.evaluatedAt,
  });

  double get completionRate =>
      totalCount == 0 ? 0.0 : completedCount / totalCount;

  int get completionPercent => (completionRate * 100).round();

  bool get hasAlert => overdueCount > 0 || dueSoonCount > 0;

  /// Định dạng đếm ngược thời gian còn lại hoặc quá hạn của công việc gấp nhất.
  String get urgentCountdownText {
    final task = mostUrgentTask;
    if (task == null || task.dueDate == null) return '';
    final diff = DateTime.fromMillisecondsSinceEpoch(task.dueDate!)
        .difference(evaluatedAt);
    if (diff.isNegative) {
      final abs = diff.abs();
      if (abs.inDays >= 1) return 'Quá hạn ${abs.inDays} ngày';
      if (abs.inHours >= 1) return 'Quá hạn ${abs.inHours} giờ';
      return 'Quá hạn ${abs.inMinutes.clamp(1, 59)} phút';
    }
    if (diff.inHours >= 1) {
      final mins = diff.inMinutes % 60;
      return 'Còn ${diff.inHours}g ${mins}p';
    }
    return 'Còn ${diff.inMinutes.clamp(1, 59)} phút';
  }
}

/// Tính toán snapshot hạn chót từ danh sách công việc hiện tại.
DeadlineSummary evaluateDeadlines(List<TaskModel> tasks) {
  final now = DateTime.now();
  final nowMs = now.millisecondsSinceEpoch;
  final soonLimitMs = now.add(const Duration(hours: 24)).millisecondsSinceEpoch;

  var completed = 0;
  var overdue = 0;
  var dueSoon = 0;
  TaskModel? mostUrgent;

  for (final task in tasks) {
    if (task.isCompleted) {
      completed++;
      continue;
    }
    final due = task.dueDate;
    if (due == null) continue;

    if (due < nowMs) {
      overdue++;
      if (mostUrgent == null || due < (mostUrgent.dueDate ?? due + 1)) {
        mostUrgent = task;
      }
    } else if (due <= soonLimitMs) {
      dueSoon++;
      if (mostUrgent == null ||
          (mostUrgent.dueDate != null &&
              mostUrgent.dueDate! >= nowMs &&
              due < mostUrgent.dueDate!)) {
        mostUrgent = task;
      }
    }
  }

  return DeadlineSummary(
    totalCount: tasks.length,
    completedCount: completed,
    overdueCount: overdue,
    dueSoonCount: dueSoon,
    mostUrgentTask: mostUrgent,
    evaluatedAt: now,
  );
}

/// Tính toán snapshot hạn chót cho danh sách công việc trong Không gian Nhóm (Shared Workspace).
DeadlineSummary evaluateWorkspaceDeadlines(List<WorkspaceTask> tasks) {
  final adapted = tasks
      .map(
        (t) => TaskModel(
          id: t.id,
          userId: t.assigneeUid ?? '',
          scheduleId: t.scheduleId,
          title: t.title,
          description: t.description,
          category: 'Nhóm',
          priority: t.priority,
          isCompleted: t.isCompleted,
          dueDate: t.dueDate,
          createdAt: t.updatedAt,
          updatedAt: t.updatedAt,
        ),
      )
      .toList();
  return evaluateDeadlines(adapted);
}

/// Stream generator (async*/yield) phát cập nhật tiến độ & cảnh báo hạn chót thời gian thực.
/// Hủy Timer đồng bộ ngay khi StreamBuilder dispose để không rò rỉ bộ nhớ.
Stream<DeadlineSummary> watchDeadlineStream(
  List<TaskModel> Function() getTasks, {
  Duration interval = const Duration(seconds: 15),
}) async* {
  yield evaluateDeadlines(getTasks());
  final controller = StreamController<DeadlineSummary>();
  final timer = Timer.periodic(interval, (_) {
    if (!controller.isClosed) {
      controller.add(evaluateDeadlines(getTasks()));
    }
  });
  controller.onCancel = () {
    timer.cancel();
    controller.close();
  };
  yield* controller.stream;
}
