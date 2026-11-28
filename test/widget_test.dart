import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/data/services/app_update_service.dart';
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
    expect(find.byTooltip('Thêm mới'), findsOneWidget);

    // Tab 2: Ghi chú
    await tester.tap(find.text('Ghi chú'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Ghi chú mới'), findsOneWidget);

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
    await tester.scrollUntilVisible(find.text('Cập nhật ứng dụng'), 300);
    expect(find.text('Cập nhật ứng dụng'), findsOneWidget);
  });

  test('AppUpdateService.isNewerVersion compares SemVer tags accurately', () {
    expect(AppUpdateService.isNewerVersion('v1.2.0', '1.1.0'), isTrue);
    expect(AppUpdateService.isNewerVersion('1.1.1', '1.1.0'), isTrue);
    expect(AppUpdateService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
    expect(AppUpdateService.isNewerVersion('v1.1.0', '1.1.0'), isFalse);
    expect(AppUpdateService.isNewerVersion('1.0.9', '1.1.0'), isFalse);
  });

  test('AppUpdateService.selectBestApkAsset picks matching CPU ABI or fallback',
      () {
    final assets = [
      {'name': 'app-armeabi-v7a-release.apk', 'browser_download_url': 'u1'},
      {'name': 'app-arm64-v8a-release.apk', 'browser_download_url': 'u2'},
      {'name': 'app-x86_64-release.apk', 'browser_download_url': 'u3'},
      {'name': 'app-release.apk', 'browser_download_url': 'u4'},
    ];

    expect(
      AppUpdateService.selectBestApkAsset(assets, preferredAbi: 'arm64-v8a')?[
          'name'],
      'app-arm64-v8a-release.apk',
    );
    expect(
      AppUpdateService.selectBestApkAsset(assets, preferredAbi: 'armeabi-v7a')?[
          'name'],
      'app-armeabi-v7a-release.apk',
    );
    expect(
      AppUpdateService.selectBestApkAsset(assets, preferredAbi: 'x86_64')?[
          'name'],
      'app-x86_64-release.apk',
    );
    expect(
      AppUpdateService.selectBestApkAsset(assets, preferredAbi: 'mips')?[
          'name'],
      'app-release.apk',
    );
  });
}
