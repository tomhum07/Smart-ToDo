import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/api_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/note_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/task_provider.dart';

/// Tab Thống kê (đã tách riêng khỏi Hồ sơ): hiển thị tiến độ (LayoutBuilder), số liệu & trạng thái kết nối.
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final noteProvider = context.watch<NoteProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final shadTheme = ShadTheme.of(context);

    final totalTasks = taskProvider.totalCount;
    final completedTasks = taskProvider.completedCount;
    final activeTasks = totalTasks - completedTasks;
    final overdueTasks = taskProvider.overdueCount;
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;
    final percentText = '${(progress * 100).round()}%';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ShadCard(
          title: const Text('Tiến độ Công việc'),
          description: Text(
            'Đã hoàn thành $completedTasks / $totalTasks công việc ($percentText).',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 12,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: shadTheme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 12,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          color: shadTheme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatMetric(
                      label: 'Đang làm',
                      value: '$activeTasks',
                    ),
                    _StatMetric(
                      label: 'Đã xong',
                      value: '$completedTasks',
                      valueColor: const Color(0xFF16A34A),
                    ),
                    _StatMetric(
                      label: 'Quá hạn',
                      value: '$overdueTasks',
                      valueColor: overdueTasks > 0
                          ? const Color(0xFFDC2626)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShadCard(
          title: const Text('Tổng quan Dữ liệu Cục bộ'),
          description: const Text(
            'Số lượng bản ghi đang lưu trong SQLite (sqflite) của tài khoản hiện tại.',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatMetric(label: 'Công việc', value: '$totalTasks'),
                _StatMetric(
                  label: 'Ghi chú',
                  value: '${noteProvider.totalCount}',
                ),
                _StatMetric(
                  label: 'Lịch trình',
                  value: '${scheduleProvider.totalCount}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShadCard(
          title: const Text('Trạng thái Dịch vụ Đám mây'),
          description: const Text(
            'Tình trạng kết nối Firebase, Supabase Storage và .NET Web API.',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                _StatusRow(
                  label: 'Firebase Auth & Realtime DB',
                  isReady: auth.isFirebaseReady,
                  pendingText: 'Chờ setup',
                ),
                const SizedBox(height: 8),
                _StatusRow(
                  label: 'Supabase Storage (Ảnh)',
                  isReady: ApiConstants.isSupabaseConfigured,
                  pendingText: 'Làm sau',
                ),
                const SizedBox(height: 8),
                _StatusRow(
                  label: '.NET Web API (Chia sẻ lịch)',
                  isReady: ApiConstants.isDotNetConfigured,
                  pendingText: 'Phase 3',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.h3.copyWith(color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.muted),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isReady;
  final String pendingText;

  const _StatusRow({
    required this.label,
    required this.isReady,
    required this.pendingText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        isReady
            ? const ShadBadge(child: Text('Đã kết nối'))
            : ShadBadge.outline(child: Text(pendingText)),
      ],
    );
  }
}
