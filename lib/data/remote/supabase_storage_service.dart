import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../core/constants/api_constants.dart';

/// Dịch vụ upload và xóa ảnh ghi chú qua Supabase Storage REST API (package:http).
class SupabaseStorageService {
  final http.Client _client;

  SupabaseStorageService({http.Client? client})
      : _client = client ?? http.Client();

  /// Upload ảnh cục bộ lên Supabase Storage và trả về Public URL.
  Future<String> uploadNoteImage({
    required File imageFile,
    required String userId,
    required String noteId,
  }) async {
    _ensureConfigured();

    final ext = p.extension(imageFile.path).toLowerCase();
    final safeExt = (ext == '.png' || ext == '.webp') ? ext : '.jpg';
    final contentType = safeExt == '.png'
        ? 'image/png'
        : safeExt == '.webp'
            ? 'image/webp'
            : 'image/jpeg';

    final objectPath = '$userId/$noteId$safeExt';
    final uploadUri = Uri.parse(
      '${ApiConstants.supabaseUrl}/storage/v1/object/${ApiConstants.supabaseNoteImagesBucket}/$objectPath',
    );

    final bytes = await imageFile.readAsBytes();
    final response = await _client.post(
      uploadUri,
      headers: {
        'Authorization': 'Bearer ${ApiConstants.supabaseAnonKey}',
        'apikey': ApiConstants.supabaseAnonKey,
        'Content-Type': contentType,
        'x-upsert': 'true',
      },
      body: bytes,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Giải mã phản hồi JSON từ Supabase để xác nhận key lưu thành công.
      if (response.body.isNotEmpty) {
        jsonDecode(response.body);
      }
      return '${ApiConstants.supabaseUrl}/storage/v1/object/public/${ApiConstants.supabaseNoteImagesBucket}/$objectPath';
    }

    throw Exception(
      'Upload ảnh lên Supabase thất bại (${response.statusCode}): ${response.body}',
    );
  }

  /// Xóa ảnh ghi chú khỏi Supabase Storage theo objectPath (ví dụ: uid/noteId.jpg).
  Future<void> deleteNoteImage(String objectPath) async {
    _ensureConfigured();

    final deleteUri = Uri.parse(
      '${ApiConstants.supabaseUrl}/storage/v1/object/${ApiConstants.supabaseNoteImagesBucket}/$objectPath',
    );

    final response = await _client.delete(
      deleteUri,
      headers: {
        'Authorization': 'Bearer ${ApiConstants.supabaseAnonKey}',
        'apikey': ApiConstants.supabaseAnonKey,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Xóa ảnh trên Supabase thất bại (${response.statusCode}): ${response.body}',
      );
    }
  }

  void _ensureConfigured() {
    if (!ApiConstants.isSupabaseConfigured) {
      throw Exception(
        'Supabase chưa được cấu hình. Hãy cập nhật SUPABASE_URL và SUPABASE_ANON_KEY trong api_constants.dart.',
      );
    }
  }
}
