import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/services/app_update_service.dart';

/// Hộp thoại thông báo có bản cập nhật mới và tải + cài đặt APK trực tiếp trong app.
class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;

  const AppUpdateDialog({super.key, required this.info});

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showShadDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppUpdateDialog(info: info),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _statusText;
  String? _errorText;

  Future<void> _startUpdate() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = widget.info.apkSizeBytes;
      _statusText = 'Đang kết nối máy chủ tải bản cập nhật...';
      _errorText = null;
    });

    try {
      await AppUpdateService.instance.downloadAndInstallApk(
        widget.info,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          final pct = (progress * 100).round();
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
            _statusText = pct >= 100
                ? 'Đang mở trình cài đặt Android...'
                : 'Đang tải bản cập nhật ($pct%)...';
          });
        },
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final info = widget.info;

    return PopScope(
      canPop: !_isDownloading,
      child: ShadDialog(
        title: Row(
          children: [
            Icon(
              LucideIcons.download,
              size: 20,
              color: shadTheme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Có bản cập nhật mới ${info.tagName}'),
            ),
          ],
        ),
        description: Text(
          'Phiên bản hiện tại: v${info.currentVersion}'
          '${info.formattedSize.isNotEmpty ? ' • Dung lượng: ${info.formattedSize}' : ''}',
        ),
        actions: [
          ShadButton.outline(
            onPressed: _isDownloading ? null : () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          ShadButton(
            onPressed: _isDownloading ? null : _startUpdate,
            child: _isDownloading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Đang tải...'),
                    ],
                  )
                : Text(_errorText != null ? 'Thử lại' : 'Cập nhật ngay'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (info.releaseNotes.isNotEmpty) ...[
                Text(
                  'Điểm mới trong phiên bản này:',
                  style: shadTheme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: shadTheme.colorScheme.secondary
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: shadTheme.colorScheme.border),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        info.releaseNotes,
                        style: shadTheme.textTheme.small.copyWith(height: 1.4),
                      ),
                    ),
                  ),
                ),
              ],
              if (_isDownloading) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _statusText ?? 'Đang tải...',
                        style: shadTheme.textTheme.muted.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_totalBytes > 0)
                      Text(
                        '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                        style: shadTheme.textTheme.muted.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                ShadAlert.destructive(
                  icon: const Icon(LucideIcons.circleAlert),
                  title: const Text('Cập nhật thất bại'),
                  description: Text(_errorText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
