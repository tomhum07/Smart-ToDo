using Microsoft.EntityFrameworkCore;
using SmartTodo.Api.Models;

namespace SmartTodo.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Workspace> Workspaces => Set<Workspace>();
    public DbSet<WorkspaceMember> WorkspaceMembers => Set<WorkspaceMember>();
    public DbSet<WorkspaceSchedule> WorkspaceSchedules => Set<WorkspaceSchedule>();
    public DbSet<WorkspaceTask> WorkspaceTasks => Set<WorkspaceTask>();
    public DbSet<WorkspaceNote> WorkspaceNotes => Set<WorkspaceNote>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Workspace>()
            .HasIndex(w => w.InviteCode)
            .IsUnique();

        modelBuilder.Entity<WorkspaceMember>()
            .HasIndex(m => new { m.WorkspaceId, m.UserUid })
            .IsUnique();

        modelBuilder.Entity<WorkspaceMember>()
            .HasOne(m => m.Workspace)
            .WithMany(w => w.Members)
            .HasForeignKey(m => m.WorkspaceId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<WorkspaceSchedule>()
            .HasOne(s => s.Workspace)
            .WithMany(w => w.Schedules)
            .HasForeignKey(s => s.WorkspaceId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<WorkspaceTask>()
            .HasOne(t => t.Workspace)
            .WithMany(w => w.Tasks)
            .HasForeignKey(t => t.WorkspaceId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<WorkspaceTask>()
            .HasOne(t => t.Schedule)
            .WithMany(s => s.Tasks)
            .HasForeignKey(t => t.ScheduleId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<WorkspaceNote>()
            .HasOne(n => n.Workspace)
            .WithMany(w => w.Notes)
            .HasForeignKey(n => n.WorkspaceId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
