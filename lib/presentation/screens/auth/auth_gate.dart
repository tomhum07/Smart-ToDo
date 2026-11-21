import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../home/main_shell_screen.dart';
import 'login_screen.dart';

/// Cổng kiểm tra phiên đăng nhập tự động qua Firebase Auth authStateChanges().
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isLocalGuestMode) {
      return const MainShellScreen();
    }

    if (!authProvider.isFirebaseReady) {
      return const LoginScreen();
    }

    return StreamBuilder<User?>(
      stream: authProvider.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MainShellScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
