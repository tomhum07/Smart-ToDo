import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../home/main_shell_screen.dart';
import 'login_screen.dart';

/// Cổng kiểm tra phiên đăng nhập tự động qua Firebase Auth authStateChanges().
/// Cache stream trong StatefulWidget để không làm unmount LoginScreen khi AuthProvider notifyListeners.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Stream<User?>? _authStream;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isFirebaseReady) {
      _authStream = authProvider.authStateChanges;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocalGuestMode =
        context.select<AuthProvider, bool>((a) => a.isLocalGuestMode);
    final isFirebaseReady =
        context.select<AuthProvider, bool>((a) => a.isFirebaseReady);

    if (isLocalGuestMode) {
      return const MainShellScreen();
    }

    if (!isFirebaseReady) {
      return const LoginScreen();
    }

    final initialUser = context.read<AuthProvider>().currentUser;
    _authStream ??= context.read<AuthProvider>().authStateChanges;

    return StreamBuilder<User?>(
      stream: _authStream,
      initialData: initialUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            initialUser == null) {
          return const LoginScreen();
        }
        if (snapshot.data != null) {
          return const MainShellScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
