import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/local/database_helper.dart';
import '../data/models/task_model.dart';
import '../data/services/notification_service.dart';

enum TaskStatusFilter { all, active, completed }

enum TaskSortOption { dueDate, createdAt, priority }

/// Quản lý trạng thái, tìm kiếm, lọc và CRUD Công việc Todo (Offline-first Sqflite).
class TaskProvider extends ChangeNotifier {
  final DatabaseHelper _db;
  final NotificationService _notifications;
  final Uuid _uuid = const Uuid();

  List<TaskModel> _tasks = [];
  bool _isLoading = false;
  String? _loadedUserId;

  String _searchQuery = '';
  String _selectedCategory = 'Tất cả';
  int? _selectedPriority; // null = tất cả, 0 = Low, 1 = Medium, 2 = High
  TaskStatusFilter _statusFilter = TaskStatusFilter.all;
  // Mặc định sắp xếp theo Mức độ ưu tiên Cao -> Trung bình -> Thấp
  TaskSortOption _sortOption = TaskSortOption.priority;

  TaskProvider({
    DatabaseHelper? db,
    NotificationService? notifications,
  })  : _db = db ?? DatabaseHelper.instance,
        _notifications = notifications ?? NotificationService.instance;

  bool get isLoading => _isLoading;
  List<TaskModel> get allTasks => List.unmodifiable(_tasks);
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  int? get selectedPriority => _selectedPriority;
  TaskStatusFilter get statusFilter => _statusFilter;
  TaskSortOption get sortOption => _sortOption;

  int get activeFilterCount {
    var count = 0;
    if (_selectedCategory != 'Tất cả') count++;
    if (_selectedPriority != null) count++;
    if (_statusFilter != TaskStatusFilter.all) count++;
    if (_sortOption != TaskSortOption.priority) count++;
    return count;
  }

  int get totalCount => _tasks.length;
  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get overdueCount {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _tasks
        .where((t) => !t.isCompleted && t.dueDate != null && t.dueDate! < now)
        .length;
  }

  /// Danh sách công việc đã áp dụng tìm kiếm, lọc và sắp xếp.
  List<TaskModel> get filteredTasks {
    final query = _searchQuery.trim().toLowerCase();
    final list = _tasks.where((task) {
      if (query.isNotEmpty) {
        final matchTitle = task.title.toLowerCase().contains(query);
        final matchDesc = task.description.toLowerCase().contains(query);
        if (!matchTitle && !matchDesc) return false;
      }
      if (_selectedCategory != 'Tất cả' && task.category != _selectedCategory) {
        return false;
      }
      if (_selectedPriority != null && task.priority != _selectedPriority) {
        return false;
      }
      if (_statusFilter == TaskStatusFilter.active && task.isCompleted) {
        return false;
      }
      if (_statusFilter == TaskStatusFilter.completed && !task.isCompleted) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      // Công việc chưa hoàn thành luôn hiển thị trước đã hoàn thành
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      switch (_sortOption) {
        case TaskSortOption.dueDate:
          if (a.dueDate == null && b.dueDate == null) {
            return b.updatedAt.compareTo(a.updatedAt);
          }
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        case TaskSortOption.priority:
          final cmp = b.priority.compareTo(a.priority);
          if (cmp != 0) return cmp;
          if (a.dueDate != null && b.dueDate != null) {
            return a.dueDate!.compareTo(b.dueDate!);
          }
          if (a.dueDate != null) return -1;
          if (b.dueDate != null) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        case TaskSortOption.createdAt:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return list;
  }

  Future<void> loadTasks(String userId, {bool force = false}) async {
    if (!force && _loadedUserId == userId) return;
    _isLoading = true;
    _loadedUserId = userId;
    notifyListeners();

    try {
      _tasks = await _db.getTasksByUser(userId);
    } catch (e) {
      debugPrint('Lỗi tải danh sách công việc: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setPriority(int? priority) {
    _selectedPriority = priority;
    notifyListeners();
  }

  void setStatusFilter(TaskStatusFilter status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSortOption(TaskSortOption sort) {
    _sortOption = sort;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = 'Tất cả';
    _selectedPriority = null;
    _statusFilter = TaskStatusFilter.all;
    _sortOption = TaskSortOption.priority;
    notifyListeners();
  }

  Future<void> addTask({
    required String userId,
    required String title,
    String description = '',
    required String category,
    required int priority,
    int? dueDate,
    int remindBeforeMinutes = 10,
    int repeatIntervalSeconds = 60,
    int repeatCount = 1,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final task = TaskModel(
      id: _uuid.v4(),
      userId: userId,
      title: title.trim(),
      description: description.trim(),
      category: category,
      priority: priority,
      isCompleted: false,
      dueDate: dueDate,
      remindBeforeMinutes: remindBeforeMinutes,
      repeatIntervalSeconds: repeatIntervalSeconds,
      repeatCount: repeatCount,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      isSynced: false,
    );

    await _db.upsertTask(task);
    await _notifications.scheduleTaskReminder(task);
    await loadTasks(userId, force: true);
  }

  Future<void> updateTask(TaskModel updated) async {
    final saved = updated.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isSynced: false,
    );
    await _db.upsertTask(saved);
    await _notifications.scheduleTaskReminder(saved);
    await loadTasks(saved.userId, force: true);
  }

  Future<void> toggleTaskCompletion(TaskModel task) async {
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      isSynced: false,
    );
    await _db.upsertTask(updated);
    if (updated.isCompleted) {
      await _notifications.cancelTaskReminder(updated.id);
    } else {
      await _notifications.scheduleTaskReminder(updated);
    }
    await loadTasks(updated.userId, force: true);
  }

  Future<void> deleteTask(TaskModel task) async {
    await _db.softDeleteTask(task.id);
    await _notifications.cancelTaskReminder(task.id);
    await loadTasks(task.userId, force: true);
  }
}
