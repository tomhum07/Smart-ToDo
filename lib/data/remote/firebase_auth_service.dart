import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Dịch vụ xác thực người dùng qua Firebase Authentication (Email/Password, Quên & Đổi mật khẩu).
class FirebaseAuthService {
  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? get currentUser => isFirebaseReady ? _auth.currentUser : null;

  Stream<User?> get authStateChanges {
    if (!isFirebaseReady) {
      return Stream<User?>.value(null);
    }
    return _auth.authStateChanges();
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureReady();
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapErrorCode(e.code));
    }
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _ensureReady();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.reload();
      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapErrorCode(e.code));
    }
  }

  /// Gửi email chứa link đặt lại mật khẩu cho người dùng (Quên mật khẩu).
  Future<void> sendPasswordResetEmail(String email) async {
    _ensureReady();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapErrorCode(e.code));
    }
  }

  /// Đổi mật khẩu sau khi xác thực lại mật khẩu hiện tại (Re-authenticate).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _ensureReady();
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Bạn chưa đăng nhập tài khoản Firebase.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapErrorCode(e.code));
    }
  }

  Future<void> signOut() async {
    if (!isFirebaseReady) return;
    await _auth.signOut();
  }

  void _ensureReady() {
    if (!isFirebaseReady) {
      throw Exception(
        'Firebase chưa được cấu hình. Hãy thêm google-services.json vào android/app/.',
      );
    }
  }

  String _mapErrorCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Địa chỉ email không hợp lệ.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký trước đó.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (cần ít nhất 6 ký tự).';
      case 'requires-recent-login':
        return 'Phiên đăng nhập đã cũ. Vui lòng đăng xuất và đăng nhập lại.';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.';
      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng kiểm tra Wi-Fi/4G.';
      default:
        return 'Lỗi xác thực Firebase ($code).';
    }
  }
}
