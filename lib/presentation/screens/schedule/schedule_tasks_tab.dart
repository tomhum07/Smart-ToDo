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
import '../../widgets/deadline_alert_banner.dart';
import '../../widgets/filter_bar_widget.dart';
import '../../widgets/share_schedule_dialog.dart';

/// Tab 1 hợp nhất: Chọn Workspace + Lịch tuần (< > tuần cũ/tương lai, ngày/tháng) + Mục lớn & Việc nhỏ.
class ScheduleTasksTab extends StatefulWidget {
  const ScheduleTasksTab({super.key});

  @override
  State<ScheduleTasksTab> createState() => _ScheduleTasksTabState();
}

class _ScheduleTasksTabState extends State<ScheduleTasksTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _showScrollToTop = false;
  final Set<String> _expandedScheduleIds = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 220;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showWorkspaceSwitcherSheet() {
    final scheduleProvider = context.read<ScheduleProvider>();
    final workspaces = scheduleProvider.workspaces;
    final activeId = scheduleProvider.activeWorkspace.id;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final shadTheme = ShadTheme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chọn Không gian làm việc (Workspace)',
                  style: shadTheme.textTheme.h4,
                ),
                const SizedBox(height: 4),
                Text(
                  'Chuyển đổi giữa lịch cá nhân và không gian chia sẻ nhóm (.NET Web API).',
                  style: shadTheme.textTheme.muted,
                ),
                const SizedBox(height: 12),
                ...workspaces.map((ws) {
                  final isSelected = ws.id == activeId;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selected: isSelected,
                    leading: Icon(
                      ws.isPersonal ? LucideIcons.user : LucideIcons.users,
                    ),
                    title: Text(ws.name),
                    subtitle: Text(
                      ws.isPersonal
                          ? 'Dữ liệu cá nhân (SQLite + Firebase)'
                          : 'Mã nhóm: ${ws.inviteCode ?? "---"}',
                    ),
                    trailing: isSelected
                        ? const Icon(LucideIcons.check, size: 18)
                        : null,
                    onTap: () {
                      scheduleProvider.selectWorkspace(ws.id);
                      Navigator.pop(ctx);
                    },
                  );
                }),
                const Divider(height: 20),
                ShadButton.outline(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showShadDialog<void>(
                      context: context,
                      builder: (_) => const ShareScheduleDialog(),
                    );
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.users, size: 16),
                      SizedBox(width: 8),
                      Text('Tạo / Tham gia Workspace bằng mã'),
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

  void _showAddOptionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.calendarPlus),
                  title: const Text('Thêm Mục lớn (Lịch trình / Môn học)'),
                  subtitle: const Text(
                    'VD: Lập trình di động • Thứ 2, 07:30–10:00, phòng B4-202',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.scheduleForm);
                  },
                ),
                const Divider(height: 8),
                ListTile(
                  leading: const Icon(LucideIcons.listPlus),
                  title: const Text('Thêm Công việc nhỏ / Việc lẻ'),
                  subtitle: const Text(
                    'Gắn vào 1 mục lớn có sẵn hoặc lưu vào "Việc khác / Tự do"',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.taskForm);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteTask(TaskModel task) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Xóa công việc?'),
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
    if (confirmed == true && mounted) {
      await context.read<TaskProvider>().deleteTask(task);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final shadTheme = ShadTheme.of(context);
    final activeWorkspace = scheduleProvider.activeWorkspace;
    final weekDates = scheduleProvider.currentWeekDates;
    final today = DateTime.now();

    final query = taskProvider.searchQuery.trim().toLowerCase();
    final daySchedules = scheduleProvider.schedulesForSelectedDay.where((s) {
      if (query.isEmpty) return true;
      final matchSchedule = s.title.toLowerCase().contains(query) ||
          s.location.toLowerCase().contains(query) ||
          s.note.toLowerCase().contains(query);
      final matchChild = taskProvider
          .tasksForSchedule(s.id, applyFilters: true)
          .isNotEmpty;
      return matchSchedule || matchChild;
    }).toList();

    final standaloneTasks = taskProvider.standaloneFilteredTasks;
    final selectedDate = scheduleProvider.selectedDate;

    return Scaffold(
      body: Column(
        children: [
          const DeadlineAlertBanner(),

          // 1. Thanh chọn Workspace (thay cho phần Ngày lễ cũ)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: InkWell(
              onTap: _showWorkspaceSwitcherSheet,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: shadTheme.colorScheme.secondary.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: shadTheme.colorScheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      activeWorkspace.isPersonal
                          ? LucideIcons.layers
                          : LucideIcons.users,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeWorkspace.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ShadBadge.outline(
                      child: Text(
                        activeWorkspace.isPersonal ? 'Cá nhân' : 'Nhóm',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(LucideIcons.chevronsUpDown, size: 15),
                  ],
                ),
              ),
            ),
          ),

          // 2. Thanh tìm kiếm & Bộ lọc siêu gọn 1 hàng
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: FilterBarWidget(
              searchController: _searchController,
              searchPlaceholder: 'Tìm môn học, công việc...',
              selectedCategory: taskProvider.selectedCategory,
              selectedPriority: taskProvider.selectedPriority,
              activeFilterCount: taskProvider.activeFilterCount,
              onSearchChanged: taskProvider.setSearchQuery,
              onCategoryChanged: taskProvider.setCategory,
              onPriorityChanged: taskProvider.setPriority,
              onResetFilters: () {
                _searchController.clear();
                taskProvider.resetFilters();
              },
              extraSheetBuilder: (setModalState) {
                final provider = context.read<TaskProvider>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Trạng thái công việc',
                      style: shadTheme.textTheme.small,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Tất cả (${provider.totalCount})'),
                          selected: provider.statusFilter == TaskStatusFilter.all,
                          onSelected: (_) {
                            provider.setStatusFilter(TaskStatusFilter.all);
                            setModalState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Chưa xong'),
                          selected:
                              provider.statusFilter == TaskStatusFilter.active,
                          onSelected: (_) {
                            provider.setStatusFilter(TaskStatusFilter.active);
                            setModalState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: Text('Đã xong (${provider.completedCount})'),
                          selected: provider.statusFilter ==
                              TaskStatusFilter.completed,
                          onSelected: (_) {
                            provider
                                .setStatusFilter(TaskStatusFilter.completed);
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Sắp xếp công việc', style: shadTheme.textTheme.small),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Ưu tiên (Cao → Thấp)'),
                          selected:
                              provider.sortOption == TaskSortOption.priority,
                          onSelected: (_) {
                            provider.setSortOption(TaskSortOption.priority);
                            setModalState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Hạn chót gần nhất'),
                          selected:
                              provider.sortOption == TaskSortOption.dueDate,
                          onSelected: (_) {
                            provider.setSortOption(TaskSortOption.dueDate);
                            setModalState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Mới tạo gần đây'),
                          selected:
                              provider.sortOption == TaskSortOption.createdAt,
                          onSelected: (_) {
                            provider.setSortOption(TaskSortOption.createdAt);
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. Thanh Lịch Tuần có nút < > chuyển tuần cũ / tuần tương lai + Thứ & Ngày/Tháng
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Column(
              children: [
                if (!scheduleProvider.isCurrentWeek)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: GestureDetector(
                      onTap: scheduleProvider.jumpToToday,
                      child: ShadBadge.secondary(
                        child: Text(
                          'Tuần ${weekDates.first.day}/${weekDates.first.month} – ${weekDates.last.day}/${weekDates.last.month} • Về Hôm nay',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Tuần trước',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 36,
                      ),
                      onPressed: scheduleProvider.previousWeek,
                      icon: const Icon(LucideIcons.chevronLeft, size: 18),
                    ),
                    Expanded(
                      child: Row(
                        children: List.generate(7, (index) {
                          final date = weekDates[index];
                          final day = index + 1;
                          final isSelected =
                              scheduleProvider.selectedDayOfWeek == day;
                          final isToday = _isSameDay(date, today);
                          final count = scheduleProvider.countForDate(date);
                          final shortLabel = day == 7 ? 'CN' : 'T${day + 1}';
                          final dayMonth = '${date.day}/${date.month}';

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: InkWell(
                                onTap: () => scheduleProvider.selectDay(day),
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? shadTheme.colorScheme.primary
                                        : shadTheme.colorScheme.secondary
                                            .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isToday && !isSelected
                                        ? Border.all(
                                            color: shadTheme.colorScheme.primary,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          shortLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? shadTheme.colorScheme
                                                    .primaryForeground
                                                : shadTheme
                                                    .colorScheme.foreground,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          dayMonth,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isToday
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? shadTheme.colorScheme
                                                    .primaryForeground
                                                    .withValues(alpha: 0.9)
                                                : shadTheme.colorScheme
                                                    .mutedForeground,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: count > 0
                                              ? (isSelected
                                                  ? shadTheme.colorScheme
                                                      .primaryForeground
                                                  : shadTheme
                                                      .colorScheme.primary)
                                              : Colors.transparent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tuần sau',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 36,
                      ),
                      onPressed: scheduleProvider.nextWeek,
                      icon: const Icon(LucideIcons.chevronRight, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 4. Danh sách Mục lớn (Lịch trình trong ngày) + Mục Việc khác / Tự do
          Expanded(
            child: (scheduleProvider.isLoading && taskProvider.isLoading)
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      Text(
                        '${DateFormatter.dayOfWeekLabel(scheduleProvider.selectedDayOfWeek)}, ${DateFormatter.formatDate(selectedDate)} (${daySchedules.length} mục lớn)',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (daySchedules.isEmpty)
                        ShadCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Chưa có mục lớn nào cho ${DateFormatter.dayOfWeekLabel(scheduleProvider.selectedDayOfWeek)}. Bấm "Thêm mới" để tạo lịch học / sự kiện!',
                              textAlign: TextAlign.center,
                              style: shadTheme.textTheme.muted,
                            ),
                          ),
                        )
                      else
                        ...daySchedules.map((schedule) {
                          final childTasks =
                              taskProvider.tasksForSchedule(schedule.id);
                          final isExpanded =
                              _expandedScheduleIds.contains(schedule.id);
                          return _ScheduleParentCard(
                            schedule: schedule,
                            childTasks: childTasks,
                            isExpanded: isExpanded,
                            onToggleExpand: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedScheduleIds.remove(schedule.id);
                                } else {
                                  _expandedScheduleIds.add(schedule.id);
                                }
                              });
                            },
                            onOpenDetail: () => Navigator.pushNamed(
                              context,
                              AppRoutes.scheduleDetail,
                              arguments: schedule.id,
                            ),
                            onAddSubtask: () => Navigator.pushNamed(
                              context,
                              AppRoutes.taskForm,
                              arguments: TaskFormArgs(
                                initialScheduleId: schedule.id,
                              ),
                            ),
                            onToggleTask: taskProvider.toggleTaskCompletion,
                          );
                        }),

                      const SizedBox(height: 18),

                      // Mục "Việc khác / Tự do"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Việc khác / Tự do (${standaloneTasks.length})',
                            style: shadTheme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          ShadButton.ghost(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.taskForm,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.plus, size: 14),
                                SizedBox(width: 4),
                                Text('Thêm việc lẻ'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (standaloneTasks.isEmpty)
                        Text(
                          'Không có công việc lẻ nào.',
                          style: shadTheme.textTheme.muted,
                        )
                      else
                        ...standaloneTasks.map((task) {
                          return _StandaloneTaskCard(
                            task: task,
                            onToggle: () =>
                                taskProvider.toggleTaskCompletion(task),
                            onEdit: () => Navigator.pushNamed(
                              context,
                              AppRoutes.taskForm,
                              arguments: TaskFormArgs(task: task),
                            ),
                            onDelete: () => _confirmDeleteTask(task),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showScrollToTop) ...[
            FloatingActionButton.small(
              heroTag: 'unified_scroll_top',
              onPressed: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              child: const Icon(LucideIcons.arrowUp, size: 18),
            ),
            const SizedBox(height: 8),
          ],
          FloatingActionButton.extended(
            heroTag: 'unified_add_btn',
            onPressed: _showAddOptionsSheet,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Thêm mới'),
          ),
        ],
      ),
    );
  }
}

/// Thẻ Mục lớn (Cách A): hiện tóm tắt tiến độ, nút mở rộng nhanh để tick việc nhỏ & chạm mở trang chi tiết.
class _ScheduleParentCard extends StatelessWidget {
  final ScheduleModel schedule;
  final List<TaskModel> childTasks;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onOpenDetail;
  final VoidCallback onAddSubtask;
  final ValueChanged<TaskModel> onToggleTask;

  const _ScheduleParentCard({
    required this.schedule,
    required this.childTasks,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpenDetail,
    required this.onAddSubtask,
    required this.onToggleTask,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final completed = childTasks.where((t) => t.isCompleted).length;
    final accentColor = schedule.colorHex.toUpperCase() == '#FFFFFF'
        ? shadTheme.colorScheme.primary
        : AppColors.fromHex(schedule.colorHex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShadCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: onOpenDetail,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ShadBadge.secondary(
                                  child: Text(
                                    '${schedule.startTime} - ${schedule.endTime}',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ShadBadge.outline(
                                  child: Text(
                                    childTasks.isEmpty
                                        ? '0 việc nhỏ'
                                        : '$completed/${childTasks.length} việc',
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Thêm việc nhỏ',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onAddSubtask,
                                  icon: const Icon(LucideIcons.plus, size: 17),
                                ),
                                IconButton(
                                  tooltip: isExpanded
                                      ? 'Thu gọn việc nhỏ'
                                      : 'Mở rộng việc nhỏ',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: onToggleExpand,
                                  icon: Icon(
                                    isExpanded
                                        ? LucideIcons.chevronUp
                                        : LucideIcons.chevronDown,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              schedule.title,
                              style: shadTheme.textTheme.p.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (schedule.location.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(LucideIcons.mapPin, size: 13),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      schedule.location,
                                      style: shadTheme.textTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
                        child: childTasks.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                child: Text(
                                  'Chưa có việc nhỏ nào. Bấm "+" để thêm.',
                                  style: shadTheme.textTheme.muted,
                                ),
                              )
                            : Column(
                                children: childTasks.map((task) {
                                  final isDone = task.isCompleted;
                                  return AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    opacity: isDone ? 0.48 : 1.0,
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          visualDensity: VisualDensity.compact,
                                          value: isDone,
                                          onChanged: (_) => onToggleTask(task),
                                        ),
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: shadTheme.textTheme.small
                                                .copyWith(
                                              decoration: isDone
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        if (task.dueDate != null)
                                          Text(
                                            DateFormatter.formatTime(
                                              DateTime
                                                  .fromMillisecondsSinceEpoch(
                                                task.dueDate!,
                                              ),
                                            ),
                                            style: shadTheme.textTheme.muted
                                                .copyWith(fontSize: 11),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandaloneTaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StandaloneTaskCard({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final isDone = task.isCompleted;
    final priorityColor = isDone
        ? shadTheme.colorScheme.mutedForeground
        : AppColors.priorityColor(task.priority);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDone ? 0.48 : 1.0,
        child: ShadCard(
          backgroundColor: isDone
              ? shadTheme.colorScheme.muted.withValues(alpha: 0.45)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: isDone,
                onChanged: (_) => onToggle(),
              ),
              Expanded(
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: shadTheme.textTheme.p.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppColors.priorityLabel(task.priority),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                              ),
                            ),
                          ),
                          ShadBadge.outline(child: Text(task.category)),
                          if (task.dueDate != null)
                            ShadBadge.secondary(
                              child: Text(
                                DateFormatter.formatEpochDateTime(
                                  task.dueDate!,
                                ),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Xóa công việc',
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2, size: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
