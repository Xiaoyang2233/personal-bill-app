import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  String _chartMode = 'pie'; // 'pie', 'bar', 'line'
  bool _showLedgerPicker = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger != null) {
      await Future.wait([
        context.read<BillProvider>().loadBills(ledger.id!),
        context.read<BudgetProvider>().loadBudgets(ledger.id!),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final billProvider = context.watch<BillProvider>();
    final ledgerProvider = context.watch<LedgerProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    final now = DateTime.now();
    final monthName = getMonthName(now.month);
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
            year: now.year,
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
          if (_chartMode == 'pie')
            CategoryPieChart(data: billProvider.categoryBreakdown),
          if (_chartMode == 'bar')
            CategoryBarChart(data: billProvider.categoryBreakdown),
          if (_chartMode == 'line')
            TrendLineChart(data: billProvider.dailyTotals),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, String mode, ThemeProvider theme) {
    final active = _chartMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _chartMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? theme.primaryColor : const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? Colors.white : theme.textColor,
          )),
        ),
      ),
    );
  }
}
