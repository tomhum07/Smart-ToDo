import 'package:flutter/material.dart';

/// Phân loại 3 ngưỡng kích thước màn hình chuẩn (Nhỏ / Vừa / Lớn).
enum DeviceSizeClass {
  compact, // Điện thoại màn hình nhỏ (< 360dp)
  medium, // Điện thoại tiêu chuẩn (360dp – 599dp)
  expanded, // Máy tính bảng / màn hình lớn / xoay ngang (>= 600dp)
}

/// Bộ tiện ích Responsive giúp tối ưu khoảng cách, số cột và giới hạn chiều rộng nội dung
/// trên đa dạng thiết bị nhỏ, vừa, lớn.
class ResponsiveLayout {
  ResponsiveLayout._();

  static const double compactBreakpoint = 360;
  static const double expandedBreakpoint = 600;
  static const double largeTabletBreakpoint = 900;

  static DeviceSizeClass sizeClassOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactBreakpoint) return DeviceSizeClass.compact;
    if (width < expandedBreakpoint) return DeviceSizeClass.medium;
    return DeviceSizeClass.expanded;
  }

  static bool isCompact(BuildContext context) =>
      sizeClassOf(context) == DeviceSizeClass.compact;

  static bool isExpanded(BuildContext context) =>
      sizeClassOf(context) == DeviceSizeClass.expanded;

  /// Đệm ngang thích ứng theo độ rộng màn hình.
  static double horizontalPadding(BuildContext context) {
    switch (sizeClassOf(context)) {
      case DeviceSizeClass.compact:
        return 12;
      case DeviceSizeClass.medium:
        return 16;
      case DeviceSizeClass.expanded:
        return 24;
    }
  }

  /// Số cột lưới Ghi chú dựa trên chiều rộng thực tế thay vì chỉ dựa vào hướng xoay.
  static int notesGridColumns(double availableWidth) {
    if (availableWidth < 340) return 1;
    if (availableWidth < 600) return 2;
    if (availableWidth < 900) return 3;
    return 4;
  }

  /// Tỉ lệ khung thẻ Ghi chú tương ứng theo số cột.
  static double notesGridAspectRatio(double availableWidth) {
    if (availableWidth < 340) return 1.55;
    if (availableWidth < 600) return 0.86;
    return 0.98;
  }
}

/// Căn giữa nội dung và giới hạn chiều rộng tối đa trên màn hình lớn / tablet
/// để thẻ và form nhập liệu không bị kéo giãn quá dài.
class ResponsiveCenterContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveCenterContainer({
    super.key,
    required this.child,
    this.maxWidth = 820,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
