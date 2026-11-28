using System.Security.Cryptography;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartTodo.Api.Data;
using SmartTodo.Api.Dtos;
using SmartTodo.Api.Models;

namespace SmartTodo.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class WorkspacesController(AppDbContext db) : ControllerBase
{
    private const string InviteAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    /// <summary>
    /// Lấy danh sách tất cả Workspace mà người dùng đã tham gia.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<WorkspaceSummaryDto>>> GetMyWorkspaces(
        [FromQuery] string userUid)
    {
        if (string.IsNullOrWhiteSpace(userUid))
            return BadRequest(new { message = "Thiếu userUid." });

        var workspaces = await db.Workspaces
            .Include(w => w.Members)
            .Where(w => w.Members.Any(m => m.UserUid == userUid))
            .OrderByDescending(w => w.CreatedAt)
            .ToListAsync();

        return Ok(workspaces.Select(ToSummary).ToList());
    }

    /// <summary>
    /// Tạo mới một Không gian Chia sẻ Nhóm và sinh mã mời 6 ký tự.
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<WorkspaceSummaryDto>> CreateWorkspace(
        [FromBody] CreateWorkspaceRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name) ||
            string.IsNullOrWhiteSpace(request.OwnerUid))
        {
            return BadRequest(new { message = "Vui lòng nhập tên Workspace và thông tin chủ sở hữu." });
        }

        var code = await GenerateUniqueInviteCodeAsync();
        var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

        var workspace = new Workspace
        {
            Name = request.Name.Trim(),
            Description = (request.Description ?? string.Empty).Trim(),
            InviteCode = code,
            OwnerUid = request.OwnerUid.Trim(),
            OwnerName = string.IsNullOrWhiteSpace(request.OwnerName)
                ? "Chủ nhóm"
                : request.OwnerName.Trim(),
            CreatedAt = now
        };

        workspace.Members.Add(new WorkspaceMember
        {
            WorkspaceId = workspace.Id,
            UserUid = workspace.OwnerUid,
            DisplayName = workspace.OwnerName,
            Email = (request.OwnerEmail ?? string.Empty).Trim(),
            Role = "Owner",
            JoinedAt = now
        });

        db.Workspaces.Add(workspace);
        await db.SaveChangesAsync();

        return CreatedAtAction(
            nameof(GetOverview),
            new { id = workspace.Id },
            ToSummary(workspace));
    }

    /// <summary>
    /// Tham gia Không gian Nhóm bằng mã mời 6 ký tự.
    /// </summary>
    [HttpPost("join")]
    public async Task<ActionResult<WorkspaceSummaryDto>> JoinByCode(
        [FromBody] JoinWorkspaceRequest request)
    {
        var code = (request.InviteCode ?? string.Empty).Trim().ToUpperInvariant();
        if (code.Length < 4 || string.IsNullOrWhiteSpace(request.UserUid))
            return BadRequest(new { message = "Mã mời không hợp lệ." });

        var workspace = await db.Workspaces
            .Include(w => w.Members)
            .FirstOrDefaultAsync(w => w.InviteCode == code);

        if (workspace is null)
            return NotFound(new { message = $"Không tìm thấy Workspace với mã \"{code}\"." });

        var alreadyMember = workspace.Members.Any(m => m.UserUid == request.UserUid);
        if (!alreadyMember)
        {
            db.WorkspaceMembers.Add(new WorkspaceMember
            {
                WorkspaceId = workspace.Id,
                UserUid = request.UserUid.Trim(),
                DisplayName = string.IsNullOrWhiteSpace(request.DisplayName)
                    ? "Thành viên"
                    : request.DisplayName.Trim(),
                Email = (request.Email ?? string.Empty).Trim(),
                Role = "Member",
                JoinedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
            });
            await db.SaveChangesAsync();
            workspace = await db.Workspaces
                .Include(w => w.Members)
                .FirstAsync(w => w.Id == workspace.Id);
        }

        return Ok(ToSummary(workspace));
    }

    /// <summary>
    /// Rời Workspace (nếu là Owner và là người cuối cùng thì xóa luôn Workspace).
    /// </summary>
    [HttpDelete("{id}/leave")]
    public async Task<IActionResult> LeaveWorkspace(string id, [FromQuery] string userUid)
    {
        var workspace = await db.Workspaces
            .Include(w => w.Members)
            .FirstOrDefaultAsync(w => w.Id == id);

        if (workspace is null) return NotFound();

        if (workspace.OwnerUid == userUid)
        {
            db.Workspaces.Remove(workspace);
            await db.SaveChangesAsync();
            return NoContent();
        }

        var member = workspace.Members.FirstOrDefault(m => m.UserUid == userUid);
        if (member is null) return NotFound();

        db.WorkspaceMembers.Remove(member);
        await db.SaveChangesAsync();
        return NoContent();
    }

    /// <summary>
    /// Mời thành viên ra khỏi nhóm (Kick) — chỉ Nhóm trưởng (Owner) mới có quyền.
    /// </summary>
    [HttpDelete("{id}/members/{targetUid}")]
    public async Task<IActionResult> KickMember(
        string id,
        string targetUid,
        [FromQuery] string requesterUid)
    {
        if (string.IsNullOrWhiteSpace(requesterUid) ||
            string.IsNullOrWhiteSpace(targetUid))
        {
            return BadRequest(new { message = "Thiếu thông tin người yêu cầu hoặc thành viên cần xóa." });
        }

        var workspace = await db.Workspaces
            .Include(w => w.Members)
            .Include(w => w.Tasks)
            .FirstOrDefaultAsync(w => w.Id == id);

        if (workspace is null)
            return NotFound(new { message = "Nhóm không tồn tại." });

        if (workspace.OwnerUid != requesterUid)
            return StatusCode(403, new { message = "Chỉ nhóm trưởng mới có quyền mời thành viên ra khỏi nhóm." });

        if (targetUid == workspace.OwnerUid)
            return BadRequest(new { message = "Không thể xóa nhóm trưởng. Hãy dùng chức năng Xóa nhóm." });

        var member = workspace.Members.FirstOrDefault(m => m.UserUid == targetUid);
        if (member is null)
            return NotFound(new { message = "Thành viên không còn trong nhóm." });

        // Gỡ phân công các công việc đang giao cho thành viên bị mời ra
        foreach (var task in workspace.Tasks.Where(t => t.AssigneeUid == targetUid))
        {
            task.AssigneeUid = null;
            task.AssigneeName = null;
            task.UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        }

        db.WorkspaceMembers.Remove(member);
        await db.SaveChangesAsync();
        return NoContent();
    }

    /// <summary>
    /// Tải toàn bộ dữ liệu 1 Workspace (Members, Schedules, Tasks, Notes) trong 1 request.
    /// </summary>
    [HttpGet("{id}/overview")]
    public async Task<ActionResult<WorkspaceOverviewDto>> GetOverview(string id)
    {
        var workspace = await db.Workspaces
            .Include(w => w.Members)
            .Include(w => w.Schedules)
            .Include(w => w.Tasks)
            .Include(w => w.Notes)
            .FirstOrDefaultAsync(w => w.Id == id);

        if (workspace is null)
            return NotFound(new { message = "Workspace không tồn tại." });

        return Ok(new WorkspaceOverviewDto(
            ToSummary(workspace),
            workspace.Members
                .OrderBy(m => m.JoinedAt)
                .Select(m => new WorkspaceMemberDto(
                    m.Id, m.UserUid, m.DisplayName, m.Email, m.Role, m.JoinedAt))
                .ToList(),
            workspace.Schedules
                .OrderBy(s => s.DayOfWeek)
                .ThenBy(s => s.StartTime)
                .Select(ToScheduleDto)
                .ToList(),
            workspace.Tasks
                .OrderBy(t => t.IsCompleted)
                .ThenByDescending(t => t.Priority)
                .ThenBy(t => t.DueDate ?? long.MaxValue)
                .Select(ToTaskDto)
                .ToList(),
            workspace.Notes
                .OrderByDescending(n => n.UpdatedAt)
                .Select(ToNoteDto)
                .ToList()
        ));
    }

    // ==================== SCHEDULES (MỤC LỚN CHUNG) ====================

    [HttpPost("{id}/schedules")]
    public async Task<ActionResult<WorkspaceScheduleDto>> CreateSchedule(
        string id,
        [FromBody] UpsertScheduleRequest req)
    {
        if (!await db.Workspaces.AnyAsync(w => w.Id == id))
            return NotFound(new { message = "Workspace không tồn tại." });

        var schedule = new WorkspaceSchedule
        {
            WorkspaceId = id,
            Title = req.Title.Trim(),
            DayOfWeek = req.DayOfWeek,
            ScheduleDate = req.ScheduleDate,
            IsRecurring = req.IsRecurring,
            StartTime = req.StartTime,
            EndTime = req.EndTime,
            Location = (req.Location ?? string.Empty).Trim(),
            Note = (req.Note ?? string.Empty).Trim(),
            ColorHex = string.IsNullOrWhiteSpace(req.ColorHex) ? "#DBEAFE" : req.ColorHex,
            CreatedByName = (req.CreatedByName ?? string.Empty).Trim(),
            UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        };

        db.WorkspaceSchedules.Add(schedule);
        await db.SaveChangesAsync();
        return Ok(ToScheduleDto(schedule));
    }

    [HttpPut("{id}/schedules/{scheduleId}")]
    public async Task<ActionResult<WorkspaceScheduleDto>> UpdateSchedule(
        string id,
        string scheduleId,
        [FromBody] UpsertScheduleRequest req)
    {
        var schedule = await db.WorkspaceSchedules
            .FirstOrDefaultAsync(s => s.Id == scheduleId && s.WorkspaceId == id);
        if (schedule is null) return NotFound();

        schedule.Title = req.Title.Trim();
        schedule.DayOfWeek = req.DayOfWeek;
        schedule.ScheduleDate = req.ScheduleDate;
        schedule.IsRecurring = req.IsRecurring;
        schedule.StartTime = req.StartTime;
        schedule.EndTime = req.EndTime;
        schedule.Location = (req.Location ?? string.Empty).Trim();
        schedule.Note = (req.Note ?? string.Empty).Trim();
        if (!string.IsNullOrWhiteSpace(req.ColorHex)) schedule.ColorHex = req.ColorHex;
        schedule.UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

        await db.SaveChangesAsync();
        return Ok(ToScheduleDto(schedule));
    }

    [HttpDelete("{id}/schedules/{scheduleId}")]
    public async Task<IActionResult> DeleteSchedule(string id, string scheduleId)
    {
        var schedule = await db.WorkspaceSchedules
            .FirstOrDefaultAsync(s => s.Id == scheduleId && s.WorkspaceId == id);
        if (schedule is null) return NotFound();

        db.WorkspaceSchedules.Remove(schedule);
        await db.SaveChangesAsync();
        return NoContent();
    }

    // ==================== TASKS (CÔNG VIỆC NHỎ & PHÂN CÔNG THÀNH VIÊN) ====================

    [HttpPost("{id}/tasks")]
    public async Task<ActionResult<WorkspaceTaskDto>> CreateTask(
        string id,
        [FromBody] UpsertTaskRequest req)
    {
        if (!await db.Workspaces.AnyAsync(w => w.Id == id))
            return NotFound(new { message = "Workspace không tồn tại." });

        var task = new WorkspaceTask
        {
            WorkspaceId = id,
            ScheduleId = string.IsNullOrWhiteSpace(req.ScheduleId) ? null : req.ScheduleId,
            Title = req.Title.Trim(),
            Description = (req.Description ?? string.Empty).Trim(),
            Priority = req.Priority,
            IsCompleted = req.IsCompleted,
            DueDate = req.DueDate,
            AssigneeUid = req.AssigneeUid,
            AssigneeName = req.AssigneeName,
            UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        };

        db.WorkspaceTasks.Add(task);
        await db.SaveChangesAsync();
        return Ok(ToTaskDto(task));
    }

    [HttpPut("{id}/tasks/{taskId}")]
    public async Task<ActionResult<WorkspaceTaskDto>> UpdateTask(
        string id,
        string taskId,
        [FromBody] UpsertTaskRequest req)
    {
        var task = await db.WorkspaceTasks
            .FirstOrDefaultAsync(t => t.Id == taskId && t.WorkspaceId == id);
        if (task is null) return NotFound();

        task.ScheduleId = string.IsNullOrWhiteSpace(req.ScheduleId) ? null : req.ScheduleId;
        task.Title = req.Title.Trim();
        task.Description = (req.Description ?? string.Empty).Trim();
        task.Priority = req.Priority;
        task.IsCompleted = req.IsCompleted;
        task.DueDate = req.DueDate;
        task.AssigneeUid = req.AssigneeUid;
        task.AssigneeName = req.AssigneeName;
        task.UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

        await db.SaveChangesAsync();
        return Ok(ToTaskDto(task));
    }

    [HttpPatch("{id}/tasks/{taskId}/toggle")]
    public async Task<ActionResult<WorkspaceTaskDto>> ToggleTask(string id, string taskId)
    {
        var task = await db.WorkspaceTasks
            .FirstOrDefaultAsync(t => t.Id == taskId && t.WorkspaceId == id);
        if (task is null) return NotFound();

        task.IsCompleted = !task.IsCompleted;
        task.UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        await db.SaveChangesAsync();
        return Ok(ToTaskDto(task));
    }

    [HttpDelete("{id}/tasks/{taskId}")]
    public async Task<IActionResult> DeleteTask(string id, string taskId)
    {
        var task = await db.WorkspaceTasks
            .FirstOrDefaultAsync(t => t.Id == taskId && t.WorkspaceId == id);
        if (task is null) return NotFound();

        db.WorkspaceTasks.Remove(task);
        await db.SaveChangesAsync();
        return NoContent();
    }

    // ==================== NOTES (GHI CHÚ CHUNG THEO NGÀY) ====================

    [HttpPost("{id}/notes")]
    public async Task<ActionResult<WorkspaceNoteDto>> CreateNote(
        string id,
        [FromBody] CreateNoteRequest req)
    {
        if (!await db.Workspaces.AnyAsync(w => w.Id == id))
            return NotFound(new { message = "Workspace không tồn tại." });

        var note = new WorkspaceNote
        {
            WorkspaceId = id,
            ScheduleDate = req.ScheduleDate,
            Title = req.Title.Trim(),
            Content = (req.Content ?? string.Empty).Trim(),
            ColorHex = string.IsNullOrWhiteSpace(req.ColorHex) ? "#FEF3C7" : req.ColorHex,
            AuthorName = (req.AuthorName ?? string.Empty).Trim(),
            UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        };

        db.WorkspaceNotes.Add(note);
        await db.SaveChangesAsync();
        return Ok(ToNoteDto(note));
    }

    [HttpDelete("{id}/notes/{noteId}")]
    public async Task<IActionResult> DeleteNote(string id, string noteId)
    {
        var note = await db.WorkspaceNotes
            .FirstOrDefaultAsync(n => n.Id == noteId && n.WorkspaceId == id);
        if (note is null) return NotFound();

        db.WorkspaceNotes.Remove(note);
        await db.SaveChangesAsync();
        return NoContent();
    }

    // ==================== HELPERS ====================

    private async Task<string> GenerateUniqueInviteCodeAsync()
    {
        for (var attempt = 0; attempt < 20; attempt++)
        {
            var chars = new char[6];
            for (var i = 0; i < 6; i++)
            {
                chars[i] = InviteAlphabet[RandomNumberGenerator.GetInt32(InviteAlphabet.Length)];
            }
            var code = new string(chars);
            if (!await db.Workspaces.AnyAsync(w => w.InviteCode == code))
                return code;
        }
        return Guid.NewGuid().ToString("N")[..6].ToUpperInvariant();
    }

    private static WorkspaceSummaryDto ToSummary(Workspace w) => new(
        w.Id, w.Name, w.Description, w.InviteCode, w.OwnerUid, w.OwnerName,
        w.Members.Count, w.CreatedAt);

    private static WorkspaceScheduleDto ToScheduleDto(WorkspaceSchedule s) => new(
        s.Id, s.WorkspaceId, s.Title, s.DayOfWeek, s.ScheduleDate, s.IsRecurring,
        s.StartTime, s.EndTime, s.Location, s.Note, s.ColorHex, s.CreatedByName, s.UpdatedAt);

    private static WorkspaceTaskDto ToTaskDto(WorkspaceTask t) => new(
        t.Id, t.WorkspaceId, t.ScheduleId, t.Title, t.Description, t.Priority,
        t.IsCompleted, t.DueDate, t.AssigneeUid, t.AssigneeName, t.UpdatedAt);

    private static WorkspaceNoteDto ToNoteDto(WorkspaceNote n) => new(
        n.Id, n.WorkspaceId, n.ScheduleDate, n.Title, n.Content,
        n.ColorHex, n.AuthorName, n.UpdatedAt);
}
