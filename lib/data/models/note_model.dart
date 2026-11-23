import 'dart:convert';

/// Model Ghi chú đa phương tiện hỗ trợ NHIỀU ảnh cục bộ & Cloud (Supabase Storage).
class NoteModel {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String colorHex;
  final int priority; // 0: Low, 1: Medium, 2: High
  final String category;
  final List<String> localImagePaths;
  final List<String> remoteImageUrls;
  final int createdAt;
  final int updatedAt;
  final bool isDeleted;
  final bool isSynced;

  const NoteModel({
    required this.id,
    required this.userId,
    required this.title,
    this.content = '',
    this.colorHex = '#FFFFFF',
    this.priority = 1,
    this.category = 'Học tập',
    this.localImagePaths = const [],
    this.remoteImageUrls = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  bool get hasImages =>
      localImagePaths.isNotEmpty || remoteImageUrls.isNotEmpty;

  int get totalImages => localImagePaths.isNotEmpty
      ? localImagePaths.length
      : remoteImageUrls.length;

  NoteModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? colorHex,
    int? priority,
    String? category,
    List<String>? localImagePaths,
    List<String>? remoteImageUrls,
    int? createdAt,
    int? updatedAt,
    bool? isDeleted,
    bool? isSynced,
  }) {
    return NoteModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      colorHex: colorHex ?? this.colorHex,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      remoteImageUrls: remoteImageUrls ?? this.remoteImageUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Giải mã linh hoạt cả dạng mảng JSON mới lẫn chuỗi đơn cũ trong SQLite.
  static List<String> _decodeStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return const [];
    if (str.startsWith('[')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return [str];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'color_hex': colorHex,
      'priority': priority,
      'category': category,
      'local_image_path':
          localImagePaths.isEmpty ? null : jsonEncode(localImagePaths),
      'remote_image_url':
          remoteImageUrls.isEmpty ? null : jsonEncode(remoteImageUrls),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      content: (map['content'] as String?) ?? '',
      colorHex: (map['color_hex'] as String?) ?? '#FFFFFF',
      priority: (map['priority'] as int?) ?? 1,
      category: (map['category'] as String?) ?? 'Học tập',
      localImagePaths: _decodeStringList(map['local_image_path']),
      remoteImageUrls: _decodeStringList(map['remote_image_url']),
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'content': content,
      'colorHex': colorHex,
      'priority': priority,
      'category': category,
      'remoteImageUrls': remoteImageUrls,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
    };
  }

  factory NoteModel.fromJson(Map<String, dynamic> json, {String? idOverride}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return NoteModel(
      id: idOverride ?? (json['id'] as String? ?? ''),
      userId: (json['userId'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      colorHex: (json['colorHex'] as String?) ?? '#FFFFFF',
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      category: (json['category'] as String?) ?? 'Học tập',
      remoteImageUrls: _decodeStringList(
        json['remoteImageUrls'] ?? json['remoteImageUrl'],
      ),
      createdAt: (json['createdAt'] as num?)?.toInt() ?? now,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? now,
      isDeleted: (json['isDeleted'] as bool?) ?? false,
      isSynced: true,
    );
  }
}
