import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/task_model.dart';
import '../../../providers/task_provider.dart';
import '../../widgets/deadline_alert_banner.dart';
import '../../widgets/filter_bar_widget.dart';

/// Tab Công việc (Todo): Thanh lọc siêu gọn 1 hàng + mặc định ưu tiên Cao->Thấp + xám mờ việc đã xong.
class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showScrollToTop = false;

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

  Future<void> _confirmDelete(BuildContext context, TaskModel task) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Xóa công việc?'),
        description: Text(
          'Bạn có chắc muốn xóa "${task.title}" không? Thông báo nhắc việc đi kèm cũng sẽ bị hủy.',
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
      await context.read<TaskProvider>().deleteTask(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final tasks = taskProvider.filteredTasks;

    return Scaffold(
      body: Column(
        children: [
          const DeadlineAlertBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: FilterBarWidget(
              searchController: _searchController,
              searchPlaceholder: 'Tìm kiếm công việc...',
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
                final shadTheme = ShadTheme.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Trạng thái', style: shadTheme.textTheme.small),
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
                    Text('Sắp xếp theo', style: shadTheme.textTheme.small),
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
          const Divider(height: 1),
          Expanded(
            child: taskProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : tasks.isEmpty
                    ? _buildEmptyState(context, taskProvider)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          return _TaskCardItem(
                            task: tasks[index],
                            onToggle: () => taskProvider
                                .toggleTaskCompletion(tasks[index]),
                            onEdit: () => Navigator.pushNamed(
                              context,
                              AppRoutes.taskForm,
                              arguments: tasks[index],
                            ),
                            onDelete: () =>
                                _confirmDelete(context, tasks[index]),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showScrollToTop) ...[
            FloatingActionButton.small(
              heroTag: 'tasks_scroll_top',
              onPressed: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              ),
              child: const Icon(LucideIcons.arrowUp, size: 18),
            ),
            const SizedBox(height: 8),
          ],
          FloatingActionButton(
            heroTag: 'tasks_add_btn',
            tooltip: 'Thêm việc',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.taskForm),
            child: const Icon(LucideIcons.plus),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TaskProvider provider) {
    final hasFilter =
        provider.searchQuery.isNotEmpty || provider.activeFilterCount > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.listChecks, size: 48),
            const SizedBox(height: 12),
            Text(
              hasFilter
                  ? 'Không tìm thấy công việc phù hợp bộ lọc.'
                  : 'Chưa có công việc nào.\nBấm "Thêm việc" để bắt đầu!',
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: 12),
              ShadButton.outline(
                onPressed: () {
                  _searchController.clear();
                  provider.resetFilters();
                },
                child: const Text('Xóa bộ lọc'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskCardItem extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCardItem({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isDone = task.isCompleted;
    final isOverdue = !isDone && task.dueDate != null && task.dueDate! < nowMs;
    final isDueSoon = !isDone &&
        !isOverdue &&
        task.dueDate != null &&
        (task.dueDate! - nowMs) <= const Duration(hours: 24).inMilliseconds;

    // Khi đã tích hoàn thành -> xám mờ toàn bộ thẻ & badge để phân biệt rõ
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isDone,
                onChanged: (_) => onToggle(),
              ),
              Expanded(
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: shadTheme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDone
                                ? shadTheme.colorScheme.mutedForeground
                                : null,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: shadTheme.textTheme.muted,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppColors.priorityLabel(task.priority),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: priorityColor,
                                  ),
                                ),
                              ),
                            ),
                            ShadBadge.outline(
                              child: Text(task.category),
                            ),
                            if (task.dueDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isOverdue
                                      ? const Color(0xFFDC2626)
                                          .withValues(alpha: 0.14)
                                      : isDueSoon
                                          ? const Color(0xFFD97706)
                                              .withValues(alpha: 0.16)
                                          : shadTheme.colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.clock,
                                      size: 12,
                                      color: isOverdue
                                          ? const Color(0xFFDC2626)
                                          : isDueSoon
                                              ? const Color(0xFFD97706)
                                              : shadTheme
                                                  .colorScheme.foreground,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormatter.formatEpochDateTime(
                                        task.dueDate!,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isOverdue || isDueSoon
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isOverdue
                                            ? const Color(0xFFDC2626)
                                            : isDueSoon
                                                ? const Color(0xFFD97706)
                                                : shadTheme
                                                    .colorScheme.foreground,
                                      ),
                                    ),
                                  ],
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
                tooltip: 'Xóa công việc',
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
