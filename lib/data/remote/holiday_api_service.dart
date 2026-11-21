import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/holiday_model.dart';

/// Dịch vụ gọi Nager.Date Public API lấy danh sách ngày nghỉ lễ Việt Nam.
class HolidayApiService {
  final http.Client _client;

  HolidayApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<HolidayModel>> fetchVietnamHolidays(int year) async {
    final uri = Uri.parse(ApiConstants.vietnamHolidaysUrl(year));
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) {
        return decoded
            .map((item) => HolidayModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    throw Exception('Không thể tải ngày lễ Việt Nam (${response.statusCode}).');
  }
}
