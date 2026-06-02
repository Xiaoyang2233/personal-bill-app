import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/pending_transaction_service.dart';
import '../database/bill_service.dart';
import '../models/pending_transaction.dart';

class PendingTransactionProvider extends ChangeNotifier {
  final _service = PendingTransactionService();
  final _billService = BillService();

  List<PendingTransaction> _pendingItems = [];
  List<PendingTransaction> get pendingItems => _pendingItems;

  int get pendingCount => _pendingItems.where((t) => t.status == 'pending').length;

  bool _isPanelOpen = false;
  bool get isPanelOpen => _isPanelOpen;

  bool _showReminder = false;
  bool get showReminder => _showReminder;
  int _overdueCount = 0;
  int get overdueCount => _overdueCount;

  bool _reminderEnabled = true;
  int _reminderHours = 4;
  int _autoIgnoreDays = 7;

  PendingTransactionProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _reminderEnabled = prefs.getBool('pending_reminder_enabled') ?? true;
    _reminderHours = prefs.getInt('pending_reminder_hours') ?? 4;
    _autoIgnoreDays = prefs.getInt('pending_auto_ignore_days') ?? 7;
  }

  Future<void> loadPending() async {
    _pendingItems = await _service.getPending();
    _checkOverdue();
    notifyListeners();
  }

  void _checkOverdue() {
    if (!_reminderEnabled) {
      _showReminder = false;
      return;
    }
    final now = DateTime.now();
    _overdueCount = 0;
    for (final item in _pendingItems) {
      if (item.status != 'pending') continue;
      final created = DateTime.tryParse(item.createdAt);
      if (created != null && now.difference(created).inHours >= _reminderHours) {
        _overdueCount++;
      }
    }
    _showReminder = _overdueCount > 0;
  }

  Future<void> confirmTransaction(PendingTransaction item, {
    required String category,
    required String note,
    required int ledgerId,
  }) async {
    await _billService.addBill(
      ledgerId: ledgerId,
      type: item.type,
      amount: item.amount,
      category: category,
      note: note.isNotEmpty ? note : (item.merchant ?? ''),
      date: _formatDate(item.createdAt),
      source: item.packageName,
    );
    await _service.updateStatus(item.id!, 'confirmed');
    await loadPending();
  }

  Future<void> ignoreTransaction(PendingTransaction item) async {
    await _service.updateStatus(item.id!, 'ignored');
    await loadPending();
  }

  Future<void> autoIgnoreExpired() async {
    await _service.deleteOlderThan(_autoIgnoreDays);
    await loadPending();
  }

  void togglePanel() {
    _isPanelOpen = !_isPanelOpen;
    notifyListeners();
  }

  void closePanel() {
    _isPanelOpen = false;
    notifyListeners();
  }

  String _formatDate(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return DateTime.now().toString().substring(0, 10);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  // Settings methods
  Future<void> setReminderEnabled(bool value) async {
    _reminderEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_reminder_enabled', value);
    _checkOverdue();
    notifyListeners();
  }

  Future<void> setReminderHours(int hours) async {
    _reminderHours = hours;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pending_reminder_hours', hours);
    _checkOverdue();
    notifyListeners();
  }

  Future<void> setAutoIgnoreDays(int days) async {
    _autoIgnoreDays = days;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pending_auto_ignore_days', days);
    notifyListeners();
  }

  bool get reminderEnabled => _reminderEnabled;
  int get reminderHours => _reminderHours;
  int get autoIgnoreDays => _autoIgnoreDays;
}
