import 'database_helper.dart';
import '../models/pending_transaction.dart';
import '../providers/auto_bookkeeping_provider.dart';

class PendingTransactionService {
  final _db = DatabaseHelper.instance;

  Future<int> insert(ParsedNotification notification) async {
    final db = await _db.database;
    return await db.insert('pending_transactions', {
      'package_name': notification.packageName,
      'source_name': notification.sourceName,
      'title': notification.title,
      'text': notification.text,
      'amount': notification.amount,
      'type': notification.type,
      'merchant': notification.merchant,
      'suggested_category': notification.suggestedCategory,
      'status': 'pending',
    });
  }

  Future<List<PendingTransaction>> getPending() async {
    final db = await _db.database;
    final result = await db.query(
      'pending_transactions',
      where: "status = 'pending'",
      orderBy: 'created_at DESC',
    );
    return result.map((map) => PendingTransaction.fromMap(map)).toList();
  }

  Future<List<PendingTransaction>> getAll() async {
    final db = await _db.database;
    final result = await db.query(
      'pending_transactions',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => PendingTransaction.fromMap(map)).toList();
  }

  Future<void> updateStatus(int id, String status) async {
    final db = await _db.database;
    await db.update(
      'pending_transactions',
      {
        'status': status,
        'updated_at': DateTime.now().toString(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getPendingCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM pending_transactions WHERE status = 'pending'",
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> deleteOlderThan(int days) async {
    final db = await _db.database;
    final threshold = DateTime.now().subtract(Duration(days: days)).toString();
    await db.delete(
      'pending_transactions',
      where: 'created_at < ?',
      whereArgs: [threshold],
    );
  }
}
