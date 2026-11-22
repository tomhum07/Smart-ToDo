/// Model Công việc (Todo) hỗ trợ lưu trữ SQLite cục bộ, nhắc lại nhiều lần & đồng bộ Firebase.
class TaskModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final int priority; // 0: Low, 1: Medium, 2: High
  final bool isCompleted;
  final int? dueDate; // epoch milliseconds
  final int remindBeforeMinutes; // 0 = không nhắc
  final int repeatIntervalSeconds; // khoảng thời gian giữa các lần nhắc lại (30s, 60s, ...)
  final int repeatCount; // tổng số lần nhắc (1, 2, 3, 4, ...)
  final int createdAt;
  final int updatedAt;
  final bool isDeleted;
  final bool isSynced;

  const TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.category = 'Học tập',
    this.priority = 1,
    this.isCompleted = false,
    this.dueDate,
    this.remindBeforeMinutes = 10,
    this.repeatIntervalSeconds = 60,
    this.repeatCount = 1,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  TaskModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? category,
    int? priority,
    bool? isCompleted,
    int? dueDate,
    bool clearDueDate = false,
    int? remindBeforeMinutes,
    int? repeatIntervalSeconds,
    int? repeatCount,
    int? createdAt,
    int? updatedAt,
    bool? isDeleted,
    bool? isSynced,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      remindBeforeMinutes: remindBeforeMinutes ?? this.remindBeforeMinutes,
      repeatIntervalSeconds:
          repeatIntervalSeconds ?? this.repeatIntervalSeconds,
      repeatCount: repeatCount ?? this.repeatCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Chuyển đổi sang Map để lưu vào SQLite (sqflite).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'is_completed': isCompleted ? 1 : 0,
      'due_date': dueDate,
      'remind_before_minutes': remindBeforeMinutes,
      'repeat_interval_seconds': repeatIntervalSeconds,
      'repeat_count': repeatCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Khởi tạo từ dòng dữ liệu SQLite.
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Học tập',
      priority: (map['priority'] as int?) ?? 1,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      dueDate: map['due_date'] as int?,
      remindBeforeMinutes: (map['remind_before_minutes'] as int?) ?? 10,
      repeatIntervalSeconds: (map['repeat_interval_seconds'] as int?) ?? 60,
      repeatCount: (map['repeat_count'] as int?) ?? 1,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }

  /// Chuyển đổi sang JSON cho Firebase Realtime DB / REST API.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'isCompleted': isCompleted,
      'dueDate': dueDate,
      'remindBeforeMinutes': remindBeforeMinutes,
      'repeatIntervalSeconds': repeatIntervalSeconds,
      'repeatCount': repeatCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
    };
  }

  /// Khởi tạo từ JSON của Firebase Realtime DB / REST API.
  factory TaskModel.fromJson(Map<String, dynamic> json, {String? idOverride}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return TaskModel(
      id: idOverride ?? (json['id'] as String? ?? ''),
      userId: (json['userId'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'Học tập',
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      dueDate: (json['dueDate'] as num?)?.toInt(),
      remindBeforeMinutes: (json['remindBeforeMinutes'] as num?)?.toInt() ?? 10,
      repeatIntervalSeconds:
          (json['repeatIntervalSeconds'] as num?)?.toInt() ?? 60,
      repeatCount: (json['repeatCount'] as num?)?.toInt() ?? 1,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? now,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? now,
      isDeleted: (json['isDeleted'] as bool?) ?? false,
      isSynced: true,
    );
  }
}
