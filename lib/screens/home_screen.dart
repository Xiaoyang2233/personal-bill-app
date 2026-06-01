import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/budget_provider.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/category_bar_chart.dart';
import '../widgets/trend_line_chart.dart';
import '../widgets/glass_container.dart';
import '../utils/date_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _chartMode = 'pie';
  bool _showLedgerPicker = false;
  int? _loadedLedgerId;
  late int _displayYear;
  late int _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayYear = now.year;
    _displayMonth = now.month;
    _loadChartMode();
    final ledgerProvider = context.read<LedgerProvider>();
    ledgerProvider.addListener(_onLedgerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDataIfReady());
  }

  @override
  void dispose() {
    context.read<LedgerProvider>().removeListener(_onLedgerChanged);
    super.dispose();
  }

  void _onLedgerChanged() {
    _loadDataIfReady();
  }

  void _loadDataIfReady() {
    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger != null && ledger.id != _loadedLedgerId) {
      _loadedLedgerId = ledger.id;
      _loadData();
    }
  }

  Future<void> _loadChartMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _chartMode = prefs.getString('chart_mode') ?? 'pie');
  }

  Future<void> _setChartMode(String mode) async {
    setState(() => _chartMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chart_mode', mode);
  }

  Future<void> _loadData() async {
    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger != null) {
      await Future.wait([
        context.read<BillProvider>().loadBills(ledger.id!,
          year: _displayYear, month: _displayMonth),
        context.read<BudgetProvider>().loadBudgets(ledger.id!),
      ]);
    }
  }

  void _goToPrevMonth() {
    setState(() {
      if (_displayMonth == 1) {
        _displayMonth = 12;
        _displayYear--;
      } else {
        _displayMonth--;
      }
    });
    _loadData();
  }

  void _goToNextMonth() {
    final now = DateTime.now();
    if (_displayYear == now.year && _displayMonth == now.month) return;
    setState(() {
      if (_displayMonth == 12) {
        _displayMonth = 1;
        _displayYear++;
      } else {
        _displayMonth++;
      }
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final billProvider = context.watch<BillProvider>();
    final ledgerProvider = context.watch<LedgerProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    final now = DateTime.now();
    final isCurrentMonth = _displayYear == now.year && _displayMonth == now.month;
    final monthName = getMonthName(_displayMonth);
    final hasAlerts = budgetProvider.alerts.any((a) => a.exceeded || a.nearLimit);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.only(top: topSafe + 8, left: 16, right: 16, bottom: 80),
        children: [
          // Ledger Switcher
          GlassContainer(
            margin: const EdgeInsets.only(bottom: 10, top: 4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showLedgerPicker = !_showLedgerPicker),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('📒 ${ledgerProvider.activeLedger?.name ?? '个人'}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
                    Text(_showLedgerPicker ? '▲' : '▼',
                      style: TextStyle(color: theme.textSecondaryColor)),
                  ],
                ),
              ),
            ),
          ),

          // Ledger dropdown
          if (_showLedgerPicker)
            GlassContainer(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: ledgerProvider.ledgers.map((l) => ListTile(
                  title: Text(
                    '${l.id == ledgerProvider.activeLedger?.id ? '● ' : '○ '}${l.name}',
                    style: TextStyle(color: theme.textColor),
                  ),
                  onTap: () {
                    ledgerProvider.switchLedger(l.id!);
                    setState(() => _showLedgerPicker = false);
                    _loadData();
                  },
                  dense: true,
                )).toList(),
              ),
            ),

          // Month selector
          GlassContainer(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _goToPrevMonth,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Text('←', style: TextStyle(fontSize: 18, color: theme.primaryColor)),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(_displayYear, _displayMonth),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      helpText: '选择月份',
                    );
                    if (picked != null) {
                      setState(() {
                        _displayYear = picked.year;
                        _displayMonth = picked.month;
                      });
                      _loadData();
                    }
                  },
                  child: Text(
                    '$_displayYear年 $monthName',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor),
                  ),
                ),
                GestureDetector(
                  onTap: isCurrentMonth ? null : _goToNextMonth,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Text('→', style: TextStyle(
                      fontSize: 18,
                      color: isCurrentMonth ? theme.textSecondaryColor : theme.primaryColor,
                    )),
                  ),
                ),
              ],
            ),
          ),

          // Budget alerts
          if (hasAlerts)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.dangerColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('⚠️ 部分预算已超支或接近上限',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ),

          // Monthly Summary
          MonthlySummaryCard(
            year: _displayYear,
            month: monthName,
            totals: billProvider.monthlyTotals,
          ),

          // Chart mode toggle
          Row(
            children: [
              _buildToggle('饼图', 'pie', theme),
              const SizedBox(width: 10),
              _buildToggle('条形图', 'bar', theme),
              const SizedBox(width: 10),
              _buildToggle('趋势', 'line', theme),
            ],
          ),
          const SizedBox(height: 12),

          // Charts
          if (_chartMode == 'pie') ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CategoryPieChart(
                    data: billProvider.categoryBreakdown,
                    title: '支出分类',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CategoryPieChart(
                    data: billProvider.incomeBreakdown,
                    title: '收入分类',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TrendLineChart(data: billProvider.dailyTotals),
          ],
          if (_chartMode == 'bar') ...[
            CategoryBarChart(data: billProvider.categoryBreakdown),
            const SizedBox(height: 12),
            TrendLineChart(data: billProvider.dailyTotals),
          ],
          if (_chartMode == 'line')
            TrendLineChart(data: billProvider.dailyTotals),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, String mode, ThemeProvider theme) {
    final active = _chartMode == mode;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _setChartMode(mode),
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.primaryColor.withAlpha(50),
          highlightColor: theme.primaryColor.withAlpha(30),
          child: Ink(
            decoration: BoxDecoration(
              color: active ? theme.primaryColor : theme.inputBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: active ? Colors.white : theme.textColor,
              )),
            ),
          ),
        ),
      ),
    );
  }
}
