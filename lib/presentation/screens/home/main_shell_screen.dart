import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/models/holiday_model.dart';
import '../../../data/remote/holiday_api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';

/// Khung giao diện chính gồm 4 Tab: Công việc, Ghi chú, Lịch trình, Thống kê & Tài khoản.
/// Tự động thích ứng xoay dọc (NavigationBar) / xoay ngang (NavigationRail) qua OrientationBuilder.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  Future<List<HolidayModel>>? _holidaysFuture;
  final HolidayApiService _holidayApiService = HolidayApiService();

  static const _titles = [
    'Công việc',
    'Ghi chú',
    'Lịch trình',
    'Thống kê & Tài khoản',
  ];

  Future<List<HolidayModel>> _getHolidaysFuture() {
    return _holidaysFuture ??=
        _holidayApiService.fetchVietnamHolidays(DateTime.now().year);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;
        final bodyContent = _buildCurrentTab();

        return Scaffold(
          appBar: AppBar(
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_titles[_selectedIndex]),
            ),
            actions: [
              IconButton(
                tooltip: themeProvider.isDarkMode
                    ? 'Chuyển sang giao diện Sáng'
                    : 'Chuyển sang giao diện Tối',
                onPressed: () => themeProvider.toggleTheme(),
                icon: Icon(
                  themeProvider.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
                ),
              ),
            ],
          ),
          body: isLandscape
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (i) =>
                          setState(() => _selectedIndex = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.listTodo),
                          label: Text('Công việc'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.stickyNote),
                          label: Text('Ghi chú'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.calendarDays),
                          label: Text('Lịch trình'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(LucideIcons.chartColumn),
                          label: Text('Thống kê'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: bodyContent),
                  ],
                )
              : bodyContent,
          bottomNavigationBar: isLandscape
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(LucideIcons.listTodo),
                      label: 'Công việc',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.stickyNote),
                      label: 'Ghi chú',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.calendarDays),
                      label: 'Lịch trình',
                    ),
                    NavigationDestination(
                      icon: Icon(LucideIcons.chartColumn),
                      label: 'Thống kê',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedIndex) {
      case 0:
        return _PhasePlaceholderTab(
          icon: LucideIcons.listTodo,
          title: 'Tab Công việc (Todo)',
          description:
              'Bảng SQLite "tasks" và TaskModel đã sẵn sàng. Giao diện CRUD, lọc nâng cao và nhắc hạn chót sẽ được triển khai ở Phase 2.',
        );
      case 1:
        return _PhasePlaceholderTab(
          icon: LucideIcons.stickyNote,
          title: 'Tab Ghi chú (Notes)',
          description:
              'Bảng SQLite "notes", NoteModel và SupabaseStorageService đã sẵn sàng. Lưới 2/3 cột (OrientationBuilder) & trình soạn thảo sẽ triển khai ở Phase 2.',
        );
      case 2:
        return _buildSchedulePreviewTab();
      default:
        return _buildStatsProfileTab();
    }
  }

  /// Tab Lịch trình tích hợp trước FutureBuilder gọi Nager.Date Public API (Smoke Test Phase 1).
  Widget _buildSchedulePreviewTab() {
    final shadTheme = ShadTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ShadCard(
          title: const Text('Ngày lễ Việt Nam (Nager.Date REST API)'),
          description: Text(
            'Kiểm thử kết nối HTTP GET + jsonDecode() + FutureBuilder cho năm ${DateTime.now().year}.',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FutureBuilder<List<HolidayModel>>(
              future: _getHolidaysFuture(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShadAlert.destructive(
                        icon: const Icon(LucideIcons.wifiOff),
                        title: const Text('Không tải được ngày lễ'),
                        description: Text('${snapshot.error}'),
                      ),
                      const SizedBox(height: 8),
                      ShadButton.outline(
                        onPressed: () => setState(() {
                          _holidaysFuture = _holidayApiService
                              .fetchVietnamHolidays(DateTime.now().year);
                        }),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  );
                }
                final holidays = snapshot.data ?? [];
                if (holidays.isEmpty) {
                  return const Text('Không có dữ liệu ngày lễ.');
                }
                return Column(
                  children: holidays.take(5).map((h) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.sparkles, size: 18),
                      title: Text(h.localName, style: shadTheme.textTheme.p),
                      subtitle: Text(h.name),
                      trailing: ShadBadge.secondary(
                        child: Text(DateFormatter.formatDate(h.date)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _PhasePlaceholderTab(
          icon: LucideIcons.calendarDays,
          title: 'Thời khóa biểu T2 – CN',
          description:
              'Bảng SQLite "schedules" và hợp đồng .NET Share API đã sẵn sàng cho Phase 2 & 3.',
          inline: true,
        ),
      ],
    );
  }

  /// Tab Thống kê & Tài khoản hiển thị trạng thái kết nối các dịch vụ Phase 1.
  Widget _buildStatsProfileTab() {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ShadCard(
          title: Text(auth.displayName),
          description: Text(auth.email),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Chế độ tối (Dark Mode)'),
                    ShadSwitch(
                      value: themeProvider.isDarkMode,
                      onChanged: (v) => themeProvider.toggleTheme(v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ShadButton.destructive(
                    onPressed: () => auth.signOut(),
                    child: const Text('Đăng xuất'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ShadCard(
          title: const Text('Trạng thái Hệ thống (Phase 1)'),
          description: const Text(
            'Theo dõi tình trạng cấu hình CSDL cục bộ & dịch vụ bên ngoài.',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                _StatusRow(
                  label: 'Firebase Auth & Realtime DB',
                  isReady: auth.isFirebaseReady,
                  pendingText: 'Chờ setup',
                ),
                const SizedBox(height: 8),
                _StatusRow(
                  label: 'Supabase Storage (Ảnh)',
                  isReady: ApiConstants.isSupabaseConfigured,
                  pendingText: 'Chờ key',
                ),
                const SizedBox(height: 8),
                _StatusRow(
                  label: '.NET Web API (Chia sẻ lịch)',
                  isReady: ApiConstants.isDotNetConfigured,
                  pendingText: 'Phase 3',
                ),
                const Divider(height: 24),
                FutureBuilder<Map<String, int>>(
                  future: DatabaseHelper.instance
                      .getTableCounts(auth.effectiveUserId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Đang kiểm tra SQLite cục bộ...');
                    }
                    if (snapshot.hasError) {
                      return Text('SQLite lỗi: ${snapshot.error}');
                    }
                    final counts = snapshot.data ?? {};
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat(
                          label: 'Tasks',
                          value: '${counts['tasks'] ?? 0}',
                        ),
                        _MiniStat(
                          label: 'Notes',
                          value: '${counts['notes'] ?? 0}',
                        ),
                        _MiniStat(
                          label: 'Schedules',
                          value: '${counts['schedules'] ?? 0}',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isReady;
  final String pendingText;

  const _StatusRow({
    required this.label,
    required this.isReady,
    required this.pendingText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        isReady
            ? const ShadBadge(child: Text('Đã kết nối'))
            : ShadBadge.outline(child: Text(pendingText)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.h4),
        Text(label, style: theme.textTheme.muted),
      ],
    );
  }
}

class _PhasePlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool inline;

  const _PhasePlaceholderTab({
    required this.icon,
    required this.title,
    required this.description,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = ShadCard(
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      description: Text(description),
    );

    if (inline) return card;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: card,
        ),
      ),
    );
  }
}
