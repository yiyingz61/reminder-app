import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/schedule.dart';
import '../models/todo.dart';

/// SQLite 持久化层：负责建库、建表以及对日程/待办的增删改查。
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'reminder.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        note TEXT,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER,
        day_key TEXT NOT NULL,
        all_day INTEGER NOT NULL DEFAULT 0,
        color INTEGER NOT NULL,
        done INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_schedule_day ON schedules(day_key)');
    await db.execute('''
      CREATE TABLE todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 0,
        created_ms INTEGER NOT NULL,
        due_ms INTEGER
      )
    ''');
  }

  // ---------------- 日程 ----------------

  Future<int> insertSchedule(Schedule s) async {
    final db = await database;
    return db.insert('schedules', s.toMap()..remove('id'));
  }

  Future<int> updateSchedule(Schedule s) async {
    final db = await database;
    return db.update('schedules', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  /// 取某一天的全部日程，按开始时间升序。
  Future<List<Schedule>> schedulesForDay(DateTime day) async {
    final db = await database;
    final key =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final rows = await db.query('schedules',
        where: 'day_key = ?', whereArgs: [key], orderBy: 'all_day DESC, start_ms ASC');
    return rows.map(Schedule.fromMap).toList();
  }

  /// 返回某月内有日程的所有 day_key，用于日历圆点标记。
  Future<Set<String>> daysWithSchedulesInMonth(DateTime month) async {
    final db = await database;
    final first = DateTime(month.year, month.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    final rows = await db.query('schedules',
        columns: ['DISTINCT day_key'],
        where: 'start_ms >= ? AND start_ms < ?',
        whereArgs: [first.millisecondsSinceEpoch, next.millisecondsSinceEpoch]);
    return rows.map((r) => r['day_key'] as String).toSet();
  }

  // ---------------- 待办 ----------------

  Future<int> insertTodo(Todo t) async {
    final db = await database;
    return db.insert('todos', t.toMap()..remove('id'));
  }

  Future<int> updateTodo(Todo t) async {
    final db = await database;
    return db.update('todos', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<int> deleteTodo(int id) async {
    final db = await database;
    return db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  /// 待办列表：未完成在前，再按优先级高到低、创建时间新到旧。
  Future<List<Todo>> allTodos() async {
    final db = await database;
    final rows = await db.query('todos',
        orderBy: 'done ASC, priority DESC, created_ms DESC');
    return rows.map(Todo.fromMap).toList();
  }
}
