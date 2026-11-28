import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/routes/app_routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';

/// Màn hình Đăng nhập thiết kế theo bộ giao diện shadcn_ui.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _localValidationError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _localValidationError = 'Vui lòng nhập email hợp lệ.');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _localValidationError = 'Mật khẩu phải có ít nhất 6 ký tự.',
      );
      return;
    }

    setState(() => _localValidationError = null);
    final auth = context.read<AuthProvider>();
    final success = await auth.signIn(email: email, password: password);

    if (!mounted) return;
    if (success) {
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName != AppRoutes.root) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.root,
          (route) => false,
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? dialogError;
    var isSending = false;

    await showShadDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return ShadDialog(
              title: const Text('Quên mật khẩu'),
              description: const Text(
                'Nhập email đã đăng ký, Firebase sẽ gửi đường dẫn đặt lại mật khẩu vào hộp thư của bạn.',
              ),
              actions: [
                ShadButton.outline(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ShadButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final email = resetController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(
                              () => dialogError = 'Vui lòng nhập email hợp lệ.',
                            );
                            return;
                          }
                          setDialogState(() {
                            isSending = true;
                            dialogError = null;
                          });
                          final error = await context
                              .read<AuthProvider>()
                              .sendPasswordResetEmail(email);
                          if (!ctx.mounted) return;
                          if (error != null) {
                            setDialogState(() {
                              isSending = false;
                              dialogError = error;
                            });
                            return;
                          }
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã gửi email đặt lại mật khẩu tới $email.',
                              ),
                            ),
                          );
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Gửi link đặt lại'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShadInput(
                      controller: resetController,
                      placeholder: const Text('ten@example.com'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      ShadAlert.destructive(
                        icon: const Icon(LucideIcons.circleAlert),
                        title: const Text('Không thể gửi email'),
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
    resetController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final shadTheme = ShadTheme.of(context);
    final errorToShow = _localValidationError ?? auth.errorMessage;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.checkCheck,
                            size: 26,
                            color: shadTheme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Smart Todo',
                            style: shadTheme.textTheme.h4,
                          ),
                        ],
                      ),
                      ShadButton.ghost(
                        onPressed: () => themeProvider.toggleTheme(),
                        child: Icon(
                          themeProvider.isDarkMode
                              ? LucideIcons.sun
                              : LucideIcons.moon,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!auth.isFirebaseReady) ...[
                    const ShadAlert(
                      icon: Icon(LucideIcons.info),
                      title: Text('Chưa kết nối Firebase'),
                      description: Text(
                        'Bạn có thể vào Chế độ xem trước Offline để kiểm tra giao diện & SQLite trước khi gắn google-services.json.',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ShadCard(
                    title: const Text('Đăng nhập'),
                    description: const Text(
                      'Quản lý ghi chú, công việc và lịch trình cá nhân của bạn.',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Email', style: shadTheme.textTheme.small),
                          const SizedBox(height: 6),
                          ShadInput(
                            controller: _emailController,
                            placeholder: const Text('ten@example.com'),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          Text('Mật khẩu', style: shadTheme.textTheme.small),
                          const SizedBox(height: 6),
                          ShadInput(
                            controller: _passwordController,
                            placeholder: const Text('••••••••'),
                            obscureText: _obscurePassword,
                            trailing: GestureDetector(
                              onTap: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              child: Icon(
                                _obscurePassword
                                    ? LucideIcons.eyeOff
                                    : LucideIcons.eye,
                                size: 16,
                              ),
                            ),
                          ),
                          if (errorToShow != null) ...[
                            const SizedBox(height: 12),
                            ShadAlert.destructive(
                              icon: const Icon(LucideIcons.circleAlert),
                              title: const Text('Không thể đăng nhập'),
                              description: Text(errorToShow),
                            ),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: ShadButton.link(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              onPressed: _showForgotPasswordDialog,
                              child: const Text('Quên mật khẩu?'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ShadButton(
                            onPressed: auth.isLoading ? null : _handleLogin,
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Đăng nhập'),
                          ),
                          const SizedBox(height: 10),
                          ShadButton.outline(
                            onPressed: () {
                              auth.clearError();
                              Navigator.pushNamed(context, AppRoutes.register);
                            },
                            child: const Text('Tạo tài khoản mới'),
                          ),
                          if (!auth.isFirebaseReady) ...[
                            const SizedBox(height: 10),
                            ShadButton.secondary(
                              onPressed: () => auth.enterLocalGuestMode(),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Xem trước Offline'),
                              ),
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
      ),
    );
  }
}
