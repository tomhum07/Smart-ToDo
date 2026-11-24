import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/schedule_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/schedule_provider.dart';

/// Màn hình Thêm / Chỉnh sửa Mục lớn (Lịch trình / Môn học) hỗ trợ ngày cụ thể & lặp hằng tuần.
class ScheduleFormScreen extends StatefulWidget {
  final ScheduleModel? schedule;

  const ScheduleFormScreen({super.key, this.schedule});

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _selectedDate;
  late bool _isRecurring;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _colorHex;
  String? _validationError;
  bool _isSaving = false;

  bool get _isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    final defaultDate = context.read<ScheduleProvider>().selectedDate;
    _titleController.text = s?.title ?? '';
    _locationController.text = s?.location ?? '';
    _noteController.text = s?.note ?? '';
    _selectedDate = (s?.scheduleDate != null
            ? DateTime.tryParse(s!.scheduleDate!)
            : null) ??
        defaultDate;
    _isRecurring = s?.isRecurring ?? false;
    _startTime = _parseTime(s?.startTime ?? '07:30');
    _endTime = _parseTime(s?.endTime ?? '09:30');
    _colorHex = s?.colorHex ?? AppColors.noteColorHexes[2];
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '7') ?? 7;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '30') ?? 30;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = 'Vui lòng nhập tên môn học / sự kiện.');
      return;
    }

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      setState(
        () => _validationError = 'Giờ kết thúc phải sau giờ bắt đầu.',
      );
      return;
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });

    final auth = context.read<AuthProvider>();
    final scheduleProvider = context.read<ScheduleProvider>();

    try {
      await scheduleProvider.saveSchedule(
        existing: widget.schedule,
        userId: auth.effectiveUserId,
        title: title,
        dayOfWeek: _selectedDate.weekday,
        scheduleDate: _selectedDate,
        isRecurring: _isRecurring,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        location: _locationController.text.trim(),
        note: _noteController.text.trim(),
        colorHex: _colorHex,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa mục lớn' : 'Thêm mục lớn mới'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ShadCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tên môn học / Sự kiện *',
                    style: shadTheme.textTheme.small,
                  ),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _titleController,
                    placeholder: const Text('VD: Lập trình Ứng dụng Mobile'),
                  ),
                  const SizedBox(height: 16),
                  Text('Ngày diễn ra', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  ShadButton.outline(
                    onPressed: _pickDate,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.calendar, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormatter.dayOfWeekLabel(_selectedDate.weekday)}, ${DateFormatter.formatDate(_selectedDate)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(LucideIcons.repeat, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Lặp lại hằng tuần'),
                            Text(
                              _isRecurring
                                  ? 'Tự động hiển thị vào mỗi ${DateFormatter.dayOfWeekLabel(_selectedDate.weekday)}'
                                  : 'Chỉ hiển thị duy nhất ngày ${DateFormatter.formatDate(_selectedDate)}',
                              style: shadTheme.textTheme.muted,
                            ),
                          ],
                        ),
                      ),
                      ShadSwitch(
                        value: _isRecurring,
                        onChanged: (v) => setState(() => _isRecurring = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Khung giờ', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ShadButton.outline(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          onPressed: () => _pickTime(isStart: true),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Bắt đầu: ${_formatTime(_startTime)}'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ShadButton.outline(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          onPressed: () => _pickTime(isStart: false),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Kết thúc: ${_formatTime(_endTime)}'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Phòng học / Địa điểm',
                    style: shadTheme.textTheme.small,
                  ),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _locationController,
                    placeholder: const Text('VD: Phòng B4-202'),
                  ),
                  const SizedBox(height: 14),
                  Text('Ghi chú thêm', style: shadTheme.textTheme.small),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _noteController,
                    placeholder: const Text('Giảng viên, tài liệu cần mang...'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Text('Màu đánh dấu', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppColors.noteColorHexes.skip(1).map((hex) {
                      final isSelected = _colorHex == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _colorHex = hex),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.fromHex(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? shadTheme.colorScheme.primary
                                  : Colors.grey.shade400,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  LucideIcons.check,
                                  size: 16,
                                  color: Colors.black87,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  if (_validationError != null) ...[
                    const SizedBox(height: 14),
                    ShadAlert.destructive(
                      icon: const Icon(LucideIcons.circleAlert),
                      title: const Text('Kiểm tra lại thông tin'),
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
                        : Text(_isEditing ? 'Lưu thay đổi' : 'Thêm vào lịch'),
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
