import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../database/bill_service.dart';
import '../database/category_service.dart';
import '../utils/date_utils.dart';

class BillProvider extends ChangeNotifier {
  final _billService = BillService();
  final _categoryService = CategoryService();

  List<Bill> _bills = [];
  List<Bill> get bills => _bills;

  MonthlyTotals _monthlyTotals = MonthlyTotals(expense: 0, income: 0);
  MonthlyTotals get monthlyTotals => _monthlyTotals;

  List<CategoryBreakdown> _categoryBreakdown = [];
  List<CategoryBreakdown> get categoryBreakdown => _categoryBreakdown;

  List<CategoryBreakdown> _incomeBreakdown = [];
  List<CategoryBreakdown> get incomeBreakdown => _incomeBreakdown;

  List<DailyTotal> _dailyTotals = [];
  List<DailyTotal> get dailyTotals => _dailyTotals;

  AllTimeStats? _allTimeStats;
  AllTimeStats? get allTimeStats => _allTimeStats;

  Future<void> loadBills(int ledgerId, {int? year, int? month}) async {
    final now = DateTime.now();
    final y = year ?? now.year;
    final m = month ?? now.month;

    _bills = await _billService.getBills(ledgerId, limit: 200);

    _monthlyTotals = await _billService.getMonthlyTotals(ledgerId, y, m);
    _categoryBreakdown = await _billService.getCategoryBreakdown(ledgerId, y, m, 'expense');
    _incomeBreakdown = await _billService.getCategoryBreakdown(ledgerId, y, m, 'income');
    final trendStart = getDaysAgo(30);
    final trendEnd = getToday();
    _dailyTotals = await _billService.getDailyTotals(ledgerId, trendStart, trendEnd);
    _allTimeStats = await _billService.getAllTimeStats(ledgerId);

    notifyListeners();
  }

  Future<int> addBill({
    required int ledgerId,
    required String type,
    required double amount,
    required String category,
    String note = '',
    required String date,
  }) async {
    final id = await _billService.addBill(
      ledgerId: ledgerId,
      type: type,
      amount: amount,
      category: category,
      note: note,
      date: date,
    );
    await loadBills(ledgerId);
    return id;
  }

  Future<void> updateBill(int id, {
    String? type,
    double? amount,
    String? category,
    String? note,
    String? date,
  }) async {
    await _billService.updateBill(id,
      type: type, amount: amount, category: category, note: note, date: date);
    // Reload with current month context
    final now = DateTime.now();
    await loadBills(_bills.firstOrNull?.ledgerId ?? 1, year: now.year, month: now.month);
  }

  Future<void> deleteBill(int id) async {
    final ledgerId = _bills.firstOrNull?.ledgerId ?? 1;
    await _billService.deleteBill(id);
    await loadBills(ledgerId);
  }

  List<Bill> getFilteredBills({
    String? startDate,
    String? endDate,
    String? type,
    String? category,
    String? keyword,
  }) {
    return _bills.where((b) {
      if (startDate != null && b.date.compareTo(startDate) < 0) return false;
      if (endDate != null && b.date.compareTo(endDate) > 0) return false;
      if (type != null && b.type != type) return false;
      if (category != null && b.category != category) return false;
      if (keyword != null && keyword.isNotEmpty &&
          !b.note.toLowerCase().contains(keyword.toLowerCase())) return false;
      return true;
    }).toList();
  }

  Future<String?> getCategoryIcon(String category, String type) async {
    return await _categoryService.getCategoryIcon(category, type);
  }
}
