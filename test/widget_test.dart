import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/main.dart';
import 'package:todo_app/providers/theme_provider.dart';

void main() {
  testWidgets('SmartTodoApp renders LoginScreen and unified 4 tabs cleanly',
      (tester) async {
    final themeProvider = ThemeProvider();
    await tester.pumpWidget(SmartTodoApp(themeProvider: themeProvider));
    await tester.pumpAndSettle();

    expect(find.text('Smart Todo'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);

    // Chuyển vào chế độ xem trước Offline để kiểm tra 4 Tab hợp nhất
    final previewBtn = find.text('Xem trước Offline');
    await tester.ensureVisible(previewBtn);
    await tester.pumpAndSettle();
    await tester.tap(previewBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tab 1: Lịch & Việc (hợp nhất Mục lớn + Việc nhỏ + Việc khác)
    expect(find.text('Thêm mới'), findsOneWidget);

    // Tab 2: Ghi chú
    await tester.tap(find.text('Ghi chú'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ghi chú mới'), findsOneWidget);

    // Tab 3: Thống kê
    await tester.tap(find.text('Thống kê'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tiến độ Công việc'), findsOneWidget);

    // Tab 4: Hồ sơ
    await tester.tap(find.text('Hồ sơ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Hệ thống'), findsWidgets);
    await tester.scrollUntilVisible(find.text('???'), 300);
    expect(find.text('???'), findsOneWidget);
  });
}
