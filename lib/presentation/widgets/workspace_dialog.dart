import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/constants/api_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/workspace_provider.dart';

/// Hộp thoại Tạo Không gian Chia sẻ Nhóm mới hoặc Tham gia bằng mã mời 6 ký tự (.NET Web API).
class WorkspaceDialog extends StatefulWidget {
  const WorkspaceDialog({super.key});

  @override
  State<WorkspaceDialog> createState() => _WorkspaceDialogState();
}

class _WorkspaceDialogState extends State<WorkspaceDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _codeController = TextEditingController();

  int _modeIndex = 0; // 0 = Tạo Workspace mới, 1 = Tham gia bằng mã
  bool _isLoading = false;
  String? _createdCode;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập tên Không gian nhóm.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final wsProvider = context.read<WorkspaceProvider>();
      final scheduleProvider = context.read<ScheduleProvider>();

      final created = await wsProvider.createWorkspace(
        name: name,
        description: _descController.text.trim(),
        ownerUid: auth.effectiveUserId,
        ownerName: auth.displayName,
        ownerEmail: auth.email,
      );

      scheduleProvider.setSharedWorkspaces(wsProvider.toWorkspaceOptions());
      scheduleProvider.selectWorkspace(created.id);

      if (!mounted) return;
      setState(() {
        _createdCode = created.inviteCode;
        _successMessage =
            'Đã tạo "${created.name}"! Gửi mã ${created.inviteCode} cho thành viên tham gia.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _errorMessage = 'Vui lòng nhập mã mời 6 ký tự hợp lệ.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final wsProvider = context.read<WorkspaceProvider>();
      final scheduleProvider = context.read<ScheduleProvider>();

      final joined = await wsProvider.joinByCode(
        inviteCode: code,
        userUid: auth.effectiveUserId,
        displayName: auth.displayName,
        email: auth.email,
      );

      scheduleProvider.setSharedWorkspaces(wsProvider.toWorkspaceOptions());
      scheduleProvider.selectWorkspace(joined.id);

      if (!mounted) return;
      setState(() {
        _successMessage = 'Đã tham gia không gian "${joined.name}"!';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return ShadDialog(
      title: const Text('Không gian Chia sẻ Nhóm'),
      description: const Text(
        'Cùng nhóm quản lý lịch trình chung, phân công công việc cho từng thành viên và ghi chú theo ngày.',
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!ApiConstants.isDotNetConfigured) ...[
              const ShadAlert(
                icon: Icon(LucideIcons.serverOff),
                title: Text('Chưa gắn URL Backend .NET (Render)'),
                description: Text(
                  'Sau khi deploy thư mục backend_api/ lên Render và dán URL vào api_constants.dart, tính năng Không gian nhóm sẽ chạy ngay.',
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Tạo nhóm mới')),
                    selected: _modeIndex == 0,
                    onSelected: (_) => setState(() {
                      _modeIndex = 0;
                      _errorMessage = null;
                      _successMessage = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Nhập mã mời')),
                    selected: _modeIndex == 1,
                    onSelected: (_) => setState(() {
                      _modeIndex = 1;
                      _errorMessage = null;
                      _successMessage = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_modeIndex == 0) ...[
              ShadInput(
                controller: _nameController,
                placeholder: const Text('VD: Nhóm Dự án A'),
              ),
              const SizedBox(height: 10),
              ShadInput(
                controller: _descController,
                placeholder: const Text('Mô tả ngắn (tùy chọn)'),
              ),
              const SizedBox(height: 12),
              if (_createdCode != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: shadTheme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _createdCode!,
                        style: shadTheme.textTheme.h3.copyWith(
                          letterSpacing: 3,
                        ),
                      ),
                      ShadButton.outline(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _createdCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép mã mời!'),
                            ),
                          );
                        },
                        child: const Icon(LucideIcons.copy, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              ShadButton(
                onPressed: _isLoading ? null : _handleCreate,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tạo Không gian & Lấy mã 6 ký tự'),
              ),
            ] else ...[
              ShadInput(
                controller: _codeController,
                placeholder: const Text('Nhập mã mời 6 ký tự (VD: AB12CD)'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              ShadButton(
                onPressed: _isLoading ? null : _handleJoin,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tham gia Không gian nhóm'),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              ShadAlert.destructive(
                icon: const Icon(LucideIcons.circleAlert),
                title: const Text('Thông báo'),
                description: Text(_errorMessage!),
              ),
            ],
            if (_successMessage != null) ...[
              const SizedBox(height: 12),
              ShadAlert(
                icon: const Icon(LucideIcons.circleCheck),
                title: const Text('Thành công'),
                description: Text(_successMessage!),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
