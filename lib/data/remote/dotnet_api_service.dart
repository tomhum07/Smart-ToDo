import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

/// Kết quả trả về khi tạo mã chia sẻ Thời khóa biểu / Ghi chú từ .NET Web API.
class ShareCodeResult {
  final String code;
  final DateTime? expiresAt;

  const ShareCodeResult({required this.code, this.expiresAt});

  factory ShareCodeResult.fromJson(Map<String, dynamic> json) {
    return ShareCodeResult(
      code: (json['code'] as String?) ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }
}

/// Hợp đồng REST API kết nối tới server .NET Web API của nhóm (Share/Import Code).
class DotNetApiService {
  final http.Client _client;

  DotNetApiService({http.Client? client}) : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 90);

  /// Kiểm tra trạng thái hoạt động của server .NET.
  Future<bool> checkHealth() async {
    _ensureConfigured();
    final response = await _client
        .get(Uri.parse(ApiConstants.dotnetHealthUrl))
        .timeout(_timeout);
    return response.statusCode == 200;
  }

  /// Tạo mã chia sẻ 6 ký tự cho danh sách Thời khóa biểu hoặc Ghi chú.
  Future<ShareCodeResult> createShare({
    required String type, // 'schedule' | 'note'
    required String ownerName,
    required List<Map<String, dynamic>> items,
  }) async {
    _ensureConfigured();
    final response = await _client
        .post(
          Uri.parse(ApiConstants.dotnetSharesUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'type': type,
            'ownerName': ownerName,
            'items': items,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ShareCodeResult.fromJson(data);
    }

    throw Exception(
      'Tạo mã chia sẻ thất bại (${response.statusCode}): ${response.body}',
    );
  }

  /// Tải dữ liệu chia sẻ theo mã 6 ký tự.
  Future<Map<String, dynamic>> getShareByCode(String code) async {
    _ensureConfigured();
    final cleaned = code.trim().toUpperCase();
    final response = await _client
        .get(Uri.parse(ApiConstants.dotnetShareByCodeUrl(cleaned)))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    if (response.statusCode == 404) {
      throw Exception('Mã chia sẻ "$cleaned" không tồn tại hoặc đã hết hạn.');
    }

    throw Exception(
      'Không thể tải dữ liệu chia sẻ (${response.statusCode}).',
    );
  }

  /// Xóa/thu hồi mã chia sẻ.
  Future<void> deleteShare(String code) async {
    _ensureConfigured();
    final cleaned = code.trim().toUpperCase();
    final response = await _client
        .delete(Uri.parse(ApiConstants.dotnetShareByCodeUrl(cleaned)))
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Xóa mã chia sẻ thất bại (${response.statusCode}).');
    }
  }

  void _ensureConfigured() {
    if (!ApiConstants.isDotNetConfigured) {
      throw Exception(
        '.NET Web API chưa được cấu hình. Hãy cập nhật DOTNET_API_URL trong api_constants.dart sau khi deploy.',
      );
    }
  }
}
