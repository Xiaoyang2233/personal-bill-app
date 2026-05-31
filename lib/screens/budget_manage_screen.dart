import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/ledger_provider.dart';
import '../database/category_service.dart';
import '../models/category.dart';
import '../utils/currency_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_background.dart';

class BudgetManageScreen extends StatefulWidget {
  const BudgetManageScreen({super.key});

  @override
  State<BudgetManageScreen> createState() => _BudgetManageScreenState();
}

class _BudgetManageScreenState extends State<BudgetManageScreen> {
  bool _showCreate = false;
  String _budgetCategory = '餐饮';
  final _amountController = TextEditingController();
  final _thresholdController = TextEditingController(text: '80');
  List<CustomCategory> _categories = [];
  final _categoryService = CategoryService();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    _categories = await _categoryService.getCategories('expense');
    setState(() {});
  }

  Future<void> _create() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效预算金额')));
      return;
    }
    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger == null) return;

    final threshold = (int.tryParse(_thresholdController.text) ?? 80) / 100;
    await context.read<BudgetProvider>().setBudget(
      ledgerId: ledger.id!,
      category: _budgetCategory,
      amount: amount,
      alertThreshold: threshold,
    );
    _amountController.clear();
    setState(() => _showCreate = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    return AppBackground(
      child: ListView(
        padding: EdgeInsets.only(top: topSafe, left: 16, right: 16, bottom: 100),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text('← 返回', style: TextStyle(fontSize: 16, color: theme.primaryColor)),
              ),
              Text('预算管理', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textColor)),
              GestureDetector(
                onTap: () => setState(() => _showCreate = !_showCreate),
                child: Text(_showCreate ? '取消' : '+ 新增',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.primaryColor)),
              ),
            ],
          ),
        ),

        // Create form
        if (_showCreate)
          GlassContainer(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分类', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _categories.map((c) {
                    final selected = _budgetCategory == c.label;
                    final color = Color(int.parse(c.color.replaceAll('#', '0xFF')));
                    return GestureDetector(
                      onTap: () => setState(() => _budgetCategory = c.label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? color : theme.inputBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.icon, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text(c.label, style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500,
                              color: selected ? Colors.white : theme.textColor,
                            )),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text('每月预算金额', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 14, color: theme.textColor),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.borderColor),
                    ),
                    filled: true,
                    fillColor: theme.inputBgColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text('提醒阈值: ${_thresholdController.text}%', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                const SizedBox(height: 6),
                TextField(
                  controller: _thresholdController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 14, color: theme.textColor),
                  decoration: InputDecoration(
                    hintText: '80',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.borderColor),
                    ),
                    filled: true,
                    fillColor: theme.inputBgColor,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _create,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('设置预算', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

        // Budget list
        if (budgetProvider.budgets.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text('暂无预算设置，点击右上角新增',
                style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
            ),
          ),

        ...budgetProvider.budgets.map((budget) {
          final alert = budgetProvider.alerts.where((a) => a.category == budget.category).firstOrNull;
          final spent = alert?.spent ?? 0;
          final percentage = budget.amount > 0 ? spent / budget.amount : 0;
          final isOver = percentage >= 1;
          final isNear = percentage >= budget.alertThreshold;

          return GlassContainer(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(budget.category, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textColor)),
                    Text('${formatCurrency(spent)} / ${formatCurrency(budget.amount)}',
                      style: TextStyle(fontSize: 14, color: theme.textColor)),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage.clamp(0, 1).toDouble(),
                    backgroundColor: theme.inputBgColor,
                    color: isOver ? theme.dangerColor : (isNear ? theme.warningColor : theme.successColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(percentage * 100).round()}%',
                      style: TextStyle(fontSize: 13, color: isOver ? theme.dangerColor : theme.textSecondaryColor)),
                    if (isOver || isNear)
                      Text('⚠️ ${isOver ? '已超支!' : '即将超支'}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.dangerColor)),
                    GestureDetector(
                      onTap: () => context.read<BudgetProvider>().deleteBudget(budget.id!),
                      child: Text('删除', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.dangerColor)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 60),
      ],
      ),
    );
  }
}
