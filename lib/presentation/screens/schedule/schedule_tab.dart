import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/holiday_model.dart';
import '../../../data/models/schedule_model.dart';
import '../../../data/remote/holiday_api_service.dart';
import '../../../providers/schedule_provider.dart';

/// Tab Thời khóa biểu: Thanh 7 ngày T2->CN gọn đều trên 1 hàng + Ngày lễ VN (Nager.Date FutureBuilder).
class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final HolidayApiService _holidayApiService = HolidayApiService();
  Future<List<HolidayModel>>? _holidaysFuture;
  bool _showHolidays = false;

  Future<List<HolidayModel>> _getHolidaysFuture() {
    return _holidaysFuture ??=
        _holidayApiService.fetchVietnamHolidays(DateTime.now().year);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ScheduleModel schedule,
  ) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Xóa lịch trình?'),
        description: Text(
          'Bạn có chắc muốn xóa "${schedule.title}" (${schedule.startTime} - ${schedule.endTime})?',
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
      await context.read<ScheduleProvider>().deleteSchedule(schedule);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();
    final items = scheduleProvider.schedulesForSelectedDay;
    final shadTheme = ShadTheme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Thanh 7 ngày T2 -> CN co đều gọn trong 1 hàng duy nhất
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: List.generate(7, (index) {
                final day = index + 1;
                final isSelected = scheduleProvider.selectedDayOfWeek == day;
                final count = scheduleProvider.countForDay(day);
                final shortLabel = day == 7 ? 'CN' : 'T${day + 1}';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => scheduleProvider.selectDay(day),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? shadTheme.colorScheme.primary
                              : shadTheme.colorScheme.secondary
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                shortLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? shadTheme.colorScheme.primaryForeground
                                      : shadTheme.colorScheme.foreground,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: count > 0
                                    ? (isSelected
                                        ? shadTheme
                                            .colorScheme.primaryForeground
                                        : shadTheme.colorScheme.primary)
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

          // Thẻ Ngày lễ Việt Nam thu gọn/mở rộng (Nager.Date REST API + FutureBuilder)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: ShadCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => setState(() => _showHolidays = !_showHolidays),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.sparkles, size: 15),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ngày nghỉ lễ Việt Nam ${DateTime.now().year}',
                              style: shadTheme.textTheme.small.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            _showHolidays
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showHolidays) ...[
                    const Divider(height: 12),
                    FutureBuilder<List<HolidayModel>>(
                      future: _getHolidaysFuture(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Không tải được ngày lễ (kiểm tra mạng).',
                                  style: shadTheme.textTheme.muted,
                                ),
                              ),
                              ShadButton.outline(
                                onPressed: () => setState(() {
                                  _holidaysFuture = _holidayApiService
                                      .fetchVietnamHolidays(
                                    DateTime.now().year,
                                  );
                                }),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          );
                        }
                        final holidays = snapshot.data ?? [];
                        if (holidays.isEmpty) {
                          return const Text('Không có dữ liệu ngày lễ.');
                        }
                        return Column(
                          children: holidays.take(5).map((h) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      h.localName,
                                      style: shadTheme.textTheme.small,
                                    ),
                                  ),
                                  ShadBadge.secondary(
                                    child: Text(
                                      DateFormatter.formatDate(h.date),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),

          // Danh sách lịch học / sự kiện trong ngày
          Expanded(
            child: scheduleProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.calendarDays, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'Chưa có lịch trình nào cho ${DateFormatter.dayOfWeekLabel(scheduleProvider.selectedDayOfWeek)}.\nBấm "Thêm lịch" để tạo tiết học / sự kiện!',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ScheduleCardItem(
                            schedule: item,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.scheduleForm,
                              arguments: item,
                            ),
                            onDelete: () => _confirmDelete(context, item),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'schedule_add_btn',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.scheduleForm),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Thêm lịch'),
      ),
    );
  }
}

class _ScheduleCardItem extends StatelessWidget {
  final ScheduleModel schedule;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScheduleCardItem({
    required this.schedule,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final accentColor = schedule.colorHex.toUpperCase() == '#FFFFFF'
        ? shadTheme.colorScheme.primary
        : AppColors.fromHex(schedule.colorHex);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShadCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
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
                            const Spacer(),
                            IconButton(
                              tooltip: 'Xóa lịch trình',
                              visualDensity: VisualDensity.compact,
                              onPressed: onDelete,
                              icon: const Icon(LucideIcons.trash2, size: 17),
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
                          const SizedBox(height: 4),
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
                        if (schedule.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            schedule.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: shadTheme.textTheme.muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
