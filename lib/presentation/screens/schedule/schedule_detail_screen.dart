import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/models/task_model.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/task_provider.dart';

/// Màn hình Chi tiết Mục lớn (VD: Môn Lập trình di động Thứ 2, 7h30–10h, B4-202)
/// kèm danh sách các Công việc nhỏ (Subtasks) và thanh tiến độ riêng.
class ScheduleDetailScreen extends StatelessWidget {
  final String scheduleId;

  const ScheduleDetailScreen({super.key, required this.scheduleId});

  Future<void> _confirmDeleteSchedule(
    BuildContext context,
    ScheduleModel schedule,
    int childCount,
  ) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Xóa mục lớn này?'),
        description: Text(
          childCount > 0
              ? 'Xóa "${schedule.title}" sẽ xóa luôn $childCount công việc nhỏ bên trong và hủy toàn bộ lời nhắc.'
              : 'Bạn có chắc muốn xóa "${schedule.title}" không?',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TaskProvider>().deleteTasksBySchedule(
            userId: schedule.userId,
            scheduleId: schedule.id,
          );
      if (!context.mounted) return;
      await context.read<ScheduleProvider>().deleteSchedule(schedule);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _confirmDeleteTask(BuildContext context, TaskModel task) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Xóa công việc nhỏ?'),
        description: Text('Bạn có chắc muốn xóa "${task.title}" không?'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TaskProvider>().deleteTask(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final shadTheme = ShadTheme.of(context);

    final matches =
        scheduleProvider.allSchedules.where((s) => s.id == scheduleId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết lịch trình')),
        body: const Center(child: Text('Mục này không còn tồn tại.')),
      );
    }

    final schedule = matches.first;
    final childTasks = taskProvider.tasksForSchedule(schedule.id);
    final completedCount = childTasks.where((t) => t.isCompleted).length;
    final progress =
        childTasks.isEmpty ? 0.0 : completedCount / childTasks.length;
    final accentColor = schedule.colorHex.toUpperCase() == '#FFFFFF'
        ? shadTheme.colorScheme.primary
        : AppColors.fromHex(schedule.colorHex);

    return Scaffold(
      appBar: AppBar(
        title: Text(schedule.title),
        actions: [
          IconButton(
            tooltip: 'Sửa mục lớn',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.scheduleForm,
              arguments: schedule,
            ),
            icon: const Icon(LucideIcons.pencil, size: 19),
          ),
          IconButton(
            tooltip: 'Xóa mục lớn',
            onPressed: () => _confirmDeleteSchedule(
              context,
              schedule,
              childTasks.length,
            ),
            icon: const Icon(LucideIcons.trash2, size: 19),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          // Thẻ thông tin Mục lớn
          ShadCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadBadge.secondary(
                      child: Text(
                        '${DateFormatter.dayOfWeekLabel(schedule.dayOfWeek)} • ${schedule.startTime} - ${schedule.endTime}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(schedule.title, style: shadTheme.textTheme.h4),
                if (schedule.location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          schedule.location,
                          style: shadTheme.textTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ],
                if (schedule.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(schedule.note, style: shadTheme.textTheme.p),
                ],
                const Divider(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tiến độ việc nhỏ',
                      style: shadTheme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$completedCount / ${childTasks.length} đã xong',
                      style: shadTheme.textTheme.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 8,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: shadTheme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 8,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          color: shadTheme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Công việc nhỏ trong mục này (${childTasks.length})',
            style: shadTheme.textTheme.small.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (childTasks.isEmpty)
            ShadCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const Icon(LucideIcons.listChecks, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'Chưa có công việc nhỏ nào.\nBấm "Thêm việc nhỏ" để đặt việc & lời nhắc cho mục này!',
                      textAlign: TextAlign.center,
                      style: shadTheme.textTheme.muted,
                    ),
                  ],
                ),
              ),
            )
          else
            ...childTasks.map((task) {
              final isDone = task.isCompleted;
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              final isOverdue =
                  !isDone && task.dueDate != null && task.dueDate! < nowMs;
              final priorityColor = isDone
                  ? shadTheme.colorScheme.mutedForeground
                  : AppColors.priorityColor(task.priority);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isDone ? 0.48 : 1.0,
                  child: ShadCard(
                    backgroundColor: isDone
                        ? shadTheme.colorScheme.muted.withValues(alpha: 0.45)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: isDone,
                          onChanged: (_) =>
                              taskProvider.toggleTaskCompletion(task),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.taskForm,
                              arguments: TaskFormArgs(
                                task: task,
                                initialScheduleId: schedule.id,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    style: shadTheme.textTheme.p.copyWith(
                                      fontWeight: FontWeight.w600,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (task.description.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      task.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: shadTheme.textTheme.muted,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: priorityColor
                                              .withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          AppColors.priorityLabel(
                                            task.priority,
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: priorityColor,
                                          ),
                                        ),
                                      ),
                                      if (task.dueDate != null)
                                        ShadBadge.outline(
                                          child: Text(
                                            DateFormatter.formatEpochDateTime(
                                              task.dueDate!,
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isOverdue
                                                  ? const Color(0xFFDC2626)
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      if (task.dueDate != null &&
                                          task.remindBeforeMinutes > 0)
                                        ShadBadge.secondary(
                                          child: Text(
                                            'Nhắc trước ${task.remindBeforeMinutes}p${task.repeatCount > 1 ? ' ×${task.repeatCount}' : ''}',
                                            style:
                                                const TextStyle(fontSize: 11),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Xóa công việc nhỏ',
                          onPressed: () => _confirmDeleteTask(context, task),
                          icon: const Icon(LucideIcons.trash2, size: 17),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Thêm việc nhỏ',
        onPressed: () => Navigator.pushNamed(
          context,
          AppRoutes.taskForm,
          arguments: TaskFormArgs(initialScheduleId: schedule.id),
        ),
        child: const Icon(LucideIcons.plus),
      ),
    );
  }
}
