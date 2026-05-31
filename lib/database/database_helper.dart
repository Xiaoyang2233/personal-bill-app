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
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA foreign_keys=ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ledgers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT DEFAULT '📒',
        color TEXT DEFAULT '#4A90D9',
        created_at TEXT DEFAULT (datetime('now','localtime')),
        updated_at TEXT DEFAULT (datetime('now','localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('expense','income')),
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        note TEXT DEFAULT '',
        date TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now','localtime')),
        updated_at TEXT DEFAULT (datetime('now','localtime')),
        FOREIGN KEY (ledger_id) REFERENCES ledgers(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        period TEXT DEFAULT 'monthly',
        alert_threshold REAL DEFAULT 0.8,
        FOREIGN KEY (ledger_id) REFERENCES ledgers(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create default ledger
    await db.insert('ledgers', {
      'name': '个人账本',
      'icon': '📒',
      'color': '#4A90D9',
    });

    // Insert default settings
    final defaultSettings = {
      'theme_mode': 'system',
      'background_type': 'color',
      'background_color': '#F5F7FA',
      'background_image': '',
      'background_opacity': '0.5',
      'chart_mode': 'pie',
    };
    for (final entry in defaultSettings.entries) {
      await db.insert('settings', {
        'key': entry.key,
        'value': entry.value,
      });
    }

    // Insert default categories
    final defaultExpenseCategories = [
      {'label': '餐饮', 'icon': '🍔', 'color': '#FF6384'},
      {'label': '交通', 'icon': '🚌', 'color': '#36A2EB'},
      {'label': '购物', 'icon': '🛒', 'color': '#FFCE56'},
      {'label': '住房', 'icon': '🏠', 'color': '#4BC0C0'},
      {'label': '娱乐', 'icon': '🎮', 'color': '#9966FF'},
      {'label': '医疗', 'icon': '💊', 'color': '#FF9F40'},
      {'label': '教育', 'icon': '📚', 'color': '#7BC8A4'},
      {'label': '通讯', 'icon': '📱', 'color': '#E8A87C'},
      {'label': '日用', 'icon': '🧴', 'color': '#95A5A6'},
      {'label': '其他', 'icon': '📌', 'color': '#C9CBCF'},
    ];
    final defaultIncomeCategories = [
      {'label': '工资', 'icon': '💰', 'color': '#2ECC71'},
      {'label': '奖金', 'icon': '🎁', 'color': '#3498DB'},
      {'label': '投资', 'icon': '📈', 'color': '#9B59B6'},
      {'label': '兼职', 'icon': '💼', 'color': '#1ABC9C'},
      {'label': '报销', 'icon': '↩️', 'color': '#E67E22'},
      {'label': '其他', 'icon': '📌', 'color': '#95A5A6'},
    ];

    await db.insert('settings', {
      'key': 'custom_categories_expense',
      'value': jsonEncode(defaultExpenseCategories.map((c) => {...c, 'isDefault': true}).toList()),
    });
    await db.insert('settings', {
      'key': 'custom_categories_income',
      'value': jsonEncode(defaultIncomeCategories.map((c) => {...c, 'isDefault': true}).toList()),
    });
  }

  Future<String> getSetting(String key) async {
    final db = await database;
    final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (result.isEmpty) return '';
    return result.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'finance_app.db');
  }
}
