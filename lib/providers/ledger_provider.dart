import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ledger.dart';
import '../database/ledger_service.dart';

class LedgerProvider extends ChangeNotifier {
  final _ledgerService = LedgerService();

  List<Ledger> _ledgers = [];
  List<Ledger> get ledgers => _ledgers;

  Ledger? _activeLedger;
  Ledger? get activeLedger => _activeLedger;

  LedgerProvider() {
    loadLedgers();
  }

  Future<void> loadLedgers() async {
    _ledgers = await _ledgerService.getLedgers();
    if (_ledgers.isEmpty) {
      await _ledgerService.createLedger('个人账本');
      _ledgers = await _ledgerService.getLedgers();
    }
    if (_ledgers.isNotEmpty && _activeLedger == null) {
      // Restore previously selected ledger from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt('active_ledger_id');
      if (savedId != null) {
        _activeLedger = _ledgers.where((l) => l.id == savedId).firstOrNull;
      }
      _activeLedger ??= _ledgers.first;
    }
    notifyListeners();
  }

  Future<Ledger> ensureLedger() async {
    if (_activeLedger != null) return _activeLedger!;
    await loadLedgers();
    if (_activeLedger == null) {
      await _ledgerService.createLedger('个人账本');
      await loadLedgers();
    }
    return _activeLedger!;
  }

  Future<void> createLedger(String name, {String icon = '📒', String color = '#4A90D9'}) async {
    await _ledgerService.createLedger(name, icon: icon, color: color);
    await loadLedgers();
  }

  Future<void> updateLedger(int id, String name) async {
    await _ledgerService.updateLedger(id, name);
    await loadLedgers();
  }

  Future<void> deleteLedger(int id) async {
    await _ledgerService.deleteLedger(id);
    await loadLedgers();
    if (_activeLedger?.id == id && _ledgers.isNotEmpty) {
      _activeLedger = _ledgers.first;
      await _persistActiveLedger();
    }
  }

  Future<void> switchLedger(int id) async {
    _activeLedger = _ledgers.where((l) => l.id == id).firstOrNull;
    await _persistActiveLedger();
    notifyListeners();
  }

  Future<void> _persistActiveLedger() async {
    if (_activeLedger?.id != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_ledger_id', _activeLedger!.id!);
    }
  }
}
