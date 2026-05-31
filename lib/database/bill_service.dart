import 'database_helper.dart';
import '../models/bill.dart';

class BillService {
  final _db = DatabaseHelper.instance;

  Future<int> addBill({
    required int ledgerId,
    required String type,
    required double amount,
    required String category,
    String note = '',
    required String date,
  }) async {
    final db = await _db.database;
    return await db.insert('bills', {
      'ledger_id': ledgerId,
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date,
    });
  }

  Future<void> updateBill(int id, {
    String? type,
    double? amount,
    String? category,
    String? note,
    String? date,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final ts = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')} '
        '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';
    final updates = <String, dynamic>{
      'updated_at': ts,
    };
    if (type != null) updates['type'] = type;
    if (amount != null) updates['amount'] = amount;
    if (category != null) updates['category'] = category;
    if (note != null) updates['note'] = note;
    if (date != null) updates['date'] = date;

    await db.update('bills', updates, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteBill(int id) async {
    final db = await _db.database;
    await db.delete('bills', where: 'id = ?', whereArgs: [id]);
  }

  Future<Bill?> getBillById(int id) async {
    final db = await _db.database;
    final result = await db.query('bills', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Bill.fromMap(result.first);
  }

  Future<List<Bill>> getBills(
    int ledgerId, {
    String? startDate,
    String? endDate,
    String? type,
    String? category,
    String? keyword,
    int? limit,
    int? offset,
  }) async {
    final db = await _db.database;
    final conditions = ['ledger_id = ?'];
    final whereArgs = <Object>[ledgerId];

    if (startDate != null) {
      conditions.add('date >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null) {
      conditions.add('date <= ?');
      whereArgs.add(endDate);
    }
    if (type != null) {
      conditions.add('type = ?');
      whereArgs.add(type);
    }
    if (category != null) {
      conditions.add('category = ?');
      whereArgs.add(category);
    }
    if (keyword != null && keyword.isNotEmpty) {
      conditions.add('note LIKE ?');
      whereArgs.add('%$keyword%');
    }

    final result = await db.query(
      'bills',
      where: conditions.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((map) => Bill.fromMap(map)).toList();
  }

  Future<MonthlyTotals> getMonthlyTotals(int ledgerId, int year, int month) async {
    final db = await _db.database;
    final m = month.toString().padLeft(2, '0');
    final start = '$year-$m-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = '$year-$m-${lastDay.toString().padLeft(2, '0')}';

    final result = await db.rawQuery('''
      SELECT type, SUM(amount) as total FROM bills
      WHERE ledger_id = ? AND date >= ? AND date <= ?
      GROUP BY type
    ''', [ledgerId, start, end]);

    double expense = 0, income = 0;
    for (final row in result) {
      if (row['type'] == 'expense') expense = (row['total'] as num?)?.toDouble() ?? 0;
      if (row['type'] == 'income') income = (row['total'] as num?)?.toDouble() ?? 0;
    }
    return MonthlyTotals(expense: expense, income: income);
  }

  Future<List<CategoryBreakdown>> getCategoryBreakdown(
    int ledgerId, int year, int month, String type,
  ) async {
    final db = await _db.database;
    final m = month.toString().padLeft(2, '0');
    final start = '$year-$m-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final end = '$year-$m-${lastDay.toString().padLeft(2, '0')}';

    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total FROM bills
      WHERE ledger_id = ? AND type = ? AND date >= ? AND date <= ?
      GROUP BY category ORDER BY total DESC
    ''', [ledgerId, type, start, end]);

    final grandTotal = result.fold<double>(0, (sum, r) => sum + ((r['total'] as num).toDouble()));
    final colors = _getCategoryColors();

    return result.map((r) {
      final total = (r['total'] as num).toDouble();
      return CategoryBreakdown(
        category: r['category'] as String,
        total: total,
        percentage: grandTotal > 0 ? (total / grandTotal) * 100 : 0,
        color: colors[r['category']] ?? '#95A5A6',
      );
    }).toList();
  }

  Future<List<DailyTotal>> getDailyTotals(
    int ledgerId, String startDate, String endDate,
  ) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT date,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as expense,
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as income
      FROM bills
      WHERE ledger_id = ? AND date >= ? AND date <= ?
      GROUP BY date ORDER BY date ASC
    ''', [ledgerId, startDate, endDate]);

    return result.map((r) => DailyTotal(
      date: r['date'] as String,
      expense: (r['expense'] as num?)?.toDouble() ?? 0,
      income: (r['income'] as num?)?.toDouble() ?? 0,
    )).toList();
  }

  Future<List<String>> getDistinctCategories(int ledgerId, String type) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM bills WHERE ledger_id = ? AND type = ? ORDER BY category',
      [ledgerId, type],
    );
    return result.map((r) => r['category'] as String).toList();
  }

  Future<void> renameCategory(int ledgerId, String oldName, String newName) async {
    final db = await _db.database;
    await db.rawUpdate(
      "UPDATE bills SET category = ?, updated_at = datetime('now','localtime') WHERE ledger_id = ? AND category = ?",
      [newName, ledgerId, oldName],
    );
  }

  Future<int> getBillCount([int? ledgerId]) async {
    final db = await _db.database;
    if (ledgerId != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM bills WHERE ledger_id = ?', [ledgerId],
      );
      return (result.first['count'] as int?) ?? 0;
    }
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM bills');
    return (result.first['count'] as int?) ?? 0;
  }

  Future<AllTimeStats> getAllTimeStats(int ledgerId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as count,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as total_expense,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as total_income,
        COALESCE(AVG(CASE WHEN type = 'expense' THEN amount ELSE NULL END), 0) as avg_expense,
        COALESCE(
          (SELECT category FROM bills b2
           WHERE b2.ledger_id = ? AND b2.type = 'expense'
           GROUP BY b2.category ORDER BY SUM(b2.amount) DESC LIMIT 1),
          ''
        ) as top_category
      FROM bills WHERE ledger_id = ?
    ''', [ledgerId, ledgerId]);

    final row = result.first;
    return AllTimeStats(
      count: (row['count'] as int?) ?? 0,
      totalExpense: (row['total_expense'] as num?)?.toDouble() ?? 0,
      totalIncome: (row['total_income'] as num?)?.toDouble() ?? 0,
      avgExpense: (row['avg_expense'] as num?)?.toDouble() ?? 0,
      topCategory: (row['top_category'] as String?) ?? '',
    );
  }

  Map<String, String> _getCategoryColors() {
    return {
      '餐饮': '#FF6384', '交通': '#36A2EB', '购物': '#FFCE56',
      '娱乐': '#9966FF',
      '工资': '#2ECC71', '转账': '#E67E22', '其他': '#C9CBCF',
    };
  }
}
