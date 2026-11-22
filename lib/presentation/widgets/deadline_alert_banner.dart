import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/utils/deadline_stream.dart';
import '../../providers/task_provider.dart';

/// Banner cảnh báo hạn chót thời gian thực bằng StreamBuilder + async*/yield.
/// Đỏ: có công việc quá hạn | Cam: có công việc sắp đến hạn trong 24 giờ.
class DeadlineAlertBanner extends StatefulWidget {
  const DeadlineAlertBanner({super.key});

  @override
  State<DeadlineAlertBanner> createState() => _DeadlineAlertBannerState();
}

class _DeadlineAlertBannerState extends State<DeadlineAlertBanner> {
  late Stream<DeadlineSummary> _stream;

  @override
  void initState() {
    super.initState();
    _stream = watchDeadlineStream(() => context.read<TaskProvider>().allTasks);
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe TaskProvider để cập nhật tức thì khi user vừa thêm/sửa/tick việc
    final tasks = context.watch<TaskProvider>().allTasks;
    final initialSummary = evaluateDeadlines(tasks);

    return StreamBuilder<DeadlineSummary>(
      stream: _stream,
      initialData: initialSummary,
      builder: (context, snapshot) {
        final summary = evaluateDeadlines(tasks);
        if (!summary.hasAlert) return const SizedBox.shrink();

        final isOverdue = summary.overdueCount > 0;
        final accentColor = isOverdue
            ? const Color(0xFFDC2626) // Đỏ quá hạn
            : const Color(0xFFD97706); // Cam sắp đến hạn (<24h)
        final urgentTask = summary.mostUrgentTask;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: [
                Icon(
                  isOverdue
                      ? LucideIcons.triangleAlert
                      : LucideIcons.clockAlert,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
