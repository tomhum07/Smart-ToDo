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
import 'swipe_to_delete_tile.dart';
import 'workspace_members_sheet.dart';

/// Giao diện nội dung khi người dùng đang xem một Không gian Chia sẻ Nhóm (Shared Workspace).
/// Hiển thị Mục lớn chung, Công việc nhỏ có phân công thành viên & Ghi chú chung theo ngày.
class SharedWorkspaceBody extends StatefulWidget {
  final DateTime selectedDate;
  final ScrollController? scrollController;

  const SharedWorkspaceBody({
    super.key,
    required this.selectedDate,
    this.scrollController,
  });

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
    String? errorText;

    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final shadTheme = ShadTheme.of(ctx);
            final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Thêm Mục lớn chung',
                      style: shadTheme.textTheme.h4,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ngày ${DateFormatter.formatDate(selectedDate)} • ${overview.workspace.name}',
                      style: shadTheme.textTheme.muted,
                    ),
                    const SizedBox(height: 14),
                    ShadInput(
                      controller: titleCtrl,
                      placeholder: const Text('VD: Họp tổng kết tuần'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ShadButton.outline(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            onPressed: () async {
                              final p = await showTimePicker(
                                context: ctx,
                                initialTime: startTime,
                                builder: (c, child) => MediaQuery(
                                  data: MediaQuery.of(c)
                                      .copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                ),
                              );
                              if (p != null) setModalState(() => startTime = p);
                            },
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Từ: ${fmt(startTime)}'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ShadButton.outline(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            onPressed: () async {
                              final p = await showTimePicker(
                                context: ctx,
                                initialTime: endTime,
                                builder: (c, child) => MediaQuery(
                                  data: MediaQuery.of(c)
                                      .copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                ),
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
                      placeholder: const Text('Địa điểm (tùy chọn)'),
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
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ShadButton.outline(
                            onPressed:
                                isSaving ? null : () => Navigator.pop(ctx),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ShadButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (titleCtrl.text.trim().isEmpty) {
                                      setModalState(
                                        () => errorText =
                                            'Vui lòng nhập tên mục lớn.',
                                      );
                                      return;
                                    }
                                    setModalState(() {
                                      isSaving = true;
                                      errorText = null;
                                    });
                                    try {
                                      final auth = context.read<AuthProvider>();
                                      await context
                                          .read<WorkspaceProvider>()
                                          .addSchedule(
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
                                      HapticFeedback.lightImpact();
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setModalState(() {
                                          isSaving = false;
                                          errorText = e
                                              .toString()
                                              .replaceFirst('Exception: ', '');
                                        });
                                      }
                                    }
                                  },
                            child: isSaving
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Đang thêm...'),
                                    ],
                                  )
                                : const Text('Thêm mục lớn'),
                          ),
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
    DateTime? dueDate;
    var remindBeforeMinutes = 10;
    WorkspaceMember? selectedAssignee =
        overview.members.isNotEmpty ? overview.members.first : null;
    var isSaving = false;
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final shadTheme = ShadTheme.of(ctx);
            final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;

            Future<void> pickDueDate() async {
              FocusScope.of(ctx).unfocus();
              final now = DateTime.now();
              final initial = dueDate ?? now.add(const Duration(hours: 1));
              final pickedDate = await showDatePicker(
                context: ctx,
                initialDate: initial,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );
              if (pickedDate == null || !ctx.mounted) return;
              final pickedTime = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay.fromDateTime(initial),
                builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (!ctx.mounted) return;
              final time = pickedTime ?? const TimeOfDay(hour: 23, minute: 59);
              setModalState(() {
                dueDate = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  time.hour,
                  time.minute,
                );
              });
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + bottomInset),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Giao Công việc nhóm',
                        style: shadTheme.textTheme.h4,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Phân công việc, đặt hạn chót & nhắc nhở cho thành viên.',
                        style: shadTheme.textTheme.muted,
                      ),
                      const SizedBox(height: 14),
                      ShadInput(
                        controller: titleCtrl,
                        placeholder:
                            const Text('VD: Chuẩn bị slide thuyết trình'),
                        autofocus: true,
                      ),
                      const SizedBox(height: 10),
                      ShadInput(
                        controller: descCtrl,
                        placeholder: const Text('Mô tả chi tiết (tùy chọn)'),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Hạn chót (Deadline)',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ShadButton.outline(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              onPressed: pickDueDate,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.calendarClock,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      dueDate == null
                                          ? 'Chọn ngày & giờ hạn chót'
                                          : DateFormatter.formatDateTime(
                                              dueDate!,
                                            ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (dueDate != null) ...[
                            const SizedBox(width: 6),
                            ShadButton.ghost(
                              padding: const EdgeInsets.all(8),
                              onPressed: () =>
                                  setModalState(() => dueDate = null),
                              child: const Icon(LucideIcons.x, size: 16),
                            ),
                          ],
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: dueDate == null
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nhắc trước hạn chót',
                                    style: shadTheme.textTheme.small.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: const [
                                      (0, 'Đúng giờ'),
                                      (1, '1 phút'),
                                      (5, '5 phút'),
                                      (10, '10 phút'),
                                      (15, '15 phút'),
                                      (30, '30 phút'),
                                      (60, '1 giờ'),
                                    ].map((item) {
                                      final (mins, label) = item;
                                      return ChoiceChip(
                                        label: Text(label),
                                        selected: remindBeforeMinutes == mins,
                                        onSelected: (_) => setModalState(
                                          () => remindBeforeMinutes = mins,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Giao cho thành viên',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text('Cả nhóm'),
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
                      const SizedBox(height: 14),
                      Text(
                        'Mức ưu tiên',
                        style: shadTheme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [2, 1, 0].map((p) {
                          return ChoiceChip(
                            label: Text(AppColors.priorityLabel(p)),
                            selected: priority == p,
                            avatar: CircleAvatar(
                              radius: 4.5,
                              backgroundColor: AppColors.priorityColor(p),
                            ),
                            onSelected: (_) =>
                                setModalState(() => priority = p),
                          );
                        }).toList(),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ShadButton.outline(
                              onPressed:
                                  isSaving ? null : () => Navigator.pop(ctx),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ShadButton(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (titleCtrl.text.trim().isEmpty) {
                                        setModalState(
                                          () => errorText =
                                              'Vui lòng nhập tiêu đề công việc.',
                                        );
                                        return;
                                      }
                                      setModalState(() {
                                        isSaving = true;
                                        errorText = null;
                                      });
                                      try {
                                        await context
                                            .read<WorkspaceProvider>()
                                            .addTask(
                                              workspaceId:
                                                  overview.workspace.id,
                                              scheduleId: scheduleId,
                                              title: titleCtrl.text.trim(),
                                              description: descCtrl.text.trim(),
                                              priority: priority,
                                              dueDate: dueDate
                                                  ?.millisecondsSinceEpoch,
                                              remindBeforeMinutes:
                                                  remindBeforeMinutes,
                                              assigneeUid:
                                                  selectedAssignee?.userUid,
                                              assigneeName:
                                                  selectedAssignee?.displayName,
                                            );
                                        HapticFeedback.lightImpact();
                                        if (ctx.mounted) Navigator.pop(ctx);
                                      } catch (e) {
                                        if (ctx.mounted) {
                                          setModalState(() {
                                            isSaving = false;
                                            errorText = e
                                                .toString()
                                                .replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                );
                                          });
                                        }
                                      }
                                    },
                              child: isSaving
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('Đang giao việc...'),
                                      ],
                                    )
                                  : const Text('Giao việc'),
                            ),
                          ),
                        ],
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
    String? errorText;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final shadTheme = ShadTheme.of(ctx);
            final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ghi chú chung theo ngày',
                      style: shadTheme.textTheme.h4,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ngày ${DateFormatter.formatDate(selectedDate)}',
                      style: shadTheme.textTheme.muted,
                    ),
                    const SizedBox(height: 14),
                    ShadInput(
                      controller: titleCtrl,
                      placeholder: const Text('Tiêu đề ghi chú nhóm'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 10),
                    ShadInput(
                      controller: contentCtrl,
                      placeholder: const Text('Nội dung...'),
                      maxLines: 3,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ShadButton.outline(
                            onPressed:
                                isSaving ? null : () => Navigator.pop(ctx),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ShadButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (titleCtrl.text.trim().isEmpty) {
                                      setModalState(
                                        () => errorText =
                                            'Vui lòng nhập tiêu đề ghi chú.',
                                      );
                                      return;
                                    }
                                    setModalState(() {
                                      isSaving = true;
                                      errorText = null;
                                    });
                                    try {
                                      final auth = context.read<AuthProvider>();
                                      await context
                                          .read<WorkspaceProvider>()
                                          .addNote(
                                            workspaceId: overview.workspace.id,
                                            date: selectedDate,
                                            title: titleCtrl.text.trim(),
                                            content: contentCtrl.text.trim(),
                                            authorName: auth.displayName,
                                          );
                                      HapticFeedback.lightImpact();
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setModalState(() {
                                          isSaving = false;
                                          errorText = e
                                              .toString()
                                              .replaceFirst('Exception: ', '');
                                        });
                                      }
                                    }
                                  },
                            child: isSaving
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Đang lưu...'),
                                    ],
                                  )
                                : const Text('Lưu ghi chú'),
                          ),
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
    contentCtrl.dispose();
  }

  @override
  State<SharedWorkspaceBody> createState() => _SharedWorkspaceBodyState();
}

