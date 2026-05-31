import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../database/budget_service.dart';

class BudgetProvider extends ChangeNotifier {
  final _budgetService = BudgetService();

  List<Budget> _budgets = [];
  List<Budget> get budgets => _budgets;

  List<BudgetAlert> _alerts = [];
  List<BudgetAlert> get alerts => _alerts;

  Future<void> loadBudgets(int ledgerId) async {
    final now = DateTime.now();
    _budgets = await _budgetService.getBudgets(ledgerId);
    _alerts = await _budgetService.getBudgetAlerts(ledgerId, now.year, now.month);
    notifyListeners();
  }

  Future<void> setBudget({
    required int ledgerId,
    required String category,
    required double amount,
    String period = 'monthly',
    double alertThreshold = 0.8,
  }) async {
    await _budgetService.setBudget(
      ledgerId: ledgerId,
      category: category,
      amount: amount,
      period: period,
      alertThreshold: alertThreshold,
    );
    await loadBudgets(ledgerId);
  }

  Future<void> deleteBudget(int id) async {
    await _budgetService.deleteBudget(id);
    if (_budgets.isNotEmpty) {
      await loadBudgets(_budgets.first.ledgerId);
    }
  }
}
