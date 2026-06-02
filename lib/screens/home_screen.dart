import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/pending_transaction_provider.dart';
import '../utils/currency_utils.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/category_bar_chart.dart';
import '../widgets/trend_line_chart.dart';
import '../widgets/glass_container.dart';
import '../utils/date_utils.dart';
import 'budget_manage_screen.dart';
import 'pending_transactions_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  String _chartMode = 'pie';
  bool _showLedgerPicker = false;
  bool _showAllBudgets = false;
  int? _loadedLedgerId;
  late int _displayYear;
  late int _displayMonth;

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    final theme = context.watch<ThemeProvider>();
    final billProvider = context.watch<BillProvider>();
    final ledgerProvider = context.watch<LedgerProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    final now = DateTime.now();
    final isCurrentMonth = _displayYear == now.year && _displayMonth == now.month;
    final monthName = getMonthName(_displayMonth);
    final hasAlerts = budgetProvider.alerts.any((a) => a.exceeded || a.nearLimit);

    return Stack(
      children: [
        RefreshIndicator(
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

          // Budget Warning Cards
          ..._buildBudgetWarningCards(budgetProvider, theme),

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
            RepaintBoundary(
              child: Row(
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
            ),
          if (_chartMode == 'bar')
            RepaintBoundary(
              child: CategoryBarChart(data: billProvider.categoryBreakdown),
            ),
          if (_chartMode == 'line')
            RepaintBoundary(
              child: TrendLineChart(data: billProvider.dailyTotals),
            ),
        ],
      ),
        ),
        // Pending transactions badge
        Consumer<PendingTransactionProvider>(
          builder: (context, pendingProvider, _) {
            if (pendingProvider.pendingCount <= 0) return const SizedBox.shrink();
            return Positioned(
              right: 16,
              top: topSafe + 8,
              child: GestureDetector(
                onTap: pendingProvider.togglePanel,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.dangerColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.dangerColor.withAlpha(80),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '${pendingProvider.pendingCount}',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        ),
        const PendingTransactionsPanel(),
      ],
    );
  }

  List<Widget> _buildBudgetWarningCards(BudgetProvider budgetProvider, ThemeProvider theme) {
    final budgets = budgetProvider.budgets;
    if (budgets.isEmpty) return [];

    final cards = <Widget>[];
    final displayBudgets = _showAllBudgets ? budgets : budgets.take(2).toList();

    for (final budget in displayBudgets) {
      final alert = budgetProvider.alerts.where((a) => a.category == budget.category).firstOrNull;
      final spent = alert?.spent ?? 0.0;
      final percentage = budget.amount > 0 ? spent / budget.amount : 0.0;
      final isOver = percentage >= 1.0;
      final isNear = percentage >= 0.8;

      Color progressColor;
      if (isOver) {
        progressColor = theme.dangerColor;
      } else if (isNear) {
        progressColor = theme.warningColor;
      } else {
        progressColor = theme.successColor;
      }

      cards.add(
        GlassContainer(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(budget.category, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textColor)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetManageScreen())),
                    child: Text('预算管理 →', style: TextStyle(fontSize: 12, color: theme.primaryColor)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${formatCurrency(spent)} / ${formatCurrency(budget.amount)}',
                style: TextStyle(fontSize: 13, color: theme.textColor)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage.clamp(0.0, 1.0),
                  backgroundColor: theme.inputBgColor,
                  color: progressColor,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(percentage * 100).round()}%',
                    style: TextStyle(fontSize: 12, color: isOver ? theme.dangerColor : theme.textSecondaryColor)),
                  if (isOver || isNear)
                    Text('⚠️ ${isOver ? '已超支' : '即将超支'}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.dangerColor)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Add expand/collapse button if more than 2 budgets
    if (budgets.length > 2) {
      cards.add(
        GestureDetector(
          onTap: () => setState(() => _showAllBudgets = !_showAllBudgets),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_showAllBudgets ? '收起' : '展开全部',
                  style: TextStyle(fontSize: 13, color: theme.primaryColor)),
                Icon(_showAllBudgets ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18, color: theme.primaryColor),
              ],
            ),
          ),
        ),
      );
    }

    return cards;
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
