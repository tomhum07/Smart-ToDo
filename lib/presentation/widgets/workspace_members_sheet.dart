import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/models/workspace_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/workspace_provider.dart';

/// Bottom Sheet Quản lý nhóm: xem danh sách thành viên, kick thành viên (chỉ Nhóm trưởng),
/// rời nhóm (Thành viên) hoặc xóa nhóm vĩnh viễn (chỉ Nhóm trưởng).
class WorkspaceMembersSheet extends StatefulWidget {
  const WorkspaceMembersSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const WorkspaceMembersSheet(),
    );
  }

  @override
  State<WorkspaceMembersSheet> createState() => _WorkspaceMembersSheetState();
}

class _WorkspaceMembersSheetState extends State<WorkspaceMembersSheet> {
  bool _isProcessing = false;
  String? _kickingUid;

  Future<void> _confirmKickMember(
    WorkspaceOverview overview,
    WorkspaceMember member,
    String requesterUid,
  ) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Mời thành viên ra khỏi nhóm?'),
        description: Text(
          'Bạn có chắc muốn xóa "${member.displayName}" khỏi nhóm "${overview.workspace.name}" không? Các công việc đang giao cho thành viên này sẽ chuyển về chưa phân công.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa khỏi nhóm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _kickingUid = member.userUid);
    try {
      await context.read<WorkspaceProvider>().kickMember(
            workspaceId: overview.workspace.id,
            targetUid: member.userUid,
            requesterUid: requesterUid,
          );
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã mời "${member.displayName}" ra khỏi nhóm.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _kickingUid = null);
    }
  }

  Future<void> _confirmLeaveOrDelete(
    WorkspaceOverview overview, {
    required bool isOwner,
    required String currentUid,
  }) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: Text(isOwner ? 'Xóa nhóm vĩnh viễn?' : 'Rời khỏi nhóm?'),
        description: Text(
          isOwner
              ? 'Bạn là Nhóm trưởng. Xóa "${overview.workspace.name}" sẽ xóa vĩnh viễn toàn bộ lịch trình, công việc và ghi chú chung của tất cả thành viên!'
              : 'Bạn có chắc muốn rời khỏi nhóm "${overview.workspace.name}" không? Bạn có thể tham gia lại sau bằng mã mời.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isOwner ? 'Xóa nhóm' : 'Rời nhóm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final wsProvider = context.read<WorkspaceProvider>();
      final scheduleProvider = context.read<ScheduleProvider>();

      await wsProvider.leaveWorkspace(
        workspaceId: overview.workspace.id,
        userUid: currentUid,
      );
      scheduleProvider.setSharedWorkspaces(wsProvider.toWorkspaceOptions());
      scheduleProvider.selectWorkspace(ScheduleProvider.personalWorkspace.id);
      HapticFeedback.lightImpact();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOwner
                ? 'Đã xóa nhóm "${overview.workspace.name}".'
                : 'Đã rời khỏi nhóm "${overview.workspace.name}".',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsProvider = context.watch<WorkspaceProvider>();
    final auth = context.watch<AuthProvider>();
    final shadTheme = ShadTheme.of(context);
    final overview = wsProvider.activeOverview;

    if (overview == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Bạn không còn trong nhóm này.')),
      );
    }

    final currentUid = auth.effectiveUserId;
    final isOwner = overview.workspace.ownerUid == currentUid;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề & Mã mời
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quản lý nhóm',
                        style: shadTheme.textTheme.h4,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        overview.workspace.name,
                        style: shadTheme.textTheme.muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: overview.workspace.inviteCode),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép mã mời!')),
                    );
                  },
                  child: ShadBadge.secondary(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Mã: ${overview.workspace.inviteCode}'),
                        const SizedBox(width: 5),
                        const Icon(LucideIcons.copy, size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (overview.workspace.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                overview.workspace.description,
                style: shadTheme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ],
            const Divider(height: 22),

            // Tiêu đề danh sách thành viên
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thành viên (${overview.members.length})',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ShadBadge.outline(
                  child: Text(isOwner ? 'Bạn là Nhóm trưởng' : 'Thành viên'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Danh sách thành viên cuộn được
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: overview.members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final member = overview.members[index];
                  final isMemberOwner =
                      member.role == 'Owner' ||
                      member.userUid == overview.workspace.ownerUid;
                  final isMe = member.userUid == currentUid;
                  final canKick = isOwner && !isMemberOwner && !isMe;
                  final isKickingThis = _kickingUid == member.userUid;
                  final initial = member.displayName.isNotEmpty
                      ? member.displayName[0].toUpperCase()
                      : '?';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: shadTheme.colorScheme.secondary
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: shadTheme.colorScheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isMemberOwner
                              ? shadTheme.colorScheme.primary
                              : shadTheme.colorScheme.secondary,
                          foregroundColor: isMemberOwner
                              ? shadTheme.colorScheme.primaryForeground
                              : shadTheme.colorScheme.foreground,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      isMe
                                          ? '${member.displayName} (Bạn)'
                                          : member.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: shadTheme.textTheme.small.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMemberOwner
                                          ? shadTheme.colorScheme.primary
                                              .withValues(alpha: 0.16)
                                          : shadTheme.colorScheme.muted,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isMemberOwner
                                          ? 'Nhóm trưởng'
                                          : 'Thành viên',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isMemberOwner
                                            ? shadTheme.colorScheme.primary
                                            : shadTheme
                                                .colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (member.email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  member.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: shadTheme.textTheme.muted
                                      .copyWith(fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (canKick)
                          IconButton(
                            tooltip: 'Mời ra khỏi nhóm',
                            visualDensity: VisualDensity.compact,
                            onPressed: isKickingThis || _isProcessing
                                ? null
                                : () => _confirmKickMember(
                                      overview,
                                      member,
                                      currentUid,
                                    ),
                            icon: isKickingThis
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.userMinus,
                                    size: 17,
                                    color: Color(0xFFDC2626),
                                  ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 22),

            // Nút Rời nhóm (Thành viên) hoặc Xóa nhóm (chỉ Nhóm trưởng)
            ShadButton.destructive(
              onPressed: _isProcessing
                  ? null
                  : () => _confirmLeaveOrDelete(
                        overview,
                        isOwner: isOwner,
                        currentUid: currentUid,
                      ),
              child: _isProcessing
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Đang xử lý...'),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOwner ? LucideIcons.trash2 : LucideIcons.logOut,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(isOwner ? 'Xóa nhóm vĩnh viễn' : 'Rời khỏi nhóm'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
