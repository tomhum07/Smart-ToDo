import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/notification_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';

/// Tab Hồ sơ gồm 3 mục:
/// a. Tài khoản (Thông tin, Đổi mật khẩu [Coming soon], Đăng xuất)
/// b. Hệ thống (Bật/Tắt thông báo, Chế độ Sáng/Tối/Hệ thống, Thay đổi bảng màu giao diện)
/// c. ??? [Coming soon]
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final shadTheme = ShadTheme.of(context);

    final initialLetter = auth.displayName.isNotEmpty
        ? auth.displayName[0].toUpperCase()
        : 'U';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ==================== a. MỤC TÀI KHOẢN ====================
        ShadCard(
          title: const Text('Tài khoản'),
          description: const Text('Thông tin cá nhân và bảo mật tài khoản.'),
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: shadTheme.colorScheme.primary,
                      foregroundColor: shadTheme.colorScheme.primaryForeground,
                      child: Text(
                        initialLetter,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.displayName,
                            style: shadTheme.textTheme.p.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.email,
                            style: shadTheme.textTheme.muted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.keyRound, size: 19),
                    title: const Text('Đổi mật khẩu'),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                ),
                const SizedBox(height: 10),
                ShadButton.destructive(
                  onPressed: () => auth.signOut(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.logOut, size: 16),
                      SizedBox(width: 8),
                      Text('Đăng xuất'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ==================== b. MỤC HỆ THỐNG ====================
        ShadCard(
          title: const Text('Hệ thống'),
          description: const Text(
            'Cài đặt thông báo, chế độ hiển thị và màu sắc giao diện.',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cài đặt thông báo (Bật / Tắt)
                Row(
                  children: [
                    const Icon(LucideIcons.bell, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cài đặt thông báo'),
                          Text(
                            themeProvider.notificationsEnabled
                                ? 'Đang bật nhắc nhở hạn chót'
                                : 'Đã tắt toàn bộ thông báo cục bộ',
                            style: shadTheme.textTheme.muted,
                          ),
                        ],
                      ),
                    ),
                    ShadSwitch(
                      value: themeProvider.notificationsEnabled,
                      onChanged: (v) =>
                          themeProvider.setNotificationsEnabled(v),
                    ),
                  ],
                ),
                if (themeProvider.notificationsEnabled) ...[
                  const SizedBox(height: 10),
                  ShadButton.outline(
                    onPressed: () async {
                      await NotificationService.instance
                          .showInstantTestNotification();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã gửi thông báo kiểm thử lên thanh trạng thái!',
                          ),
                        ),
                      );
                    },
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Gửi thông báo kiểm thử'),
                    ),
                  ),
                ],
                const Divider(height: 24),

                // Chế độ Sáng / Tối / Hệ thống
                Text(
                  'Chế độ hiển thị',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ThemeModeButton(
                      label: 'Sáng',
                      icon: LucideIcons.sun,
                      selected: themeProvider.themeMode == ThemeMode.light,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                    ),
                    const SizedBox(width: 8),
                    _ThemeModeButton(
                      label: 'Tối',
                      icon: LucideIcons.moon,
                      selected: themeProvider.themeMode == ThemeMode.dark,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                    ),
                    const SizedBox(width: 8),
                    _ThemeModeButton(
                      label: 'Hệ thống',
                      icon: LucideIcons.smartphone,
                      selected: themeProvider.themeMode == ThemeMode.system,
                      onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Thay đổi giao diện (Bảng màu chủ đạo shadcn_ui)
                Text(
                  'Thay đổi giao diện (Bảng màu)',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppColorPalette.values.map((palette) {
                    final isSelected = themeProvider.palette == palette;
                    return ChoiceChip(
                      label: Text(palette.label),
                      selected: isSelected,
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: palette.previewColor,
                      ),
                      onSelected: (_) => themeProvider.setPalette(palette),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ==================== c. MỤC ??? (COMING SOON) ====================
        ShadCard(
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('???'),
              ShadBadge.secondary(child: Text('Coming soon')),
            ],
          ),
          description: const Text(
            'Tính năng bí mật sẽ được hé lộ ở các bản cập nhật tiếp theo.',
          ),
        ),
      ],
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? dialogError;
    var isSaving = false;

    await showShadDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return ShadDialog(
              title: const Text('Đổi mật khẩu'),
              description: const Text(
                'Nhập mật khẩu hiện tại và mật khẩu mới (tối thiểu 6 ký tự).',
              ),
              actions: [
                ShadButton.outline(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ShadButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final currentPass = currentCtrl.text;
                          final newPass = newCtrl.text;
                          final confirmPass = confirmCtrl.text;

                          if (currentPass.isEmpty) {
                            setDialogState(
                              () => dialogError =
                                  'Vui lòng nhập mật khẩu hiện tại.',
                            );
                            return;
                          }
                          if (newPass.length < 6) {
                            setDialogState(
                              () => dialogError =
                                  'Mật khẩu mới cần ít nhất 6 ký tự.',
                            );
                            return;
                          }
                          if (newPass != confirmPass) {
                            setDialogState(
                              () => dialogError =
                                  'Mật khẩu xác nhận không khớp.',
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          final error = await context
                              .read<AuthProvider>()
                              .changePassword(
                                currentPassword: currentPass,
                                newPassword: newPass,
                              );
                          if (!ctx.mounted) return;
                          if (error != null) {
                            setDialogState(() {
                              isSaving = false;
                              dialogError = error;
                            });
                            return;
                          }
                          Navigator.pop(ctx);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đổi mật khẩu thành công!'),
                            ),
                          );
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cập nhật'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShadInput(
                      controller: currentCtrl,
                      placeholder: const Text('Mật khẩu hiện tại'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 10),
                    ShadInput(
                      controller: newCtrl,
                      placeholder: const Text('Mật khẩu mới (≥ 6 ký tự)'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 10),
                    ShadInput(
                      controller: confirmCtrl,
                      placeholder: const Text('Xác nhận mật khẩu mới'),
                      obscureText: true,
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      ShadAlert.destructive(
                        icon: const Icon(LucideIcons.circleAlert),
                        title: const Text('Đổi mật khẩu thất bại'),
                        description: Text(dialogError!),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }
}

class _ThemeModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? shadTheme.colorScheme.primary
                : shadTheme.colorScheme.secondary.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? shadTheme.colorScheme.primaryForeground
                    : shadTheme.colorScheme.foreground,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? shadTheme.colorScheme.primaryForeground
                        : shadTheme.colorScheme.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
