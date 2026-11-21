/// Model Thời khóa biểu / Lịch trình hằng ngày (Thứ 2 -> Chủ nhật).
class ScheduleModel {
  final String id;
  final String userId;
  final String title;
  final int dayOfWeek; // 1 (Thứ 2) -> 7 (Chủ nhật)
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String location;
  final String note;
  final String colorHex;
  final int updatedAt;
  final bool isDeleted;
  final bool isSynced;

  const ScheduleModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.location = '',
    this.note = '',
    this.colorHex = '#DBEAFE',
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  ScheduleModel copyWith({
    String? id,
    String? userId,
    String? title,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? location,
    String? note,
    String? colorHex,
    int? updatedAt,
    bool? isDeleted,
    bool? isSynced,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      note: note ?? this.note,
      colorHex: colorHex ?? this.colorHex,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'location': location,
      'note': note,
      'color_hex': colorHex,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      dayOfWeek: (map['day_of_week'] as int?) ?? 1,
      startTime: (map['start_time'] as String?) ?? '07:00',
      endTime: (map['end_time'] as String?) ?? '09:00',
      location: (map['location'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      colorHex: (map['color_hex'] as String?) ?? '#DBEAFE',
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
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'note': note,
      'colorHex': colorHex,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
    };
  }

  factory ScheduleModel.fromJson(
    Map<String, dynamic> json, {
    String? idOverride,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ScheduleModel(
      id: idOverride ?? (json['id'] as String? ?? ''),
      userId: (json['userId'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      startTime: (json['startTime'] as String?) ?? '07:00',
      endTime: (json['endTime'] as String?) ?? '09:00',
      location: (json['location'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      colorHex: (json['colorHex'] as String?) ?? '#DBEAFE',
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? now,
      isDeleted: (json['isDeleted'] as bool?) ?? false,
      isSynced: true,
    );
  }
}
