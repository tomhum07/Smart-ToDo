using System.ComponentModel.DataAnnotations;

namespace SmartTodo.Api.Models;

/// <summary>
/// Không gian chia sẻ nhóm (Shared Workspace) có mã mời 6 ký tự.
/// </summary>
public class Workspace
{
    [Key]
    [MaxLength(64)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required, MaxLength(120)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(500)]
    public string Description { get; set; } = string.Empty;

    [Required, MaxLength(12)]
    public string InviteCode { get; set; } = string.Empty;

    [Required, MaxLength(128)]
    public string OwnerUid { get; set; } = string.Empty;

    [Required, MaxLength(120)]
    public string OwnerName { get; set; } = string.Empty;

    public long CreatedAt { get; set; } = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

    public List<WorkspaceMember> Members { get; set; } = [];
    public List<WorkspaceSchedule> Schedules { get; set; } = [];
    public List<WorkspaceTask> Tasks { get; set; } = [];
    public List<WorkspaceNote> Notes { get; set; } = [];
}

/// <summary>
/// Thành viên trong Workspace (Owner / Member).
/// </summary>
public class WorkspaceMember
{
    [Key]
    [MaxLength(64)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required, MaxLength(64)]
    public string WorkspaceId { get; set; } = string.Empty;
    public Workspace? Workspace { get; set; }

    [Required, MaxLength(128)]
    public string UserUid { get; set; } = string.Empty;

    [Required, MaxLength(120)]
    public string DisplayName { get; set; } = string.Empty;

    [MaxLength(200)]
    public string Email { get; set; } = string.Empty;

    [MaxLength(20)]
    public string Role { get; set; } = "Member"; // Owner | Member

    public long JoinedAt { get; set; } = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
}

/// <summary>
/// Mục lớn / Thời khóa biểu chung trong Workspace (hỗ trợ ngày cụ thể & lặp tuần).
/// </summary>
public class WorkspaceSchedule
{
    [Key]
    [MaxLength(64)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required, MaxLength(64)]
    public string WorkspaceId { get; set; } = string.Empty;
    public Workspace? Workspace { get; set; }

    [Required, MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    public int DayOfWeek { get; set; } = 1; // 1 = Thứ 2 -> 7 = Chủ nhật

    [MaxLength(16)]
    public string? ScheduleDate { get; set; } // yyyy-MM-dd

    public bool IsRecurring { get; set; } = false;

    [Required, MaxLength(10)]
    public string StartTime { get; set; } = "07:30";

    [Required, MaxLength(10)]
    public string EndTime { get; set; } = "09:30";

    [MaxLength(200)]
    public string Location { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string Note { get; set; } = string.Empty;

    [MaxLength(16)]
    public string ColorHex { get; set; } = "#DBEAFE";

    [MaxLength(120)]
    public string CreatedByName { get; set; } = string.Empty;

    public long UpdatedAt { get; set; } = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

    public List<WorkspaceTask> Tasks { get; set; } = [];
}

/// <summary>
/// Công việc nhỏ trong Workspace (gắn vào Mục lớn hoặc Việc lẻ) có phân công thành viên.
/// </summary>
public class WorkspaceTask
{
    [Key]
    [MaxLength(64)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required, MaxLength(64)]
    public string WorkspaceId { get; set; } = string.Empty;
    public Workspace? Workspace { get; set; }

    [MaxLength(64)]
    public string? ScheduleId { get; set; }
    public WorkspaceSchedule? Schedule { get; set; }

    [Required, MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string Description { get; set; } = string.Empty;

    public int Priority { get; set; } = 1; // 0: Low, 1: Medium, 2: High
    public bool IsCompleted { get; set; } = false;
    public long? DueDate { get; set; }

    [MaxLength(128)]
    public string? AssigneeUid { get; set; }

    [MaxLength(120)]
    public string? AssigneeName { get; set; }

    public long UpdatedAt { get; set; } = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
}

/// <summary>
/// Ghi chú chung theo ngày trong Workspace.
/// </summary>
public class WorkspaceNote
{
    [Key]
    [MaxLength(64)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required, MaxLength(64)]
    public string WorkspaceId { get; set; } = string.Empty;
    public Workspace? Workspace { get; set; }

    [MaxLength(16)]
    public string? ScheduleDate { get; set; } // yyyy-MM-dd

    [Required, MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(4000)]
    public string Content { get; set; } = string.Empty;

    [MaxLength(16)]
    public string ColorHex { get; set; } = "#FEF3C7";

    [MaxLength(120)]
    public string AuthorName { get; set; } = string.Empty;

    public long UpdatedAt { get; set; } = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
}
