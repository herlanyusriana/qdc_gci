import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/downtime.dart';
import '../models/hourly_report.dart';
import '../models/qdc_session.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'qdc_gci.db');
    return openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downtimes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            machineId INTEGER NOT NULL,
            machineName TEXT NOT NULL,
            shift TEXT NOT NULL,
            operatorName TEXT NOT NULL DEFAULT '',
            startTime TEXT NOT NULL,
            endTime TEXT,
            durationMinutes INTEGER,
            reason TEXT NOT NULL,
            notes TEXT,
            refillPartNo TEXT,
            refillPartName TEXT,
            refillQty REAL,
            productionOrderId INTEGER,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE hourly_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productionOrderId INTEGER NOT NULL,
            timeRange TEXT NOT NULL,
            target INTEGER NOT NULL DEFAULT 0,
            actual INTEGER NOT NULL DEFAULT 0,
            ng INTEGER NOT NULL DEFAULT 0,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE qdc_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            machineId INTEGER NOT NULL,
            machineName TEXT NOT NULL,
            shift TEXT NOT NULL,
            operatorName TEXT NOT NULL DEFAULT '',
            partFrom TEXT,
            partTo TEXT,
            startTime TEXT NOT NULL,
            endTime TEXT NOT NULL,
            durationSeconds INTEGER NOT NULL,
            internalSeconds INTEGER DEFAULT 0,
            externalSeconds INTEGER DEFAULT 0,
            notes TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              "ALTER TABLE downtimes ADD COLUMN operatorName TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 3) {
          await db.execute(
              'ALTER TABLE downtimes ADD COLUMN refillPartNo TEXT');
          await db.execute(
              'ALTER TABLE downtimes ADD COLUMN refillPartName TEXT');
          await db.execute(
              'ALTER TABLE downtimes ADD COLUMN refillQty REAL');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS hourly_reports (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              productionOrderId INTEGER NOT NULL,
              timeRange TEXT NOT NULL,
              target INTEGER NOT NULL DEFAULT 0,
              actual INTEGER NOT NULL DEFAULT 0,
              ng INTEGER NOT NULL DEFAULT 0,
              synced INTEGER DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS qdc_sessions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              machineId INTEGER NOT NULL,
              machineName TEXT NOT NULL,
              shift TEXT NOT NULL,
              operatorName TEXT NOT NULL DEFAULT '',
              partFrom TEXT,
              partTo TEXT,
              startTime TEXT NOT NULL,
              endTime TEXT NOT NULL,
              durationSeconds INTEGER NOT NULL,
              internalSeconds INTEGER DEFAULT 0,
              externalSeconds INTEGER DEFAULT 0,
              notes TEXT,
              synced INTEGER DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute(
              'ALTER TABLE downtimes ADD COLUMN productionOrderId INTEGER');
        }
      },
    );
  }

  // ─── Downtimes ───
  static Future<int> insertDowntime(Downtime dt) async {
    final db = await database;
    return db.insert('downtimes', dt.toMap()..remove('id'));
  }

  static Future<void> updateDowntime(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('downtimes', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<Downtime?> getActiveDowntime(int machineId) async {
    final db = await database;
    final results = await db.query(
      'downtimes',
      where: 'machineId = ? AND endTime IS NULL',
      whereArgs: [machineId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Downtime.fromMap(results.first);
  }

  static Future<List<Downtime>> getTodayDowntimes(int machineId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final results = await db.query(
      'downtimes',
      where: 'machineId = ? AND startTime LIKE ?',
      whereArgs: [machineId, '$today%'],
      orderBy: 'id DESC',
    );
    return results.map((m) => Downtime.fromMap(m)).toList();
  }

  static Future<List<Downtime>> getUnsyncedDowntimes() async {
    final db = await database;
    final results = await db.query('downtimes',
        where: 'synced = 0 AND endTime IS NOT NULL');
    return results.map((m) => Downtime.fromMap(m)).toList();
  }

  static Future<void> markDowntimeSynced(int id) async {
    final db = await database;
    await db.update('downtimes', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ─── Hourly Reports ───
  static Future<int> insertHourlyReport(HourlyReport hr) async {
    final db = await database;
    return db.insert('hourly_reports', hr.toMap()..remove('id'));
  }

  static Future<void> updateHourlyReport(int id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('hourly_reports', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<HourlyReport?> getHourlyReport(int productionOrderId, String timeRange) async {
    final db = await database;
    final results = await db.query(
      'hourly_reports',
      where: 'productionOrderId = ? AND timeRange = ?',
      whereArgs: [productionOrderId, timeRange],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return HourlyReport.fromMap(results.first);
  }

  static Future<List<HourlyReport>> getHourlyReportsFor(int productionOrderId) async {
    final db = await database;
    final results = await db.query(
      'hourly_reports',
      where: 'productionOrderId = ?',
      whereArgs: [productionOrderId],
      orderBy: 'timeRange ASC',
    );
    return results.map((m) => HourlyReport.fromMap(m)).toList();
  }

  static Future<List<HourlyReport>> getUnsyncedHourlyReports() async {
    final db = await database;
    final results = await db.query('hourly_reports', where: 'synced = 0');
    return results.map((m) => HourlyReport.fromMap(m)).toList();
  }

  static Future<void> markHourlyReportSynced(int id) async {
    final db = await database;
    await db.update('hourly_reports', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ─── QDC Sessions ───
  static Future<int> insertQdcSession(QdcSession qs) async {
    final db = await database;
    return db.insert('qdc_sessions', qs.toMap()..remove('id'));
  }

  static Future<List<QdcSession>> getTodayQdcSessions(int machineId) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final results = await db.query(
      'qdc_sessions',
      where: 'machineId = ? AND startTime LIKE ?',
      whereArgs: [machineId, '$today%'],
      orderBy: 'id DESC',
    );
    return results.map((m) => QdcSession.fromMap(m)).toList();
  }

  static Future<List<QdcSession>> getUnsyncedQdcSessions() async {
    final db = await database;
    final results = await db.query('qdc_sessions', where: 'synced = 0');
    return results.map((m) => QdcSession.fromMap(m)).toList();
  }

  static Future<void> markQdcSessionSynced(int id) async {
    final db = await database;
    await db.update('qdc_sessions', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }
}
