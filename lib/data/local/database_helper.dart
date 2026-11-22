import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/note_model.dart';
import '../models/schedule_model.dart';
import '../models/task_model.dart';

/// Singleton quản lý CSDL SQLite cục bộ (sqflite) cho 3 bảng: tasks, notes, schedules.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'smart_todo.db';
  static const int _dbVersion = 3;

  static const String tableTasks = 'tasks';
  static const String tableNotes = 'notes';
  static const String tableSchedules = 'schedules';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableTasks ADD COLUMN repeat_interval_seconds INTEGER DEFAULT 60',
      );
      await db.execute(
        'ALTER TABLE $tableTasks ADD COLUMN repeat_count INTEGER DEFAULT 1',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $tableTasks ADD COLUMN schedule_id TEXT',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_schedule ON $tableTasks (schedule_id, is_deleted)',
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTasks (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        schedule_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        priority INTEGER NOT NULL,
        is_completed INTEGER NOT NULL,
        due_date INTEGER,
        remind_before_minutes INTEGER DEFAULT 10,
        repeat_interval_seconds INTEGER DEFAULT 60,
        repeat_count INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableNotes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        priority INTEGER NOT NULL,
        category TEXT NOT NULL,
        local_image_path TEXT,
        remote_image_url TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSchedules (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        location TEXT,
        note TEXT,
        color_hex TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_tasks_user ON $tableTasks (user_id, is_deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_notes_user ON $tableNotes (user_id, is_deleted)',
    );
    await db.execute(
      'CREATE INDEX idx_schedules_user ON $tableSchedules (user_id, day_of_week, is_deleted)',
    );
  }

  // ==================== CRUD TASKS ====================

  Future<void> upsertTask(TaskModel task) async {
    final db = await database;
    await db.insert(
      tableTasks,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TaskModel>> getTasksByUser(String userId) async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'is_completed ASC, due_date ASC, priority DESC, updated_at DESC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<void> softDeleteTask(String taskId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      tableTasks,
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<List<TaskModel>> getUnsyncedTasks(String userId) async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<TaskModel?> getTaskById(String taskId) async {
    final db = await database;
    final rows = await db.query(
      tableTasks,
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TaskModel.fromMap(rows.first);
  }

  Future<void> markTaskSynced(String taskId) async {
    final db = await database;
    await db.update(
      tableTasks,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // ==================== CRUD NOTES ====================

  Future<void> upsertNote(NoteModel note) async {
    final db = await database;
    await db.insert(
      tableNotes,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<NoteModel>> getNotesByUser(String userId) async {
    final db = await database;
    final rows = await db.query(
      tableNotes,
      where: 'user_id = ? AND is_deleted = 0',
      whereArgs: [userId],
      orderBy: 'priority DESC, updated_at DESC',
    );
    return rows.map(NoteModel.fromMap).toList();
  }

  Future<void> softDeleteNote(String noteId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      tableNotes,
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  Future<List<NoteModel>> getUnsyncedNotes(String userId) async {
    final db = await database;
    final rows = await db.query(
      tableNotes,
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return rows.map(NoteModel.fromMap).toList();
  }

  Future<NoteModel?> getNoteById(String noteId) async {
    final db = await database;
    final rows = await db.query(
      tableNotes,
      where: 'id = ?',
      whereArgs: [noteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return NoteModel.fromMap(rows.first);
  }

  Future<void> markNoteSynced(String noteId) async {
    final db = await database;
    await db.update(
      tableNotes,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  // ==================== CRUD SCHEDULES ====================

  Future<void> upsertSchedule(ScheduleModel schedule) async {
    final db = await database;
    await db.insert(
      tableSchedules,
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScheduleModel>> getSchedulesByUser(
    String userId, {
    int? dayOfWeek,
  }) async {
    final db = await database;
    final where = dayOfWeek == null
        ? 'user_id = ? AND is_deleted = 0'
        : 'user_id = ? AND day_of_week = ? AND is_deleted = 0';
    final whereArgs = dayOfWeek == null ? [userId] : [userId, dayOfWeek];

    final rows = await db.query(
      tableSchedules,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'day_of_week ASC, start_time ASC',
    );
    return rows.map(ScheduleModel.fromMap).toList();
  }

  Future<void> softDeleteSchedule(String scheduleId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      tableSchedules,
      {'is_deleted': 1, 'is_synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  Future<List<ScheduleModel>> getUnsyncedSchedules(String userId) async {
    final db = await database;
    final rows = await db.query(
      tableSchedules,
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );
    return rows.map(ScheduleModel.fromMap).toList();
  }

  Future<ScheduleModel?> getScheduleById(String scheduleId) async {
    final db = await database;
    final rows = await db.query(
      tableSchedules,
      where: 'id = ?',
      whereArgs: [scheduleId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ScheduleModel.fromMap(rows.first);
  }

  Future<void> markScheduleSynced(String scheduleId) async {
    final db = await database;
    await db.update(
      tableSchedules,
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [scheduleId],
    );
  }

  /// Kiểm tra sức khỏe CSDL cục bộ cho Smoke Test Phase 1.
  Future<Map<String, int>> getTableCounts(String userId) async {
    final db = await database;
    final taskCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableTasks WHERE user_id = ? AND is_deleted = 0',
            [userId],
          ),
        ) ??
        0;
    final noteCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableNotes WHERE user_id = ? AND is_deleted = 0',
            [userId],
          ),
        ) ??
        0;
    final scheduleCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $tableSchedules WHERE user_id = ? AND is_deleted = 0',
            [userId],
          ),
        ) ??
        0;
    return {
      'tasks': taskCount,
      'notes': noteCount,
      'schedules': scheduleCount,
    };
  }
}
