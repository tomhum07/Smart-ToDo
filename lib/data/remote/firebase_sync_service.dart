import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../local/database_helper.dart';
import '../models/note_model.dart';
import '../models/schedule_model.dart';
import '../models/task_model.dart';

/// Dịch vụ đồng bộ 2 chiều Offline-first giữa SQLite (sqflite) và Firebase Realtime Database.
class FirebaseSyncService {
  FirebaseSyncService._();

  static final FirebaseSyncService instance = FirebaseSyncService._();

  final DatabaseHelper _db = DatabaseHelper.instance;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;

  bool get isFirebaseReady => Firebase.apps.isNotEmpty;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  DatabaseReference _userRef(String uid) =>
      FirebaseDatabase.instance.ref('users/$uid');

  /// Lưu thông tin hồ sơ người dùng lên /users/{uid}/profile.
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

  /// Đẩy toàn bộ các bản ghi chưa đồng bộ (is_synced = 0) từ SQLite lên Firebase Realtime DB.
  Future<int> pushUnsyncedData(String uid) async {
    if (!isFirebaseReady || uid == 'local_guest_user') return 0;

    var pushedCount = 0;

    final unsyncedTasks = await _db.getUnsyncedTasks(uid);
    for (final task in unsyncedTasks) {
      await _userRef(uid).child('tasks/${task.id}').set(task.toJson());
      await _db.markTaskSynced(task.id);
      pushedCount++;
    }

    final unsyncedNotes = await _db.getUnsyncedNotes(uid);
    for (final note in unsyncedNotes) {
      await _userRef(uid).child('notes/${note.id}').set(note.toJson());
      await _db.markNoteSynced(note.id);
      pushedCount++;
    }

    final unsyncedSchedules = await _db.getUnsyncedSchedules(uid);
    for (final schedule in unsyncedSchedules) {
      await _userRef(uid)
          .child('schedules/${schedule.id}')
          .set(schedule.toJson());
      await _db.markScheduleSynced(schedule.id);
      pushedCount++;
    }

    if (pushedCount > 0) {
      _lastSyncedAt = DateTime.now();
    }
    return pushedCount;
  }

  /// Kéo dữ liệu từ Firebase Realtime DB và gộp vào SQLite theo nguyên tắc Last-Write-Wins.
  Future<bool> pullAndMergeFromCloud(String uid) async {
    if (!isFirebaseReady || uid == 'local_guest_user') return false;

    final snapshot = await _userRef(uid).get();
    if (!snapshot.exists || snapshot.value is! Map) {
      _lastSyncedAt = DateTime.now();
      return false;
    }

    final rootMap = Map<String, dynamic>.from(snapshot.value as Map);
    final changed = await _mergeSnapshotMap(uid, rootMap);
    _lastSyncedAt = DateTime.now();
    return changed;
  }

  /// Thực hiện đồng bộ 2 chiều đầy đủ (Push trước, Pull & Merge sau).
  Future<bool> syncAll(String uid) async {
    if (!isFirebaseReady || uid == 'local_guest_user' || _isSyncing) {
      return false;
    }

    _isSyncing = true;
    try {
      await pushUnsyncedData(uid);
      final changed = await pullAndMergeFromCloud(uid);
      return changed;
    } catch (e) {
      debugPrint('Lỗi đồng bộ 2 chiều Firebase: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Lắng nghe thay đổi thời gian thực từ Firebase Realtime DB để cập nhật máy cục bộ.
  StreamSubscription<DatabaseEvent>? listenRealtimeUpdates(
    String uid,
    Future<void> Function() onDataMerged,
  ) {
    if (!isFirebaseReady || uid == 'local_guest_user') return null;

    return _userRef(uid).onValue.listen(
      (event) async {
        final raw = event.snapshot.value;
        if (raw is! Map) return;
        try {
          final rootMap = Map<String, dynamic>.from(raw);
          final changed = await _mergeSnapshotMap(uid, rootMap);
          _lastSyncedAt = DateTime.now();
          if (changed) {
            await onDataMerged();
          }
        } catch (e) {
          debugPrint('Lỗi xử lý realtime snapshot Firebase: $e');
        }
      },
      onError: (Object error) {
        debugPrint('Lỗi lắng nghe Realtime DB: $error');
      },
    );
  }

  Future<bool> _mergeSnapshotMap(
    String uid,
    Map<String, dynamic> rootMap,
  ) async {
    var hasChanges = false;

    // 1. Merge Tasks
    final rawTasks = rootMap['tasks'];
    if (rawTasks is Map) {
      for (final entry in rawTasks.entries) {
        if (entry.value is! Map) continue;
        final remote = TaskModel.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
          idOverride: entry.key.toString(),
        ).copyWith(userId: uid, isSynced: true);

        final local = await _db.getTaskById(remote.id);
        if (local == null || remote.updatedAt > local.updatedAt) {
          await _db.upsertTask(remote);
          hasChanges = true;
        }
      }
    }

    // 2. Merge Notes (giữ lại localImagePaths nếu máy này đã có ảnh cục bộ)
    final rawNotes = rootMap['notes'];
    if (rawNotes is Map) {
      for (final entry in rawNotes.entries) {
        if (entry.value is! Map) continue;
        final remote = NoteModel.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
          idOverride: entry.key.toString(),
        ).copyWith(userId: uid, isSynced: true);

        final local = await _db.getNoteById(remote.id);
        if (local == null || remote.updatedAt > local.updatedAt) {
          final mergedNote = local != null && local.localImagePaths.isNotEmpty
              ? remote.copyWith(localImagePaths: local.localImagePaths)
              : remote;
          await _db.upsertNote(mergedNote);
          hasChanges = true;
        }
      }
    }

    // 3. Merge Schedules
    final rawSchedules = rootMap['schedules'];
    if (rawSchedules is Map) {
      for (final entry in rawSchedules.entries) {
        if (entry.value is! Map) continue;
        final remote = ScheduleModel.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
          idOverride: entry.key.toString(),
        ).copyWith(userId: uid, isSynced: true);

        final local = await _db.getScheduleById(remote.id);
        if (local == null || remote.updatedAt > local.updatedAt) {
          await _db.upsertSchedule(remote);
          hasChanges = true;
        }
      }
    }

    return hasChanges;
  }
}
