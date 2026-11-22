import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/api_constants.dart';
import '../data/local/database_helper.dart';
import '../data/models/note_model.dart';
import '../data/remote/firebase_sync_service.dart';
import '../data/remote/supabase_storage_service.dart';

/// Quản lý trạng thái, tìm kiếm, lọc và CRUD Ghi chú đa phương tiện (hỗ trợ nhiều ảnh).
class NoteProvider extends ChangeNotifier {
  final DatabaseHelper _db;
  final SupabaseStorageService _storage;
  final Uuid _uuid = const Uuid();

  List<NoteModel> _notes = [];
  bool _isLoading = false;
  String? _loadedUserId;

  String _searchQuery = '';
  String _selectedCategory = 'Tất cả';
  int? _selectedPriority;

  NoteProvider({
    DatabaseHelper? db,
    SupabaseStorageService? storage,
  })  : _db = db ?? DatabaseHelper.instance,
        _storage = storage ?? SupabaseStorageService();

  bool get isLoading => _isLoading;
  List<NoteModel> get allNotes => List.unmodifiable(_notes);
  int get totalCount => _notes.length;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  int? get selectedPriority => _selectedPriority;

  int get activeFilterCount {
    var count = 0;
    if (_selectedCategory != 'Tất cả') count++;
    if (_selectedPriority != null) count++;
    return count;
  }

  List<NoteModel> get filteredNotes {
    final query = _searchQuery.trim().toLowerCase();
    return _notes.where((note) {
      if (query.isNotEmpty) {
        final matchTitle = note.title.toLowerCase().contains(query);
        final matchContent = note.content.toLowerCase().contains(query);
        if (!matchTitle && !matchContent) return false;
      }
      if (_selectedCategory != 'Tất cả' && note.category != _selectedCategory) {
        return false;
      }
      if (_selectedPriority != null && note.priority != _selectedPriority) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> loadNotes(String userId, {bool force = false}) async {
    if (!force && _loadedUserId == userId) return;
    _isLoading = true;
    _loadedUserId = userId;
    notifyListeners();

    try {
      _notes = await _db.getNotesByUser(userId);
    } catch (e) {
      debugPrint('Lỗi tải danh sách ghi chú: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setPriority(int? priority) {
    _selectedPriority = priority;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = 'Tất cả';
    _selectedPriority = null;
    notifyListeners();
  }

  Future<void> saveNote({
    NoteModel? existing,
    required String userId,
    required String title,
    required String content,
    required String colorHex,
    required int priority,
    required String category,
    required List<String> localImagePaths,
    required List<String> remoteImageUrls,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final noteId = existing?.id ?? _uuid.v4();

    final finalRemoteUrls = List<String>.from(remoteImageUrls);

    // Tự động upload các ảnh cục bộ mới thêm lên Supabase Storage nếu đã cấu hình key
    if (ApiConstants.isSupabaseConfigured) {
      final existingPaths = existing?.localImagePaths.toSet() ?? <String>{};
      for (var i = 0; i < localImagePaths.length; i++) {
        final path = localImagePaths[i];
        if (existingPaths.contains(path)) continue;
        try {
          final file = File(path);
          if (await file.exists()) {
            final url = await _storage.uploadNoteImage(
              imageFile: file,
              userId: userId,
              noteId: '${noteId}_${now}_$i',
            );
            finalRemoteUrls.add(url);
          }
        } catch (e) {
          debugPrint('Tạm lưu ảnh cục bộ (Supabase chưa sẵn sàng): $e');
        }
      }
    }

    final note = NoteModel(
      id: noteId,
      userId: userId,
      title: title.trim(),
      content: content.trim(),
      colorHex: colorHex,
      priority: priority,
      category: category,
      localImagePaths: List<String>.from(localImagePaths),
      remoteImageUrls: finalRemoteUrls,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isDeleted: false,
      isSynced: false,
    );

    await _db.upsertNote(note);
    await loadNotes(userId, force: true);
    _syncInBackground(userId);
  }

  Future<void> deleteNote(NoteModel note) async {
    await _db.softDeleteNote(note.id);
    await loadNotes(note.userId, force: true);
    _syncInBackground(note.userId);
  }

  void _syncInBackground(String userId) {
    FirebaseSyncService.instance.pushUnsyncedData(userId).catchError((Object e) {
      debugPrint('Đồng bộ ngầm Note tạm hoãn (offline): $e');
      return 0;
    });
  }
}
