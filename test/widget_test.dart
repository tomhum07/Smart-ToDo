import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/main.dart';
import 'package:todo_app/providers/theme_provider.dart';

void main() {
  testWidgets('SmartTodoApp renders LoginScreen and MainShellScreen cleanly',
      (tester) async {
    final themeProvider = ThemeProvider();
    await tester.pumpWidget(SmartTodoApp(themeProvider: themeProvider));
    await tester.pumpAndSettle();

    expect(find.text('Smart Todo'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);

    // Chuyển vào chế độ xem trước Offline để kiểm tra AppBar & NavigationBar
    await tester.tap(find.text('Xem trước Offline'));
    await tester.pumpAndSettle();

    expect(find.text('Tab Công việc (Todo)'), findsOneWidget);
    expect(find.text('Ghi chú'), findsOneWidget);
    expect(find.text('Lịch trình'), findsOneWidget);
  });
}
