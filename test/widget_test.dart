import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/main.dart';
import 'package:todo_app/providers/theme_provider.dart';

void main() {
  testWidgets('SmartTodoApp renders LoginScreen and all 5 tabs cleanly',
      (tester) async {
    final themeProvider = ThemeProvider();
    await tester.pumpWidget(SmartTodoApp(themeProvider: themeProvider));
    await tester.pumpAndSettle();

    expect(find.text('Smart Todo'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);

    // Chuyển vào chế độ xem trước Offline để kiểm tra 5 Tab
    final previewBtn = find.text('Xem trước Offline');
    await tester.ensureVisible(previewBtn);
    await tester.pumpAndSettle();
    await tester.tap(previewBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tab 1: Công việc (Todo)
    expect(find.text('Thêm việc'), findsOneWidget);

    // Tab 2: Ghi chú
    await tester.tap(find.text('Ghi chú'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ghi chú mới'), findsOneWidget);

    // Tab 3: Lịch trình
    await tester.tap(find.text('Lịch trình'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Thêm lịch'), findsOneWidget);

    // Tab 4: Thống kê (tách riêng)
    await tester.tap(find.text('Thống kê'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tiến độ Công việc'), findsOneWidget);

    // Tab 5: Hồ sơ (tách riêng)
    await tester.tap(find.text('Hồ sơ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Hệ thống'), findsWidgets);
    await tester.scrollUntilVisible(find.text('???'), 300);
    expect(find.text('???'), findsOneWidget);
  });
}
