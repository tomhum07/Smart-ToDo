/// Cấu hình URL và khóa kết nối các dịch vụ bên ngoài.
/// Các giá trị placeholder sẽ được cập nhật khi deploy Render & gắn key Supabase.
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

  // --- .NET Web API (Deploy Render) ---
  static const String dotnetBaseUrl = String.fromEnvironment(
    'DOTNET_API_URL',
    defaultValue: 'https://smart-todo-zkzs.onrender.com',
  );

  static bool get isDotNetConfigured =>
      dotnetBaseUrl.startsWith('http') &&
      dotnetBaseUrl != 'YOUR_DOTNET_API_URL';

  static String get _base => dotnetBaseUrl.endsWith('/')
      ? dotnetBaseUrl.substring(0, dotnetBaseUrl.length - 1)
      : dotnetBaseUrl;

  static String get dotnetHealthUrl => '$_base/api/health';
  static String get dotnetSharesUrl => '$_base/api/shares';
  static String dotnetShareByCodeUrl(String code) => '$_base/api/shares/$code';

  // Shared Workspace REST Endpoints
  static String get workspacesUrl => '$_base/api/workspaces';
  static String myWorkspacesUrl(String userUid) =>
      '$_base/api/workspaces?userUid=${Uri.encodeQueryComponent(userUid)}';
  static String get joinWorkspaceUrl => '$_base/api/workspaces/join';
  static String leaveWorkspaceUrl(String id, String userUid) =>
      '$_base/api/workspaces/$id/leave?userUid=${Uri.encodeQueryComponent(userUid)}';
  static String kickWorkspaceMemberUrl(
    String id,
    String targetUid,
    String requesterUid,
  ) =>
      '$_base/api/workspaces/$id/members/${Uri.encodeComponent(targetUid)}?requesterUid=${Uri.encodeQueryComponent(requesterUid)}';
  static String workspaceOverviewUrl(String id) =>
      '$_base/api/workspaces/$id/overview';
  static String workspaceSchedulesUrl(String id) =>
      '$_base/api/workspaces/$id/schedules';
  static String workspaceScheduleItemUrl(String id, String scheduleId) =>
      '$_base/api/workspaces/$id/schedules/$scheduleId';
  static String workspaceTasksUrl(String id) =>
      '$_base/api/workspaces/$id/tasks';
  static String workspaceTaskItemUrl(String id, String taskId) =>
      '$_base/api/workspaces/$id/tasks/$taskId';
  static String workspaceTaskToggleUrl(String id, String taskId) =>
      '$_base/api/workspaces/$id/tasks/$taskId/toggle';
  static String workspaceNotesUrl(String id) =>
      '$_base/api/workspaces/$id/notes';
  static String workspaceNoteItemUrl(String id, String noteId) =>
      '$_base/api/workspaces/$id/notes/$noteId';
}
