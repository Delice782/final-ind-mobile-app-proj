import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('datasphere.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,              // ✅ bumped from 1 to 2
      onCreate: _createDB,
      onUpgrade: _upgradeDB,   // ✅ added
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        building TEXT,
        room TEXT,
        category TEXT,
        description TEXT,
        photo TEXT,
        audio TEXT,            
        status TEXT DEFAULT 'Pending',
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  // ✅ NEW: adds audio column to existing installs
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE offline_reports ADD COLUMN audio TEXT');
    }
  }

  Future<int> insertReport(Map<String, dynamic> report) async {
    final db = await database;
    return await db.insert('offline_reports', report);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedReports() async {
    final db = await database;
    return await db.query('offline_reports', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> getAllLocalReports(int userId) async {
    final db = await database;
    return await db.query('offline_reports',
        where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update('offline_reports', {'synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }
}