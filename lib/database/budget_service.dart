import 'database_helper.dart';
import '../models/budget.dart';

class BudgetService {
  final _db = DatabaseHelper.instance;

  Future<int> setBudget({
    required int ledgerId,
    required String category,
    required double amount,
    String period = 'monthly',
    double alertThreshold = 0.8,
  }) async {
    final db = await _db.database;
    // Check if budget for this category already exists
    final existing = await db.query(
      'budgets',
      where: 'ledger_id = ? AND category = ?',
      whereArgs: [ledgerId, category],
    );
    if (existing.isNotEmpty) {
      await db.update('budgets', {
        'amount': amount,
        'alert_threshold': alertThreshold,
      }, where: 'id = ?', whereArgs: [existing.first['id']]);
      return existing.first['id'] as int;
    }
    return await db.insert('budgets', {
      'ledger_id': ledgerId,
      'category': category,
      'amount': amount,
      'period': period,
      'alert_threshold': alertThreshold,
    });
  }

  Future<void> deleteBudget(int id) async {
    final db = await _db.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Budget>> getBudgets(int ledgerId) async {
    final db = await _db.database;
    final result = await db.query('budgets', where: 'ledger_id = ?', whereArgs: [ledgerId]);
    return result.map((map) => Budget.fromMap(map)).toList();
  }

  Future<List<BudgetAlert>> getBudgetAlerts(int ledgerId, int year, int month) async {
    final budgets = await getBudgets(ledgerId);
    if (budgets.isEmpty) return [];

    final db = await _db.database;
    final m = month.toString().padLeft(2, '0');
    final start = '$year-$m-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = '$year-$m-${lastDay.toString().padLeft(2, '0')}';

    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as spent FROM bills
      WHERE ledger_id = ? AND type = 'expense' AND date >= ? AND date <= ?
      GROUP BY category
    ''', [ledgerId, start, end]);

    final spentMap = <String, double>{};
    for (final row in result) {
      spentMap[row['category'] as String] = (row['spent'] as num).toDouble();
    }

    return budgets.map((b) {
      final spent = spentMap[b.category] ?? 0;
      return BudgetAlert(
        category: b.category,
        spent: spent,
        budgetAmount: b.amount,
        threshold: b.alertThreshold,
      );
    }).toList();
  }
}
