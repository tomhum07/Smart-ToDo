import 'package:intl/intl.dart';

/// Hỗ trợ định dạng ngày giờ chuẩn Việt Nam.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('HH:mm - dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  static String formatDate(DateTime date) => _dateFormat.format(date);

  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);

  static String formatTime(DateTime date) => _timeFormat.format(date);

  static String formatEpochDate(int epochMs) =>
      formatDate(DateTime.fromMillisecondsSinceEpoch(epochMs));

  static String formatEpochDateTime(int epochMs) =>
      formatDateTime(DateTime.fromMillisecondsSinceEpoch(epochMs));

  static String dayOfWeekLabel(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Thứ 2';
      case 2:
        return 'Thứ 3';
      case 3:
        return 'Thứ 4';
      case 4:
        return 'Thứ 5';
      case 5:
        return 'Thứ 6';
      case 6:
        return 'Thứ 7';
      case 7:
        return 'Chủ nhật';
      default:
        return 'Không rõ';
    }
  }
}
