import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/deadline_stream.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/workspace_provider.dart';

/// Banner cảnh báo hạn chót thời gian thực theo từng Không gian (Cá nhân hoặc Nhóm).
/// - Ở không gian nào chỉ hiển thị công việc quá hạn / sắp đến hạn của không gian đó.
/// - Có nút X để tạm đóng thông báo; khi chuyển không gian rồi vào lại sẽ hiển thị lại.
class DeadlineAlertBanner extends StatefulWidget {
  const DeadlineAlertBanner({super.key});

  @override
  State<DeadlineAlertBanner> createState() => _DeadlineAlertBannerState();
}

class _DeadlineAlertBannerState extends State<DeadlineAlertBanner> {
  Timer? _tickTimer;
  String? _lastWorkspaceId;
  String? _dismissedWorkspaceId;

  @override
  void initState() {
    super.initState();
    // Cập nhật bộ đếm ngược mỗi 15 giây
    _tickTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeWorkspace = context.select<ScheduleProvider, WorkspaceOption>(
      (p) => p.activeWorkspace,
    );

    // Khi người dùng chuyển sang không gian khác (hoặc quay lại không gian cũ) -> hiển thị lại banner
    if (_lastWorkspaceId != activeWorkspace.id) {
      _lastWorkspaceId = activeWorkspace.id;
      _dismissedWorkspaceId = null;
    }

    if (_dismissedWorkspaceId == activeWorkspace.id) {
      return const SizedBox.shrink();
    }

    final DeadlineSummary summary;
    if (activeWorkspace.isPersonal) {
      final personalTasks = context.watch<TaskProvider>().allTasks;
      summary = evaluateDeadlines(personalTasks);
    } else {
      final overview = context.watch<WorkspaceProvider>().activeOverview;
      if (overview == null || overview.workspace.id != activeWorkspace.id) {
        return const SizedBox.shrink();
      }
      summary = evaluateWorkspaceDeadlines(overview.tasks);
    }

    if (!summary.hasAlert) return const SizedBox.shrink();

    final isOverdue = summary.overdueCount > 0;
    final accentColor = isOverdue
        ? const Color(0xFFDC2626) // Đỏ quá hạn
        : const Color(0xFFD97706); // Cam sắp đến hạn (<24h)
    final urgentTask = summary.mostUrgentTask;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(
              isOverdue ? LucideIcons.triangleAlert : LucideIcons.clockAlert,
              color: accentColor,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOverdue
                        ? 'Có ${summary.overdueCount} công việc đã quá hạn!'
                        : 'Có ${summary.dueSoonCount} công việc sắp đến hạn (< 24h)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  if (urgentTask != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${urgentTask.title} • ${summary.urgentCountdownText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng thông báo',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed: () {
                setState(() {
                  _dismissedWorkspaceId = activeWorkspace.id;
                });
              },
              icon: Icon(
                LucideIcons.x,
                size: 16,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
