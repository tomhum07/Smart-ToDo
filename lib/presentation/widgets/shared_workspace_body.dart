import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/workspace_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/workspace_provider.dart';

/// Giao diện nội dung khi người dùng đang xem một Không gian Chia sẻ Nhóm (Shared Workspace).
/// Hiển thị Mục lớn chung, Công việc nhỏ có phân công thành viên & Ghi chú chung theo ngày.
class SharedWorkspaceBody extends StatefulWidget {
  final DateTime selectedDate;

  const SharedWorkspaceBody({super.key, required this.selectedDate});

  static Future<void> showAddScheduleDialog(
    BuildContext context,
    WorkspaceOverview overview,
    DateTime selectedDate,
  ) async {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var startTime = const TimeOfDay(hour: 7, minute: 30);
    var endTime = const TimeOfDay(hour: 9, minute: 30);
    var isRecurring = false;
    var isSaving = false;

    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    await showShadDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return ShadDialog(
              title: const Text('Thêm Mục lớn chung'),
              description: Text(
                'Ngày ${DateFormatter.formatDate(selectedDate)} • ${overview.workspace.name}',
              ),
              actions: [
                ShadButton.outline(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ShadButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty) return;
                          setModalState(() => isSaving = true);
                          try {
                            final auth = context.read<AuthProvider>();
                            await context.read<WorkspaceProvider>().addSchedule(
                                  workspaceId: overview.workspace.id,
                                  title: titleCtrl.text.trim(),
                                  date: selectedDate,
                                  isRecurring: isRecurring,
                                  startTime: fmt(startTime),
                                  endTime: fmt(endTime),
                                  location: locationCtrl.text.trim(),
                                  note: noteCtrl.text.trim(),
                                  createdByName: auth.displayName,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } finally {
                            if (ctx.mounted) {
                              setModalState(() => isSaving = false);
                            }
                          }
                        },
                  child: const Text('Thêm'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShadInput(
                      controller: titleCtrl,
                      placeholder: const Text('VD: Thuyết trình Lập trình Mobile'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ShadButton.outline(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            onPressed: () async {
                              final p = await showTimePicker(
                                context: ctx,
                                initialTime: startTime,
                              );
                              if (p != null) setModalState(() => startTime = p);
                            },
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Từ: ${fmt(startTime)}'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShadButton.outline(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            onPressed: () async {
                              final p = await showTimePicker(
                                context: ctx,
                                initialTime: endTime,
                              );
                              if (p != null) setModalState(() => endTime = p);
                            },
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Đến: ${fmt(endTime)}'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ShadInput(
                      controller: locationCtrl,
                      placeholder: const Text('Phòng học / Địa điểm'),
                    ),
                    const SizedBox(height: 10),
                    ShadInput(
                      controller: noteCtrl,
                      placeholder: const Text('Ghi chú thêm'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lặp lại hằng tuần'),
                        ShadSwitch(
                          value: isRecurring,
                          onChanged: (v) => setModalState(() => isRecurring = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    titleCtrl.dispose();
    locationCtrl.dispose();
    noteCtrl.dispose();
  }

  static Future<void> showAddTaskDialog(
    BuildContext context,
    WorkspaceOverview overview, {
    String? scheduleId,
  }) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var priority = 1;
    WorkspaceMember? selectedAssignee =
        overview.members.isNotEmpty ? overview.members.first : null;
    var isSaving = false;

    await showShadDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final shadTheme = ShadTheme.of(ctx);
            return ShadDialog(
              title: const Text('Giao Công việc nhóm'),
              description: const Text(
                'Phân công việc nhỏ cho thành viên trong Workspace.',
              ),
              actions: [
                ShadButton.outline(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ShadButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty) return;
                          setModalState(() => isSaving = true);
                          try {
                            await context.read<WorkspaceProvider>().addTask(
                                  workspaceId: overview.workspace.id,
                                  scheduleId: scheduleId,
                                  title: titleCtrl.text.trim(),
                                  description: descCtrl.text.trim(),
                                  priority: priority,
                                  assigneeUid: selectedAssignee?.userUid,
                                  assigneeName: selectedAssignee?.displayName,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } finally {
                            if (ctx.mounted) {
                              setModalState(() => isSaving = false);
                            }
                          }
                        },
                  child: const Text('Giao việc'),
                ),
              ],
              child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShadInput(
                        controller: titleCtrl,
                        placeholder:
                            const Text('VD: Chuẩn bị slide thuyết trình'),
                      ),
                      const SizedBox(height: 10),
                      ShadInput(
                        controller: descCtrl,
                        placeholder: const Text('Mô tả chi tiết (tùy chọn)'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Giao cho thành viên',
                        style: shadTheme.textTheme.small,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Chưa phân công'),
                            selected: selectedAssignee == null,
                            onSelected: (_) =>
                                setModalState(() => selectedAssignee = null),
                          ),
                          ...overview.members.map((m) {
                            return ChoiceChip(
                              label: Text(m.displayName),
                              selected: selectedAssignee?.userUid == m.userUid,
                              onSelected: (_) =>
                                  setModalState(() => selectedAssignee = m),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Mức ưu tiên', style: shadTheme.textTheme.small),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [2, 1, 0].map((p) {
                          return ChoiceChip(
                            label: Text(AppColors.priorityLabel(p)),
                            selected: priority == p,
                            onSelected: (_) =>
                                setModalState(() => priority = p),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    titleCtrl.dispose();
    descCtrl.dispose();
  }

  static Future<void> showAddNoteDialog(
    BuildContext context,
    WorkspaceOverview overview,
    DateTime selectedDate,
  ) async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    var isSaving = false;

    await showShadDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return ShadDialog(
              title: const Text('Ghi chú chung theo ngày'),
              description: Text(
                'Ngày ${DateFormatter.formatDate(selectedDate)}',
              ),
              actions: [
                ShadButton.outline(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ShadButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty) return;
                          setModalState(() => isSaving = true);
                          try {
                            final auth = context.read<AuthProvider>();
                            await context.read<WorkspaceProvider>().addNote(
                                  workspaceId: overview.workspace.id,
                                  date: selectedDate,
                                  title: titleCtrl.text.trim(),
                                  content: contentCtrl.text.trim(),
                                  authorName: auth.displayName,
                                );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } finally {
                            if (ctx.mounted) {
                              setModalState(() => isSaving = false);
                            }
                          }
                        },
                  child: const Text('Lưu ghi chú'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShadInput(
                      controller: titleCtrl,
                      placeholder: const Text('Tiêu đề ghi chú nhóm'),
                    ),
                    const SizedBox(height: 10),
                    ShadInput(
                      controller: contentCtrl,
                      placeholder: const Text('Nội dung...'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    titleCtrl.dispose();
    contentCtrl.dispose();
  }

  @override
  State<SharedWorkspaceBody> createState() => _SharedWorkspaceBodyState();
}

class _SharedWorkspaceBodyState extends State<SharedWorkspaceBody> {
  bool _onlyMyTasks = false;

  Future<void> _showAddScheduleDialog(
    BuildContext context,
    WorkspaceOverview overview,
  ) =>
      SharedWorkspaceBody.showAddScheduleDialog(
        context,
        overview,
        widget.selectedDate,
      );

  Future<void> _showAddTaskDialog(
    BuildContext context,
    WorkspaceOverview overview, {
    String? scheduleId,
  }) =>
      SharedWorkspaceBody.showAddTaskDialog(
        context,
        overview,
        scheduleId: scheduleId,
      );

  Future<void> _showAddNoteDialog(
    BuildContext context,
    WorkspaceOverview overview,
  ) =>
      SharedWorkspaceBody.showAddNoteDialog(
        context,
        overview,
        widget.selectedDate,
      );

  @override
  Widget build(BuildContext context) {
    final wsProvider = context.watch<WorkspaceProvider>();
    final auth = context.watch<AuthProvider>();
    final shadTheme = ShadTheme.of(context);
    final overview = wsProvider.activeOverview;

    if (wsProvider.isLoading && overview == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (overview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.cloudOff, size: 42),
              const SizedBox(height: 10),
              Text(
                wsProvider.errorMessage ?? 'Không tải được dữ liệu Workspace.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ShadButton.outline(
                onPressed: () {
                  final id =
                      context.read<ScheduleProvider>().activeWorkspace.id;
                  wsProvider.loadOverview(id);
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final isoSelected = ScheduleModel.formatIsoDate(widget.selectedDate);
    final daySchedules = overview.schedules
        .where((s) => s.occursOnDate(widget.selectedDate))
        .toList();
    final dayNotes = overview.notes
        .where((n) => n.scheduleDate == null || n.scheduleDate == isoSelected)
        .toList();
    final standaloneTasks = overview.tasks.where((t) {
      if (t.scheduleId != null) return false;
      if (_onlyMyTasks && t.assigneeUid != auth.effectiveUserId) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => wsProvider.loadOverview(overview.workspace.id),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
        children: [
          // Thanh thông tin mã mời & thành viên nhóm
          ShadCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShadBadge.secondary(
                      child: Text('Mã mời: ${overview.workspace.inviteCode}'),
                    ),
                    const SizedBox(width: 6),
                    ShadBadge.outline(
                      child: Text('${overview.members.length} thành viên'),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Sao chép mã mời',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: overview.workspace.inviteCode),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép mã mời!')),
                        );
                      },
                      icon: const Icon(LucideIcons.copy, size: 16),
                    ),
                    IconButton(
                      tooltip: 'Làm mới',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          wsProvider.loadOverview(overview.workspace.id),
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả việc nhóm'),
                      selected: !_onlyMyTasks,
                      onSelected: (_) => setState(() => _onlyMyTasks = false),
                    ),
                    ChoiceChip(
                      label: const Text('Chỉ việc của tôi'),
                      selected: _onlyMyTasks,
                      onSelected: (_) => setState(() => _onlyMyTasks = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Mục lớn chung của ngày đang chọn
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lịch trình chung (${daySchedules.length})',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              ShadButton.ghost(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: () => _showAddScheduleDialog(context, overview),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 14),
                    SizedBox(width: 4),
                    Text('Thêm mục lớn'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (daySchedules.isEmpty)
            ShadCard(
              child: Text(
                'Chưa có mục lớn chung cho ngày ${DateFormatter.formatDate(widget.selectedDate)}.',
                style: shadTheme.textTheme.muted,
              ),
            )
          else
            ...daySchedules.map((s) {
              final childTasks = overview.tasks.where((t) {
                if (t.scheduleId != s.id) return false;
                if (_onlyMyTasks && t.assigneeUid != auth.effectiveUserId) {
                  return false;
                }
                return true;
              }).toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ShadCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ShadBadge.secondary(
                            child: Text('${s.startTime} - ${s.endTime}'),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Giao việc nhỏ trong mục này',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showAddTaskDialog(
                              context,
                              overview,
                              scheduleId: s.id,
                            ),
                            icon: const Icon(LucideIcons.userPlus, size: 16),
                          ),
                          IconButton(
                            tooltip: 'Xóa mục lớn',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => wsProvider.deleteSchedule(
                              workspaceId: overview.workspace.id,
                              scheduleId: s.id,
                            ),
                            icon: const Icon(LucideIcons.trash2, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.title,
                        style: shadTheme.textTheme.p.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (s.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(s.location, style: shadTheme.textTheme.muted),
                      ],
                      if (childTasks.isNotEmpty) ...[
                        const Divider(height: 16),
                        ...childTasks.map((t) => _buildTaskRow(
                              context,
                              overview.workspace.id,
                              t,
                              wsProvider,
                              shadTheme,
                            )),
                      ],
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 14),

          // 2. Công việc lẻ chung
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Công việc nhóm khác (${standaloneTasks.length})',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              ShadButton.ghost(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: () => _showAddTaskDialog(context, overview),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 14),
                    SizedBox(width: 4),
                    Text('Giao việc'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (standaloneTasks.isEmpty)
            Text('Chưa có việc nhóm nào.', style: shadTheme.textTheme.muted)
          else
            ShadCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: standaloneTasks
                    .map((t) => _buildTaskRow(
                          context,
                          overview.workspace.id,
                          t,
                          wsProvider,
                          shadTheme,
                        ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 16),

          // 3. Ghi chú chung theo ngày
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ghi chú chung (${dayNotes.length})',
                style: shadTheme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              ShadButton.ghost(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: () => _showAddNoteDialog(context, overview),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 14),
                    SizedBox(width: 4),
                    Text('Thêm ghi chú'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (dayNotes.isEmpty)
            Text('Chưa có ghi chú chung cho ngày này.',
                style: shadTheme.textTheme.muted)
          else
            ...dayNotes.map((n) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShadCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: shadTheme.textTheme.p.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (n.content.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(n.content, style: shadTheme.textTheme.muted),
                            ],
                            if (n.authorName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Bởi ${n.authorName}',
                                style: shadTheme.textTheme.muted
                                    .copyWith(fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Xóa ghi chú',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => wsProvider.deleteNote(
                          workspaceId: overview.workspace.id,
                          noteId: n.id,
                        ),
                        icon: const Icon(LucideIcons.trash2, size: 16),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTaskRow(
    BuildContext context,
    String workspaceId,
    WorkspaceTask task,
    WorkspaceProvider wsProvider,
    ShadThemeData shadTheme,
  ) {
    final isDone = task.isCompleted;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isDone ? 0.48 : 1.0,
      child: Row(
        children: [
          Checkbox(
            visualDensity: VisualDensity.compact,
            value: isDone,
            onChanged: (_) => wsProvider.toggleTask(
              workspaceId: workspaceId,
              taskId: task.id,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.assigneeName != null &&
                    task.assigneeName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Phụ trách: ${task.assigneeName}',
                    style: shadTheme.textTheme.muted.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Xóa việc',
            visualDensity: VisualDensity.compact,
            onPressed: () => wsProvider.deleteTask(
              workspaceId: workspaceId,
              taskId: task.id,
            ),
            icon: const Icon(LucideIcons.trash2, size: 15),
          ),
        ],
      ),
    );
  }
}
