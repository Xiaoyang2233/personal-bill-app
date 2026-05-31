class Budget {
  final int? id;
  final int ledgerId;
  final String category;
  final double amount;
  final String period;
  final double alertThreshold;

  Budget({
    this.id,
    required this.ledgerId,
    required this.category,
    required this.amount,
    this.period = 'monthly',
    this.alertThreshold = 0.8,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledger_id': ledgerId,
      'category': category,
      'amount': amount,
      'period': period,
      'alert_threshold': alertThreshold,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      ledgerId: map['ledger_id'] as int,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      period: (map['period'] as String?) ?? 'monthly',
      alertThreshold: (map['alert_threshold'] as num?)?.toDouble() ?? 0.8,
    );
  }
}

class BudgetAlert {
  final String category;
  final double spent;
  final double budgetAmount;
  final double threshold;
  bool get exceeded => spent >= budgetAmount;
  bool get nearLimit => spent >= budgetAmount * threshold;

  BudgetAlert({
    required this.category,
    required this.spent,
    required this.budgetAmount,
    required this.threshold,
  });
}
