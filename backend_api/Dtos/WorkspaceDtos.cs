namespace SmartTodo.Api.Dtos;

public record CreateWorkspaceRequest(
    string Name,
    string? Description,
    string OwnerUid,
    string OwnerName,
    string? OwnerEmail
);

public record JoinWorkspaceRequest(
    string InviteCode,
    string UserUid,
    string DisplayName,
    string? Email
);

public record UpsertScheduleRequest(
    string Title,
    int DayOfWeek,
    string? ScheduleDate,
    bool IsRecurring,
    string StartTime,
    string EndTime,
    string? Location,
    string? Note,
    string? ColorHex,
    string? CreatedByName
);

public record UpsertTaskRequest(
    string? ScheduleId,
    string Title,
    string? Description,
    int Priority,
    bool IsCompleted,
    long? DueDate,
    string? AssigneeUid,
    string? AssigneeName
);

public record CreateNoteRequest(
    string? ScheduleDate,
    string Title,
    string? Content,
    string? ColorHex,
    string? AuthorName
);

public record WorkspaceSummaryDto(
    string Id,
    string Name,
    string Description,
    string InviteCode,
    string OwnerUid,
    string OwnerName,
    int MemberCount,
    long CreatedAt
);

public record WorkspaceMemberDto(
    string Id,
    string UserUid,
    string DisplayName,
    string Email,
    string Role,
    long JoinedAt
);

public record WorkspaceScheduleDto(
    string Id,
    string WorkspaceId,
    string Title,
    int DayOfWeek,
    string? ScheduleDate,
    bool IsRecurring,
    string StartTime,
    string EndTime,
    string Location,
    string Note,
    string ColorHex,
    string CreatedByName,
    long UpdatedAt
);

public record WorkspaceTaskDto(
    string Id,
    string WorkspaceId,
    string? ScheduleId,
    string Title,
    string Description,
    int Priority,
    bool IsCompleted,
    long? DueDate,
    string? AssigneeUid,
    string? AssigneeName,
    long UpdatedAt
);

public record WorkspaceNoteDto(
    string Id,
    string WorkspaceId,
    string? ScheduleDate,
    string Title,
    string Content,
    string ColorHex,
    string AuthorName,
    long UpdatedAt
);

public record WorkspaceOverviewDto(
    WorkspaceSummaryDto Workspace,
    List<WorkspaceMemberDto> Members,
    List<WorkspaceScheduleDto> Schedules,
    List<WorkspaceTaskDto> Tasks,
    List<WorkspaceNoteDto> Notes
);
