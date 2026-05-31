class Bill {
  final int? id;
  final int ledgerId;
  final String type; // 'expense' or 'income'
  final double amount;
  final String category;
  final String note;
  final String date; // YYYY-MM-DD
  final String? createdAt;
  final String? updatedAt;

  Bill({
    this.id,
    required this.ledgerId,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledger_id': ledgerId,
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'date': date,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map) {
    return Bill(
      id: map['id'] as int?,
      ledgerId: map['ledger_id'] as int,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      note: (map['note'] as String?) ?? '',
      date: map['date'] as String,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}

class MonthlyTotals {
  final double expense;
  final double income;
  double get balance => income - expense;

  MonthlyTotals({required this.expense, required this.income});
}

class CategoryBreakdown {
  final String category;
  final double total;
  final double percentage;
  final String color;

  CategoryBreakdown({
    required this.category,
    required this.total,
    required this.percentage,
    required this.color,
  });
}

class DailyTotal {
  final String date;
  final double expense;
  final double income;

  DailyTotal({
    required this.date,
    required this.expense,
    required this.income,
  });
}

class AllTimeStats {
  final int count;
  final double totalExpense;
  final double totalIncome;
  final double avgExpense;
  final String topCategory;

  double get balance => totalIncome - totalExpense;
  int get recordCount => count;

  AllTimeStats({
    required this.count,
    required this.totalExpense,
    required this.totalIncome,
    required this.avgExpense,
    required this.topCategory,
  });
}
