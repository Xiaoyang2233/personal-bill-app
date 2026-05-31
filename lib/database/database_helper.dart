import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finance_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ledgers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT DEFAULT '📒',
        color TEXT DEFAULT '#4A90D9',
        created_at TEXT DEFAULT (datetime('now','localtime')),
        updated_at TEXT DEFAULT (datetime('now','localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('expense','income')),
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT DEFAULT '',
        date TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now','localtime')),
        updated_at TEXT DEFAULT (datetime('now','localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        period TEXT DEFAULT 'monthly',
        alert_threshold REAL DEFAULT 0.8
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create default ledger if none exists
    final existingLedgers = await db.query('ledgers');
    if (existingLedgers.isEmpty) {
      await db.insert('ledgers', {
        'name': '个人账本',
        'icon': '📒',
        'color': '#4A90D9',
      });
    }

    // Insert default settings if not present
    final defaultSettings = {
      'theme_mode': 'system',
      'background_type': 'color',
      'background_color': '#F5F7FA',
      'background_image': '',
      'background_opacity': '0.5',
      'chart_mode': 'pie',
    };
    for (final entry in defaultSettings.entries) {
      final exists = await db.query('settings', where: 'key = ?', whereArgs: [entry.key]);
      if (exists.isEmpty) {
        await db.insert('settings', {'key': entry.key, 'value': entry.value});
      }
    }

    // Insert default categories if not present
    final catsExist = await db.query('settings', where: 'key = ?', whereArgs: ['custom_categories_expense']);
    if (catsExist.isEmpty) {
      final defaultExpenseCategories = [
        {'label': '餐饮', 'icon': '🍔', 'color': '#FF6384', 'isDefault': true},
        {'label': '交通', 'icon': '🚌', 'color': '#36A2EB', 'isDefault': true},
        {'label': '购物', 'icon': '🛒', 'color': '#FFCE56', 'isDefault': true},
        {'label': '娱乐', 'icon': '🎮', 'color': '#9966FF', 'isDefault': true},
        {'label': '其他', 'icon': '📌', 'color': '#C9CBCF', 'isDefault': true},
      ];
      final defaultIncomeCategories = [
        {'label': '工资', 'icon': '💰', 'color': '#2ECC71', 'isDefault': true},
        {'label': '转账', 'icon': '↩️', 'color': '#E67E22', 'isDefault': true},
        {'label': '其他', 'icon': '📌', 'color': '#95A5A6', 'isDefault': true},
      ];

      await db.insert('settings', {
        'key': 'custom_categories_expense',
        'value': jsonEncode(defaultExpenseCategories),
      });
      await db.insert('settings', {
        'key': 'custom_categories_income',
        'value': jsonEncode(defaultIncomeCategories),
      });
    }
  }

  Future<String> getSetting(String key) async {
    try {
      final db = await database;
      final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
      if (result.isEmpty) return '';
      return result.first['value'] as String;
    } catch (_) {
      return '';
    }
  }

  Future<void> setSetting(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Silently fail - settings will use SharedPreferences fallback
    }
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'finance_app.db');
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
