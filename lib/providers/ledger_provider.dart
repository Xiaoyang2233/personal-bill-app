import 'package:flutter/material.dart';
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
    if (_ledgers.isNotEmpty && _activeLedger == null) {
      _activeLedger = _ledgers.first;
    }
    notifyListeners();
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
    }
  }

  void switchLedger(int id) {
    _activeLedger = _ledgers.where((l) => l.id == id).firstOrNull;
    notifyListeners();
  }
}
