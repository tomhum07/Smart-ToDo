import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/constants/api_constants.dart';
import '../../data/remote/dotnet_api_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/schedule_provider.dart';

/// Hộp thoại Chia sẻ & Nhập Thời khóa biểu bằng mã 6 ký tự (kết nối .NET Web API ở Phase 4).
class ShareScheduleDialog extends StatefulWidget {
  const ShareScheduleDialog({super.key});

  @override
  State<ShareScheduleDialog> createState() => _ShareScheduleDialogState();
}

class _ShareScheduleDialogState extends State<ShareScheduleDialog> {
  final DotNetApiService _api = DotNetApiService();
  final _codeController = TextEditingController();

  int _modeIndex = 0; // 0 = Tạo mã chia sẻ, 1 = Nhập mã
  bool _isLoading = false;
  String? _generatedCode;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateShare() async {
    final schedules = context.read<ScheduleProvider>().allSchedules;
    if (schedules.isEmpty) {
      setState(
        () => _errorMessage = 'Bạn chưa có lịch trình nào để chia sẻ.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final result = await _api.createShare(
        type: 'schedule',
        ownerName: auth.displayName,
        items: schedules.map((e) => e.toJson()).toList(),
      );
      if (!mounted) return;
      setState(() {
        _generatedCode = result.code;
        _successMessage =
            'Đã tạo mã chia sẻ cho ${schedules.length} tiết học!';
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

  Future<void> _handleImportByCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _errorMessage = 'Vui lòng nhập mã chia sẻ hợp lệ.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final data = await _api.getShareByCode(code);
      final rawItems = (data['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final importedCount = await context
          .read<ScheduleProvider>()
          .importSchedulesFromShare(
            userId: auth.effectiveUserId,
            rawItems: rawItems,
          );

      if (!mounted) return;
      setState(() {
        _successMessage =
            'Đã nhập thành công $importedCount lịch trình từ mã $code!';
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
      title: const Text('Chia sẻ Thời khóa biểu'),
      description: const Text(
        'Tạo mã 6 ký tự để chia sẻ cho bạn cùng lớp hoặc nhập mã để tải lịch về máy.',
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!ApiConstants.isDotNetConfigured) ...[
              const ShadAlert(
                icon: Icon(LucideIcons.serverOff),
                title: Text('Chờ kết nối .NET Web API (Phase 4)'),
                description: Text(
                  'Giao diện & hợp đồng REST API đã sẵn sàng. Sau khi nhóm deploy .NET API ở Phase 4 và điền URL vào api_constants.dart, tính năng sẽ chạy ngay.',
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Tạo mã chia sẻ')),
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
                    label: const Center(child: Text('Nhập bằng mã')),
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
              if (_generatedCode != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: shadTheme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _generatedCode!,
                        style: shadTheme.textTheme.h3.copyWith(
                          letterSpacing: 3,
                        ),
                      ),
                      ShadButton.outline(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _generatedCode!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép mã chia sẻ!'),
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
                onPressed: _isLoading ? null : _handleCreateShare,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tạo mã chia sẻ lịch hiện tại'),
              ),
            ] else ...[
              ShadInput(
                controller: _codeController,
                placeholder: const Text('Nhập mã 6 ký tự (VD: DTHU99)'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              ShadButton(
                onPressed: _isLoading ? null : _handleImportByCode,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tải & Nhập thời khóa biểu'),
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
    );
  }
}
