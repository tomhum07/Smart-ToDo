/// Cấu hình URL và khóa kết nối các dịch vụ bên ngoài.
/// Các giá trị placeholder sẽ được cập nhật khi nhóm hoàn tất phần Setup bên ngoài.
class ApiConstants {
  ApiConstants._();

  // --- Supabase Storage (Free) ---
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );
  static const String supabaseNoteImagesBucket = 'note-images';

  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('http') &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      supabaseAnonKey.isNotEmpty;

  // --- Nager.Date Public Holidays API (Miễn phí, không cần API Key) ---
  static const String nagerDateBaseUrl = 'https://date.nager.at/api/v3';

  static String vietnamHolidaysUrl(int year) =>
      '$nagerDateBaseUrl/PublicHolidays/$year/VN';

  // --- .NET Web API (Deploy Cloud - Share/Import Schedule & Notes) ---
  static const String dotnetBaseUrl = String.fromEnvironment(
    'DOTNET_API_URL',
    defaultValue: 'YOUR_DOTNET_API_URL',
  );

  static bool get isDotNetConfigured =>
      dotnetBaseUrl.startsWith('http') &&
      dotnetBaseUrl != 'YOUR_DOTNET_API_URL';

  static String get dotnetHealthUrl => '$dotnetBaseUrl/api/health';
  static String get dotnetSharesUrl => '$dotnetBaseUrl/api/shares';
  static String dotnetShareByCodeUrl(String code) =>
      '$dotnetBaseUrl/api/shares/$code';
}
