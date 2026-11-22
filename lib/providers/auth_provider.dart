import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/remote/firebase_auth_service.dart';
import '../data/remote/firebase_sync_service.dart';

/// Quản lý trạng thái xác thực người dùng (Đăng nhập, Đăng ký, Quên/Đổi mật khẩu).
class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService;
  final FirebaseSyncService _syncService;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isLocalGuestMode = false;

  AuthProvider({
    FirebaseAuthService? authService,
    FirebaseSyncService? syncService,
  })  : _authService = authService ?? FirebaseAuthService(),
        _syncService = syncService ?? FirebaseSyncService.instance;

  bool get isFirebaseReady => _authService.isFirebaseReady;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLocalGuestMode => _isLocalGuestMode;

  User? get currentUser => _authService.currentUser;
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  /// ID người dùng hiện tại dùng để truy vấn SQLite & Firebase Realtime DB.
  String get effectiveUserId => currentUser?.uid ?? 'local_guest_user';

  String get displayName {
    final name = currentUser?.displayName;
    if (name != null && name.trim().isNotEmpty) return name;
    if (currentUser?.email != null) return currentUser!.email!.split('@').first;
    return 'Khách (Offline Preview)';
  }

  String get email => currentUser?.email ?? 'Chưa kết nối Firebase Auth';

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Cho phép vào giao diện chính ở chế độ cục bộ khi chưa setup Firebase.
  void enterLocalGuestMode() {
    _isLocalGuestMode = true;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _syncService.saveUserProfile(
          uid: user.uid,
          email: user.email ?? email,
          displayName: user.displayName ?? email.split('@').first,
        );
      }
      _isLocalGuestMode = false;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading(true);
    try {
      final credential = await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      final user = credential.user;
      if (user != null) {
        await _syncService.saveUserProfile(
          uid: user.uid,
          email: user.email ?? email,
          displayName: displayName,
        );
      }
      _isLocalGuestMode = false;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Gửi email đặt lại mật khẩu. Trả về null nếu thành công, hoặc thông báo lỗi.
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Đổi mật khẩu tài khoản hiện tại. Trả về null nếu thành công, hoặc thông báo lỗi.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> signOut() async {
    _isLocalGuestMode = false;
    await _authService.signOut();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (value) _errorMessage = null;
    notifyListeners();
  }
}
