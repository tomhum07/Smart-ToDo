import 'schedule_model.dart';

/// Thông tin tóm tắt 1 Không gian Chia sẻ Nhóm (Shared Workspace).
class WorkspaceSummary {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final String ownerUid;
  final String ownerName;
  final int memberCount;
  final int createdAt;

  const WorkspaceSummary({
    required this.id,
    required this.name,
    this.description = '',
    required this.inviteCode,
    required this.ownerUid,
    required this.ownerName,
    this.memberCount = 1,
    required this.createdAt,
  });

  factory WorkspaceSummary.fromJson(Map<String, dynamic> json) {
    return WorkspaceSummary(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      inviteCode: (json['inviteCode'] as String?) ?? '',
      ownerUid: (json['ownerUid'] as String?) ?? '',
      ownerName: (json['ownerName'] as String?) ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkspaceMember {
  final String id;
  final String userUid;
  final String displayName;
  final String email;
  final String role; // Owner | Member
  final int joinedAt;

  const WorkspaceMember({
    required this.id,
    required this.userUid,
    required this.displayName,
    this.email = '',
    this.role = 'Member',
    required this.joinedAt,
  });

  factory WorkspaceMember.fromJson(Map<String, dynamic> json) {
    return WorkspaceMember(
      id: (json['id'] as String?) ?? '',
      userUid: (json['userUid'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'Member',
      joinedAt: (json['joinedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkspaceSchedule {
  final String id;
  final String workspaceId;
  final String title;
  final int dayOfWeek;
  final String? scheduleDate;
  final bool isRecurring;
  final String startTime;
  final String endTime;
  final String location;
  final String note;
  final String colorHex;
  final String createdByName;
  final int updatedAt;

  const WorkspaceSchedule({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.dayOfWeek,
    this.scheduleDate,
    this.isRecurring = false,
    required this.startTime,
    required this.endTime,
    this.location = '',
    this.note = '',
    this.colorHex = '#DBEAFE',
    this.createdByName = '',
    required this.updatedAt,
  });

  bool occursOnDate(DateTime date) {
    if (isRecurring) return dayOfWeek == date.weekday;
    if (scheduleDate != null && scheduleDate!.isNotEmpty) {
      return scheduleDate == ScheduleModel.formatIsoDate(date);
    }
    return dayOfWeek == date.weekday;
  }

  factory WorkspaceSchedule.fromJson(Map<String, dynamic> json) {
    return WorkspaceSchedule(
      id: (json['id'] as String?) ?? '',
      workspaceId: (json['workspaceId'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 1,
      scheduleDate: json['scheduleDate'] as String?,
      isRecurring: (json['isRecurring'] as bool?) ?? false,
      startTime: (json['startTime'] as String?) ?? '07:30',
      endTime: (json['endTime'] as String?) ?? '09:30',
      location: (json['location'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
      colorHex: (json['colorHex'] as String?) ?? '#DBEAFE',
      createdByName: (json['createdByName'] as String?) ?? '',
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkspaceTask {
  final String id;
  final String workspaceId;
  final String? scheduleId;
  final String title;
  final String description;
  final int priority;
  final bool isCompleted;
  final int? dueDate;
  final String? assigneeUid;
  final String? assigneeName;
  final int updatedAt;

  const WorkspaceTask({
    required this.id,
    required this.workspaceId,
    this.scheduleId,
    required this.title,
    this.description = '',
    this.priority = 1,
    this.isCompleted = false,
    this.dueDate,
    this.assigneeUid,
    this.assigneeName,
    required this.updatedAt,
  });

  factory WorkspaceTask.fromJson(Map<String, dynamic> json) {
    return WorkspaceTask(
      id: (json['id'] as String?) ?? '',
      workspaceId: (json['workspaceId'] as String?) ?? '',
      scheduleId: json['scheduleId'] as String?,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      isCompleted: (json['isCompleted'] as bool?) ?? false,
      dueDate: (json['dueDate'] as num?)?.toInt(),
      assigneeUid: json['assigneeUid'] as String?,
      assigneeName: json['assigneeName'] as String?,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkspaceNote {
  final String id;
  final String workspaceId;
  final String? scheduleDate;
  final String title;
  final String content;
  final String colorHex;
  final String authorName;
  final int updatedAt;

  const WorkspaceNote({
    required this.id,
    required this.workspaceId,
    this.scheduleDate,
    required this.title,
    this.content = '',
    this.colorHex = '#FEF3C7',
    this.authorName = '',
    required this.updatedAt,
  });

  factory WorkspaceNote.fromJson(Map<String, dynamic> json) {
    return WorkspaceNote(
      id: (json['id'] as String?) ?? '',
      workspaceId: (json['workspaceId'] as String?) ?? '',
      scheduleDate: json['scheduleDate'] as String?,
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      colorHex: (json['colorHex'] as String?) ?? '#FEF3C7',
      authorName: (json['authorName'] as String?) ?? '',
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkspaceOverview {
  final WorkspaceSummary workspace;
  final List<WorkspaceMember> members;
  final List<WorkspaceSchedule> schedules;
  final List<WorkspaceTask> tasks;
  final List<WorkspaceNote> notes;

  const WorkspaceOverview({
    required this.workspace,
    required this.members,
    required this.schedules,
    required this.tasks,
    required this.notes,
  });

  factory WorkspaceOverview.fromJson(Map<String, dynamic> json) {
    return WorkspaceOverview(
      workspace: WorkspaceSummary.fromJson(
        json['workspace'] as Map<String, dynamic>,
      ),
      members: ((json['members'] as List?) ?? [])
          .map((e) => WorkspaceMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      schedules: ((json['schedules'] as List?) ?? [])
          .map((e) => WorkspaceSchedule.fromJson(e as Map<String, dynamic>))
          .toList(),
      tasks: ((json['tasks'] as List?) ?? [])
          .map((e) => WorkspaceTask.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: ((json['notes'] as List?) ?? [])
          .map((e) => WorkspaceNote.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
