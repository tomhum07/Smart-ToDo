import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/task_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/task_provider.dart';

/// Màn hình Thêm / Chỉnh sửa Công việc nhỏ (gắn vào Mục lớn hoặc Việc khác / Tự do).
class TaskFormScreen extends StatefulWidget {
  final TaskModel? task;
  final String? initialScheduleId;

  const TaskFormScreen({super.key, this.task, this.initialScheduleId});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _scheduleId;
  late String _category;
  late int _priority;
  DateTime? _dueDate;
  late int _remindBeforeMinutes;
  late int _repeatCount;
  late int _repeatIntervalSeconds;
  String? _validationError;
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _scheduleId = t?.scheduleId ?? widget.initialScheduleId;
    _titleController.text = t?.title ?? '';
    _descController.text = t?.description ?? '';
    _category = t?.category ?? AppColors.defaultCategories.first;
    _priority = t?.priority ?? 1;
    _dueDate = t?.dueDate != null
        ? DateTime.fromMillisecondsSinceEpoch(t!.dueDate!)
        : null;
    _remindBeforeMinutes = t?.remindBeforeMinutes ?? 10;
    _repeatCount = t?.repeatCount ?? 1;
    _repeatIntervalSeconds = t?.repeatIntervalSeconds ?? 60;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initialDate = _dueDate ?? now.add(const Duration(minutes: 15));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted) return;

    final time = pickedTime ?? const TimeOfDay(hour: 23, minute: 59);
    setState(() {
      _dueDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = 'Vui lòng nhập tiêu đề công việc.');
      return;
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });

    final auth = context.read<AuthProvider>();
    final taskProvider = context.read<TaskProvider>();

    try {
      if (_isEditing) {
        final updated = widget.task!.copyWith(
          scheduleId: _scheduleId,
          clearScheduleId: _scheduleId == null,
          title: title,
          description: _descController.text.trim(),
          category: _category,
          priority: _priority,
          dueDate: _dueDate?.millisecondsSinceEpoch,
          clearDueDate: _dueDate == null,
          remindBeforeMinutes: _remindBeforeMinutes,
          repeatIntervalSeconds: _repeatIntervalSeconds,
          repeatCount: _repeatCount,
        );
        await taskProvider.updateTask(updated);
      } else {
        await taskProvider.addTask(
          userId: auth.effectiveUserId,
          scheduleId: _scheduleId,
          title: title,
          description: _descController.text.trim(),
          category: _category,
          priority: _priority,
          dueDate: _dueDate?.millisecondsSinceEpoch,
          remindBeforeMinutes: _remindBeforeMinutes,
          repeatIntervalSeconds: _repeatIntervalSeconds,
          repeatCount: _repeatCount,
        );
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final schedules = context.watch<ScheduleProvider>().allSchedules;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa công việc' : 'Thêm công việc'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ShadCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Thuộc mục lớn (Lịch trình)', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Việc khác / Tự do'),
                        selected: _scheduleId == null,
                        onSelected: (_) => setState(() => _scheduleId = null),
                      ),
                      ...schedules.map((s) {
                        return ChoiceChip(
                          label: Text(
                            '${s.title} (${DateFormatter.dayOfWeekLabel(s.dayOfWeek)})',
                          ),
                          selected: _scheduleId == s.id,
                          onSelected: (_) => setState(() => _scheduleId = s.id),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Tiêu đề *', style: shadTheme.textTheme.small),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _titleController,
                    placeholder: const Text('VD: Nộp bài tập Flutter'),
                  ),
                  const SizedBox(height: 14),
                  Text('Mô tả chi tiết', style: shadTheme.textTheme.small),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _descController,
                    placeholder: const Text('Ghi chú thêm cho công việc...'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Text('Danh mục', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppColors.defaultCategories.map((cat) {
                      return ChoiceChip(
                        label: Text(cat),
                        selected: _category == cat,
                        onSelected: (_) => setState(() => _category = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Mức độ ưu tiên', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [2, 1, 0].map((p) {
                      return ChoiceChip(
                        label: Text(AppColors.priorityLabel(p)),
                        selected: _priority == p,
                        avatar: CircleAvatar(
                          radius: 5,
                          backgroundColor: AppColors.priorityColor(p),
                        ),
                        onSelected: (_) => setState(() => _priority = p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Hạn chót (Deadline)', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ShadButton.outline(
                          onPressed: _pickDueDate,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.calendarClock, size: 16),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _dueDate == null
                                      ? 'Chọn ngày & giờ hạn chót'
                                      : DateFormatter.formatDateTime(_dueDate!),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_dueDate != null) ...[
                        const SizedBox(width: 8),
                        ShadButton.ghost(
                          onPressed: () => setState(() => _dueDate = null),
                          child: const Icon(LucideIcons.x, size: 18),
                        ),
                      ],
                    ],
                  ),
                  if (_dueDate != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Nhắc trước hạn chót',
                      style: shadTheme.textTheme.small,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        (0, 'Không nhắc'),
                        (1, '1 phút'),
                        (5, '5 phút'),
                        (10, '10 phút'),
                        (15, '15 phút'),
                        (30, '30 phút'),
                        (60, '1 giờ'),
                        (1440, '1 ngày'),
                      ].map((item) {
                        final (minutes, label) = item;
                        return ChoiceChip(
                          label: Text(label),
                          selected: _remindBeforeMinutes == minutes,
                          onSelected: (_) =>
                              setState(() => _remindBeforeMinutes = minutes),
                        );
                      }).toList(),
                    ),
                    if (_remindBeforeMinutes > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Số lần nhắc (nhắc lại)',
                        style: shadTheme.textTheme.small,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [1, 2, 3, 4, 5].map((count) {
                          return ChoiceChip(
                            label: Text(count == 1 ? '1 lần' : '$count lần'),
                            selected: _repeatCount == count,
                            onSelected: (_) =>
                                setState(() => _repeatCount = count),
                          );
                        }).toList(),
                      ),
                      if (_repeatCount > 1) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Khoảng thời gian giữa các lần nhắc lại',
                          style: shadTheme.textTheme.small,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            (30, '30 giây'),
                            (60, '1 phút'),
                            (120, '2 phút'),
                            (300, '5 phút'),
                            (600, '10 phút'),
                          ].map((item) {
                            final (seconds, label) = item;
                            return ChoiceChip(
                              label: Text(label),
                              selected: _repeatIntervalSeconds == seconds,
                              onSelected: (_) => setState(
                                () => _repeatIntervalSeconds = seconds,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ],
                  if (_validationError != null) ...[
                    const SizedBox(height: 14),
                    ShadAlert.destructive(
                      icon: const Icon(LucideIcons.circleAlert),
                      title: const Text('Thiếu thông tin'),
                      description: Text(_validationError!),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ShadButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Lưu thay đổi' : 'Tạo công việc'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