class _SharedWorkspaceBodyState extends State<SharedWorkspaceBody>
    with WidgetsBindingObserver {
  bool _onlyMyTasks = false;
  WorkspaceProvider? _wsProvider;
  String? _syncedWorkspaceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureRealtimeSync();
    });
  }

  void _ensureRealtimeSync() {
    final activeWsId = context.read<ScheduleProvider>().activeWorkspace.id;
    final uid = context.read<AuthProvider>().effectiveUserId;
    _wsProvider = context.read<WorkspaceProvider>();
    if (_syncedWorkspaceId != activeWsId) {
      _syncedWorkspaceId = activeWsId;
      _wsProvider!.startRealtimeSync(activeWsId, currentUserUid: uid);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _wsProvider?.resumeRealtimeSync();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wsProvider?.pauseRealtimeSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsProvider?.stopRealtimeSync(
      onlyIfWorkspaceId: _syncedWorkspaceId,
      notify: false,
    );
    super.dispose();
  }

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

  Future<void> _confirmDeleteSchedule(
    String workspaceId,
    WorkspaceSchedule schedule,
  ) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Xóa lịch trình chung?'),
        description: Text(
          'Bạn có chắc muốn xóa "${schedule.title}" khỏi nhóm không? Các công việc gắn bên trong cũng sẽ bị xóa.',
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
    if (confirmed == true && mounted) {
      await context.read<WorkspaceProvider>().deleteSchedule(
            workspaceId: workspaceId,
            scheduleId: schedule.id,
          );
    }
  }

  Future<void> _confirmDeleteTask(
    String workspaceId,
    WorkspaceTask task,
  ) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Xóa công việc nhóm?'),
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
      await context.read<WorkspaceProvider>().deleteTask(
            workspaceId: workspaceId,
            taskId: task.id,
          );
    }
  }

  Future<void> _confirmDeleteNote(
    String workspaceId,
    WorkspaceNote note,
  ) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Xóa ghi chú chung?'),
        description: Text('Bạn có chắc muốn xóa ghi chú "${note.title}" không?'),
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
      await context.read<WorkspaceProvider>().deleteNote(
            workspaceId: workspaceId,
            noteId: note.id,
          );
    }
  }

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
        controller: widget.scrollController,
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
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ShadBadge.secondary(
                            child: Text(
                              'Mã mời: ${overview.workspace.inviteCode}',
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => WorkspaceMembersSheet.show(context),
                            child: ShadBadge.outline(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.users, size: 11),
                                  const SizedBox(width: 4),
                                  Text('${overview.members.length} TV'),
                                ],
                              ),
                            ),
                          ),
                          if (wsProvider.isRealtimeActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: Color(0xFF16A34A),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Live',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Sao chép mã mời',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
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
                      tooltip: 'Quản lý nhóm & thành viên',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () => WorkspaceMembersSheet.show(context),
                      icon: const Icon(LucideIcons.settings, size: 16),
                    ),
                    IconButton(
                      tooltip: 'Làm mới',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
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
                child: SwipeToDeleteTile(
                  key: ValueKey('swipe_ws_sched_${s.id}'),
                  onDelete: () => _confirmDeleteSchedule(
                    overview.workspace.id,
                    s,
                  ),
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
                child: SwipeToDeleteTile(
                  key: ValueKey('swipe_ws_note_${n.id}'),
                  onDelete: () => _confirmDeleteNote(
                    overview.workspace.id,
                    n,
                  ),
                  child: ShadCard(
                    padding: const EdgeInsets.all(12),
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isOverdue = !isDone && task.dueDate != null && task.dueDate! < nowMs;
    final isDueSoon = !isDone &&
        task.dueDate != null &&
        !isOverdue &&
        task.dueDate! <= nowMs + const Duration(hours: 24).inMilliseconds;

    final dueColor = isOverdue
        ? const Color(0xFFDC2626)
        : isDueSoon
            ? const Color(0xFFD97706)
            : shadTheme.colorScheme.mutedForeground;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SwipeToDeleteTile(
        key: ValueKey('swipe_ws_task_${task.id}'),
        actionWidth: 74,
        showIcon: false,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        onDelete: () => _confirmDeleteTask(workspaceId, task),
        child: ColoredBox(
          color: shadTheme.colorScheme.card,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: isDone ? 0.48 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: isDone,
                    onChanged: (_) {
                      HapticFeedback.selectionClick();
                      wsProvider.toggleTask(
                        workspaceId: workspaceId,
                        taskId: task.id,
                      );
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, right: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: shadTheme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (task.assigneeName != null &&
                                  task.assigneeName!.isNotEmpty)
                                Text(
                                  'Phụ trách: ${task.assigneeName}',
                                  style: shadTheme.textTheme.muted
                                      .copyWith(fontSize: 11),
                                ),
                              if (task.dueDate != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: dueColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.clock,
                                        size: 11,
                                        color: dueColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        DateFormatter.formatEpochDateTime(
                                          task.dueDate!,
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: dueColor,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
