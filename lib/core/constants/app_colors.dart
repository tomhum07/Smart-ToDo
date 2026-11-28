import 'package:flutter/material.dart';

/// Bảng màu chuẩn hóa cho thẻ ghi chú, lịch trình và mức độ ưu tiên.
class AppColors {
  AppColors._();

  static const List<String> noteColorHexes = [
    '#FFFFFF', // Trắng mặc định
    '#FEF3C7', // Vàng pastel
    '#DBEAFE', // Xanh dương pastel
    '#DCFCE7', // Xanh lá pastel
    '#FCE7F3', // Hồng pastel
    '#EDE9FE', // Tím pastel
    '#FFEDD5', // Cam pastel
  ];

  static const List<String> defaultCategories = [
    'Công việc',
    'Cá nhân',
    'Học tập',
    'Gia đình',
    'Khác',
  ];

  static Color fromHex(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return Colors.white;
  }

  static Color priorityColor(int priority) {
    switch (priority) {
      case 2:
        return const Color(0xFFDC2626); // High - Đỏ
      case 1:
        return const Color(0xFFD97706); // Medium - Cam/Vàng đậm
      default:
        return const Color(0xFF16A34A); // Low - Xanh lá
    }
  }

  static String priorityLabel(int priority) {
    switch (priority) {
      case 2:
        return 'Cao';
      case 1:
        return 'Trung bình';
      default:
        return 'Thấp';
    }
  }
}
