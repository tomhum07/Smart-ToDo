import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/api_constants.dart';

/// Thông tin bản cập nhật mới lấy từ GitHub Releases.
class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String tagName;
  final String releaseTitle;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String apkFileName;
  final int apkSizeBytes;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.tagName,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkFileName,
    required this.apkSizeBytes,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Dịch vụ kiểm tra, tải và cài đặt bản cập nhật APK trực tiếp từ GitHub Releases.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  bool _hasCheckedThisSession = false;

  /// Đọc phiên bản hiện tại của ứng dụng (VD: 1.1.0).
  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '1.0.0';
    }
  }

  /// So sánh 2 chuỗi phiên bản SemVer (VD: "1.2.0" > "1.1.0").
  static bool isNewerVersion(String latest, String current) {
    List<int> parse(String v) {
      final clean = v.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
      return clean
          .split('.')
          .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .toList();
    }

    final latestParts = parse(latest);
    final currentParts = parse(current);
    final maxLen = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Kiểm tra bản phát hành mới nhất trên GitHub Releases.
  /// Trả về [AppUpdateInfo] nếu có bản mới hơn kèm file .apk, ngược lại trả về null.
  Future<AppUpdateInfo?> checkForUpdate({bool onlyOncePerSession = false}) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    if (onlyOncePerSession && _hasCheckedThisSession) return null;
    _hasCheckedThisSession = true;

    final currentVersion = await getCurrentVersion();

    final res = await http.get(
      Uri.parse(ApiConstants.githubLatestReleaseUrl),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'SmartTodo-Android-App',
      },
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Không thể kiểm tra cập nhật (HTTP ${res.statusCode}).');
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final tagName = (data['tag_name'] as String?)?.trim() ?? '';
    if (tagName.isEmpty) return null;

    final latestVersion = tagName.replaceFirst(RegExp(r'^[vV]'), '');
    if (!isNewerVersion(latestVersion, currentVersion)) {
      return null;
    }

    final assets = (data['assets'] as List?) ?? const [];
    Map<String, dynamic>? apkAsset;
    for (final raw in assets) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final name = (map['name'] as String?)?.toLowerCase() ?? '';
      if (name.endsWith('.apk')) {
        apkAsset = map;
        break;
      }
    }

    if (apkAsset == null) return null;

    final downloadUrl = (apkAsset['browser_download_url'] as String?) ?? '';
    if (downloadUrl.isEmpty) return null;

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      tagName: tagName,
      releaseTitle: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Phiên bản $tagName',
      releaseNotes: (data['body'] as String?)?.trim() ?? '',
      apkDownloadUrl: downloadUrl,
      apkFileName: (apkAsset['name'] as String?) ?? 'smart_todo_$latestVersion.apk',
      apkSizeBytes: (apkAsset['size'] as num?)?.toInt() ?? 0,
    );
  }

  /// Tải file APK về bộ nhớ tạm kèm tiến trình thực tế, sau đó mở trực tiếp trình cài đặt Android.
  Future<void> downloadAndInstallApk(
    AppUpdateInfo info, {
    required void Function(double progress, int receivedBytes, int totalBytes)
        onProgress,
  }) async {
    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(info.apkDownloadUrl))
        ..headers['User-Agent'] = 'SmartTodo-Android-App';
      final streamed = await client.send(request).timeout(
            const Duration(seconds: 30),
          );

      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw Exception(
          'Tải file cập nhật thất bại (HTTP ${streamed.statusCode}).',
        );
      }

      final totalBytes = streamed.contentLength ?? info.apkSizeBytes;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/${info.apkFileName}');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      sink = apkFile.openWrite();
      var receivedBytes = 0;

      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0
            ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;
        onProgress(progress, receivedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final result = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        throw Exception(
          result.message.isNotEmpty
              ? 'Không thể mở trình cài đặt: ${result.message}'
              : 'Không thể mở trình cài đặt APK. Vui lòng cấp quyền cài đặt ứng dụng không rõ nguồn gốc.',
        );
      }
    } finally {
      await sink?.close();
      client.close();
    }
  }
}
