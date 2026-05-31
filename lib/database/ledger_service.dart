import 'database_helper.dart';
import '../models/ledger.dart';

class LedgerService {
  final _db = DatabaseHelper.instance;

  Future<int> createLedger(String name, {String icon = '📒', String color = '#4A90D9'}) async {
    final db = await _db.database;
    return await db.insert('ledgers', {
      'name': name,
      'icon': icon,
      'color': color,
    });
  }

  Future<void> updateLedger(int id, String name) async {
    final db = await _db.database;
    final now = DateTime.now();
    final ts = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')} '
        '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';
    await db.update('ledgers', {
      'name': name,
      'updated_at': ts,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteLedger(int id) async {
    final db = await _db.database;
    // Delete related bills and budgets
    await db.delete('bills', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('budgets', where: 'ledger_id = ?', whereArgs: [id]);
    await db.delete('ledgers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Ledger>> getLedgers() async {
    final db = await _db.database;
    final result = await db.query('ledgers', orderBy: 'id ASC');
    return result.map((map) => Ledger.fromMap(map)).toList();
  }

  Future<Ledger?> getLedgerById(int id) async {
    final db = await _db.database;
    final result = await db.query('ledgers', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Ledger.fromMap(result.first);
  }
}
