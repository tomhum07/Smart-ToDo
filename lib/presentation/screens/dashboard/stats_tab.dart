import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/deadline_stream.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../../data/models/holiday_model.dart';
import '../../../data/remote/firebase_sync_service.dart';
import '../../../data/remote/holiday_api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/note_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/task_provider.dart';

/// Tab Thống kê thời gian thực (StreamBuilder + async*/yield + LayoutBuilder + FutureBuilder REST API).
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  late Stream<DeadlineSummary> _deadlineStream;
  late Future<List<HolidayModel>> _holidaysFuture;
  final HolidayApiService _holidayApi = HolidayApiService();
  bool _isManualSyncing = false;

  @override
  void initState() {
    super.initState();
    _deadlineStream =
        watchDeadlineStream(() => context.read<TaskProvider>().allTasks);
    _holidaysFuture = _holidayApi.fetchVietnamHolidays(DateTime.now().year);
  }

  Future<void> _syncNow() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isFirebaseReady || auth.effectiveUserId == 'local_guest_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần đăng nhập tài khoản Firebase để đồng bộ Cloud.'),
        ),
      );
      return;
    }

    setState(() => _isManualSyncing = true);
    try {
      final uid = auth.effectiveUserId;
      await FirebaseSyncService.instance.syncAll(uid);
      if (!mounted) return;
      await Future.wait([
        context.read<TaskProvider>().loadTasks(uid, force: true),
        context.read<NoteProvider>().loadNotes(uid, force: true),
        context.read<ScheduleProvider>().loadSchedules(uid, force: true),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đồng bộ 2 chiều thành công với Firebase!'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final noteProvider = context.watch<NoteProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final shadTheme = ShadTheme.of(context);
    final lastSynced = FirebaseSyncService.instance.lastSyncedAt;

    final hPad = ResponsiveLayout.horizontalPadding(context);

    return ResponsiveCenterContainer(
      maxWidth: 820,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
        children: [
        StreamBuilder<DeadlineSummary>(
          stream: _deadlineStream,
          initialData: evaluateDeadlines(taskProvider.allTasks),
          builder: (context, snapshot) {
            final summary = evaluateDeadlines(taskProvider.allTasks);
            final activeTasks = summary.totalCount - summary.completedCount;

            return ShadCard(
              title: const Text('Tiến độ Công việc'),
              description: Text(
                'Đã hoàn thành ${summary.completedCount} / ${summary.totalCount} công việc (${summary.completionPercent}%).',
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
                            width:
                                constraints.maxWidth * summary.completionRate,
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
                          value: '${summary.completedCount}',
                          valueColor: const Color(0xFF16A34A),
                        ),
                        _StatMetric(
                          label: 'Sắp đến hạn',
                          value: '${summary.dueSoonCount}',
                          valueColor: summary.dueSoonCount > 0
                              ? const Color(0xFFD97706)
                              : null,
                        ),
                        _StatMetric(
                          label: 'Quá hạn',
                          value: '${summary.overdueCount}',
                          valueColor: summary.overdueCount > 0
                              ? const Color(0xFFDC2626)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ShadCard(
          title: const Text('Tổng quan Dữ liệu'),
          description: const Text(
            'Số lượng bản ghi hiện có trong SQLite cục bộ & đồng bộ Firebase.',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatMetric(
                  label: 'Công việc',
                  value: '${taskProvider.totalCount}',
                ),
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
          title: const Text('Đồng bộ & Trạng thái Đám mây'),
          description: Text(
            lastSynced == null
                ? 'Chưa đồng bộ trong phiên này.'
                : 'Đồng bộ gần nhất: ${DateFormatter.formatDateTime(lastSynced)}',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  pendingText: 'Chưa kết nối',
                ),
                const SizedBox(height: 8),
                _StatusRow(
                  label: '.NET Web API (Không gian chung)',
                  isReady: ApiConstants.isDotNetConfigured,
                  pendingText: 'Chưa kết nối',
                ),
                const SizedBox(height: 14),
                ShadButton.outline(
                  onPressed: _isManualSyncing ? null : _syncNow,
                  child: _isManualSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.refreshCw, size: 15),
                            SizedBox(width: 8),
                            Text('Đồng bộ Cloud ngay'),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShadCard(
          title: const Text('Ngày lễ Việt Nam sắp tới'),
          description: const Text(
            'Tải trực tiếp từ Nager.Date Public REST API (FutureBuilder).',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FutureBuilder<List<HolidayModel>>(
              future: _holidaysFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Không tải được danh sách ngày lễ (offline).',
                          style: shadTheme.textTheme.muted,
                        ),
                      ),
                      ShadButton.ghost(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        onPressed: () => setState(() {
                          _holidaysFuture = _holidayApi
                              .fetchVietnamHolidays(DateTime.now().year);
                        }),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  );
                }

                final holidays = snapshot.data ?? const [];
                if (holidays.isEmpty) {
                  return Text(
                    'Không có dữ liệu ngày lễ cho năm ${DateTime.now().year}.',
                    style: shadTheme.textTheme.muted,
                  );
                }

                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final upcoming = holidays
                    .where((h) => !h.date.isBefore(today))
                    .take(3)
                    .toList();
                final displayList =
                    upcoming.isNotEmpty ? upcoming : holidays.take(3).toList();

                return Column(
                  children: displayList.map((h) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          ShadBadge.outline(
                            child: Text(DateFormatter.formatDate(h.date)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              h.localName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: shadTheme.textTheme.small,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
      ),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: theme.textTheme.muted),
        ),
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
