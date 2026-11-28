import 'dart:async';

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
import '../../../providers/workspace_provider.dart';

/// Tab Thống kê thời gian thực (StreamBuilder + async*/yield + LayoutBuilder + FutureBuilder REST API).
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  Timer? _tickTimer;
  late Future<List<HolidayModel>> _holidaysFuture;
  final HolidayApiService _holidayApi = HolidayApiService();
  bool _isManualSyncing = false;
  String _selectedDeadlineSpaceId = 'all'; // 'all' | 'personal' | workspaceId

  @override
  void initState() {
    super.initState();
    // Cập nhật tiến độ & đếm ngược quá hạn mỗi 15 giây (tránh lỗi Stream single-subscription khi cuộn ListView)
    _tickTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    _holidaysFuture = _holidayApi
        .fetchVietnamHolidays(DateTime.now().year)
        .catchError((_) => <HolidayModel>[]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WorkspaceProvider>().prefetchAllOverviews();
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
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
    final workspaceProvider = context.watch<WorkspaceProvider>();
    final shadTheme = ShadTheme.of(context);
    final lastSynced = FirebaseSyncService.instance.lastSyncedAt;

    final hPad = ResponsiveLayout.horizontalPadding(context);
    final summary = evaluateDeadlines(taskProvider.allTasks);
    final activeTasks = summary.totalCount - summary.completedCount;

    return ResponsiveCenterContainer(
      maxWidth: 820,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
        children: [
        ShadCard(
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
                        width: constraints.maxWidth * summary.completionRate,
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
        ),
        const SizedBox(height: 16),
        _buildDeadlineBreakdownCard(
          context,
          shadTheme: shadTheme,
          taskProvider: taskProvider,
          workspaceProvider: workspaceProvider,
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

  Widget _buildDeadlineBreakdownCard(
    BuildContext context, {
    required ShadThemeData shadTheme,
    required TaskProvider taskProvider,
    required WorkspaceProvider workspaceProvider,
  }) {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final soonLimitMs =
        now.add(const Duration(hours: 24)).millisecondsSinceEpoch;

    // Xây dựng danh sách nhóm không gian (Cá nhân + từng Workspace chung)
    final spaces = <_SpaceDeadlineGroup>[];

    // 1. Không gian Cá nhân
    final personalOverdue = <_DeadlineItem>[];
    final personalSoon = <_DeadlineItem>[];
    for (final t in taskProvider.allTasks) {
      if (t.isCompleted || t.dueDate == null) continue;
      final item = _DeadlineItem(
        title: t.title,
        dueDate: t.dueDate!,
        subtitle: t.category,
        isOverdue: t.dueDate! < nowMs,
      );
      if (t.dueDate! < nowMs) {
        personalOverdue.add(item);
      } else if (t.dueDate! <= soonLimitMs) {
        personalSoon.add(item);
      }
    }
    personalOverdue.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    personalSoon.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    spaces.add(
      _SpaceDeadlineGroup(
        id: 'personal',
        name: 'Không gian Cá nhân',
        isPersonal: true,
        overdue: personalOverdue,
        dueSoon: personalSoon,
      ),
    );

    // 2. Các Không gian Chia sẻ Nhóm
    for (final ws in workspaceProvider.workspaces) {
      final overview = workspaceProvider.overviewCache[ws.id] ??
          (workspaceProvider.activeOverview?.workspace.id == ws.id
              ? workspaceProvider.activeOverview
              : null);
      final overdue = <_DeadlineItem>[];
      final soon = <_DeadlineItem>[];
      if (overview != null) {
        for (final t in overview.tasks) {
          if (t.isCompleted || t.dueDate == null) continue;
          final item = _DeadlineItem(
            title: t.title,
            dueDate: t.dueDate!,
            subtitle: t.assigneeName != null && t.assigneeName!.isNotEmpty
                ? 'Phụ trách: ${t.assigneeName}'
                : 'Cả nhóm',
            isOverdue: t.dueDate! < nowMs,
          );
          if (t.dueDate! < nowMs) {
            overdue.add(item);
          } else if (t.dueDate! <= soonLimitMs) {
            soon.add(item);
          }
        }
        overdue.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        soon.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      }
      spaces.add(
        _SpaceDeadlineGroup(
          id: ws.id,
          name: ws.name,
          isPersonal: false,
          overdue: overdue,
          dueSoon: soon,
          isLoading: overview == null,
        ),
      );
    }

    // Nếu không gian đang lọc không còn tồn tại -> quay về 'all'
    final activeFilter = _selectedDeadlineSpaceId == 'all' ||
            spaces.any((s) => s.id == _selectedDeadlineSpaceId)
        ? _selectedDeadlineSpaceId
        : 'all';

    final visibleSpaces = activeFilter == 'all'
        ? spaces
        : spaces.where((s) => s.id == activeFilter).toList();

    return ShadCard(
      title: const Text('Chi tiết Quá hạn & Sắp đến hạn'),
      description: const Text(
        'Liệt kê chi tiết công việc đã quá hạn và sắp đến hạn (< 24h) theo từng không gian.',
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: activeFilter == 'all',
                  onSelected: (_) =>
                      setState(() => _selectedDeadlineSpaceId = 'all'),
                ),
                ...spaces.map((s) {
                  final alertCount = s.overdue.length + s.dueSoon.length;
                  return ChoiceChip(
                    label: Text(
                      alertCount > 0 ? '${s.name} ($alertCount)' : s.name,
                    ),
                    selected: activeFilter == s.id,
                    onSelected: (_) =>
                        setState(() => _selectedDeadlineSpaceId = s.id),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            ...visibleSpaces.map((space) {
              final hasAny =
                  space.overdue.isNotEmpty || space.dueSoon.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: shadTheme.colorScheme.secondary
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: shadTheme.colorScheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            space.isPersonal
                                ? LucideIcons.user
                                : LucideIcons.users,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              space.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: shadTheme.textTheme.small.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (space.overdue.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _MiniCountPill(
                                label: '${space.overdue.length} quá hạn',
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          if (space.dueSoon.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _MiniCountPill(
                                label: '${space.dueSoon.length} sắp hạn',
                                color: const Color(0xFFD97706),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (space.isLoading)
                        Text(
                          'Đang tải dữ liệu nhóm...',
                          style:
                              shadTheme.textTheme.muted.copyWith(fontSize: 12),
                        )
                      else if (!hasAny)
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.circleCheck,
                              size: 14,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Không có công việc quá hạn hay sắp đến hạn.',
                                style: shadTheme.textTheme.muted
                                    .copyWith(fontSize: 12),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        if (space.overdue.isNotEmpty) ...[
                          const Text(
                            'Đã quá hạn',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...space.overdue.map(
                            (item) => _DeadlineTaskRow(
                              item: item,
                              now: now,
                              shadTheme: shadTheme,
                            ),
                          ),
                        ],
                        if (space.dueSoon.isNotEmpty) ...[
                          if (space.overdue.isNotEmpty)
                            const SizedBox(height: 8),
                          const Text(
                            'Sắp đến hạn (< 24 giờ)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...space.dueSoon.map(
                            (item) => _DeadlineTaskRow(
                              item: item,
                              now: now,
                              shadTheme: shadTheme,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SpaceDeadlineGroup {
  final String id;
  final String name;
  final bool isPersonal;
  final List<_DeadlineItem> overdue;
  final List<_DeadlineItem> dueSoon;
  final bool isLoading;

  const _SpaceDeadlineGroup({
    required this.id,
    required this.name,
    required this.isPersonal,
    required this.overdue,
    required this.dueSoon,
    this.isLoading = false,
  });
}

class _DeadlineItem {
  final String title;
  final int dueDate;
  final String subtitle;
  final bool isOverdue;

  const _DeadlineItem({
    required this.title,
    required this.dueDate,
    required this.subtitle,
    required this.isOverdue,
  });
}

class _MiniCountPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniCountPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DeadlineTaskRow extends StatelessWidget {
  final _DeadlineItem item;
  final DateTime now;
  final ShadThemeData shadTheme;

  const _DeadlineTaskRow({
    required this.item,
    required this.now,
    required this.shadTheme,
  });

  String _relativeText() {
    final diff = DateTime.fromMillisecondsSinceEpoch(item.dueDate).difference(
      now,
    );
    if (diff.isNegative) {
      final abs = diff.abs();
      if (abs.inDays >= 1) return 'Trễ ${abs.inDays} ngày';
      if (abs.inHours >= 1) return 'Trễ ${abs.inHours}g ${abs.inMinutes % 60}p';
      return 'Trễ ${abs.inMinutes.clamp(1, 59)} phút';
    }
    if (diff.inHours >= 1) {
      return 'Còn ${diff.inHours}g ${diff.inMinutes % 60}p';
    }
    return 'Còn ${diff.inMinutes.clamp(1, 59)} phút';
  }

  @override
  Widget build(BuildContext context) {
    final color =
        item.isOverdue ? const Color(0xFFDC2626) : const Color(0xFFD97706);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 7, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${DateFormatter.formatEpochDateTime(item.dueDate)} • ${item.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: shadTheme.textTheme.muted.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _relativeText(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
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
