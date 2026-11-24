import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/routes/app_routes.dart';
import '../../../providers/auth_provider.dart';

/// Màn hình Đăng ký tài khoản mới qua Firebase Auth.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _localValidationError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty) {
      setState(() => _localValidationError = 'Vui lòng nhập họ tên hiển thị.');
      return;
    }
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
    if (password != confirm) {
      setState(() => _localValidationError = 'Mật khẩu xác nhận không khớp.');
      return;
    }

    setState(() => _localValidationError = null);
    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      email: email,
      password: password,
      displayName: name,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.root,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final shadTheme = ShadTheme.of(context);
    final errorToShow = _localValidationError ?? auth.errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký tài khoản')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ShadCard(
                title: const Text('Tạo tài khoản Smart Todo'),
                description: const Text(
                  'Đồng bộ ghi chú, công việc và lịch trình trên nhiều thiết bị.',
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Họ và tên', style: shadTheme.textTheme.small),
                      const SizedBox(height: 6),
                      ShadInput(
                        controller: _nameController,
                        placeholder: const Text('Nguyễn Văn A'),
                      ),
                      const SizedBox(height: 14),
                      Text('Email', style: shadTheme.textTheme.small),
                      const SizedBox(height: 6),
                      ShadInput(
                        controller: _emailController,
                        placeholder: const Text('sinhvien@dthu.edu.vn'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      Text('Mật khẩu', style: shadTheme.textTheme.small),
                      const SizedBox(height: 6),
                      ShadInput(
                        controller: _passwordController,
                        placeholder: const Text('Ít nhất 6 ký tự'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Xác nhận mật khẩu',
                        style: shadTheme.textTheme.small,
                      ),
                      const SizedBox(height: 6),
                      ShadInput(
                        controller: _confirmController,
                        placeholder: const Text('Nhập lại mật khẩu'),
                        obscureText: true,
                      ),
                      if (errorToShow != null) ...[
                        const SizedBox(height: 12),
                        ShadAlert.destructive(
                          icon: const Icon(LucideIcons.circleAlert),
                          title: const Text('Đăng ký thất bại'),
                          description: Text(errorToShow),
                        ),
                      ],
                      const SizedBox(height: 18),
                      ShadButton(
                        onPressed: auth.isLoading ? null : _handleRegister,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Đăng ký'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
