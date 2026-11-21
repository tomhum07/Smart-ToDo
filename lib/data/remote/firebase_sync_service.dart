import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Dịch vụ đồng bộ dữ liệu với Firebase Realtime Database.
/// Phase 1: kiểm thử đọc/ghi hồ sơ người dùng.
/// Phase 3: mở rộng đồng bộ 2 chiều Tasks, Notes, Schedules & Realtime Stream.
class FirebaseSyncService {
  bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  DatabaseReference _userRef(String uid) =>
      FirebaseDatabase.instance.ref('users/$uid');

  /// Lưu thông tin hồ sơ người dùng lên /users/{uid}/profile để xác nhận quyền ghi.
  Future<void> saveUserProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    if (!isFirebaseReady) return;
    await _userRef(uid).child('profile').set({
      'displayName': displayName,
      'email': email,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Đọc thông tin hồ sơ người dùng từ /users/{uid}/profile.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (!isFirebaseReady) return null;
    final snapshot = await _userRef(uid).child('profile').get();
    if (!snapshot.exists || snapshot.value is! Map) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }
}
