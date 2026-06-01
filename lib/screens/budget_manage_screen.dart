import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/ledger_provider.dart';
import '../database/category_service.dart';
import '../models/budget.dart';
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

  // Inline editing state
  int? _editingBudgetId;
  final _editAmountController = TextEditingController();
  final _editThresholdController = TextEditingController();
  String? _editCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _thresholdController.dispose();
    _editAmountController.dispose();
    _editThresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      _categories = await _categoryService.getCategories('expense');
    } catch (_) {
      _categories = CategoryService.defaultExpenseCategories;
    }
    setState(() {});
  }

  Future<void> _create() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效预算金额'), duration: Duration(seconds: 1)));
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

  void _startEditing(Budget budget) {
    setState(() {
      _editingBudgetId = budget.id;
      _editAmountController.text = budget.amount.toStringAsFixed(0);
      _editThresholdController.text = (budget.alertThreshold * 100).round().toString();
      _editCategory = budget.category;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingBudgetId = null;
      _editCategory = null;
    });
  }

  Future<void> _saveEditing(Budget budget) async {
    final amount = double.tryParse(_editAmountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    final threshold = (int.tryParse(_editThresholdController.text) ?? 80) / 100;
    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger == null) return;

    // Delete old budget and create new one (simple way to update category + amount)
    await context.read<BudgetProvider>().deleteBudget(budget.id!);
    await context.read<BudgetProvider>().setBudget(
      ledgerId: ledger.id!,
      category: _editCategory ?? budget.category,
      amount: amount,
      alertThreshold: threshold,
    );

    setState(() {
      _editingBudgetId = null;
      _editCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
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
                onTap: () {
  ScaffoldMessenger.of(context).clearSnackBars();
  Navigator.pop(context);
},
                child: Text('← 返回', style: TextStyle(fontSize: 16, color: theme.primaryColor)),
              ),
              Text('预算管理', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textColor)),
              GestureDetector(
                onTap: () => setState(() => _showCreate = !_showCreate),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(_showCreate ? '取消' : '+ 新增',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.primaryColor)),
                ),
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.primaryColor),
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.primaryColor),
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
          final percentage = budget.amount > 0 ? spent / budget.amount : 0.0;
          final isOver = percentage >= 1;
          final isNear = percentage >= budget.alertThreshold;
          final isEditing = _editingBudgetId == budget.id;

          return GlassContainer(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 10),
            child: isEditing ? _buildEditingCard(budget, theme) : _buildDisplayCard(budget, spent, percentage, isOver, isNear, theme),
          );
        }),
        const SizedBox(height: 60),
          ],
        ),
      ),
      );
    }

  Widget _buildDisplayCard(Budget budget, double spent, double percentage, bool isOver, bool isNear, ThemeProvider theme) {
    return Column(
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
          children: [
            Text('${(percentage * 100).round()}%',
              style: TextStyle(fontSize: 13, color: isOver ? theme.dangerColor : theme.textSecondaryColor)),
            if (isOver || isNear)
              Text('  ⚠️ ${isOver ? '已超支!' : '即将超支'}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.dangerColor)),
            const Spacer(),
            GestureDetector(
              onTap: () => _startEditing(budget),
              child: Text('编辑', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.primaryColor)),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => context.read<BudgetProvider>().deleteBudget(budget.id!),
              child: Text('删除', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.dangerColor)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditingCard(Budget budget, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category selector
        Text('分类', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _categories.map((c) {
            final selected = _editCategory == c.label;
            final color = Color(int.parse(c.color.replaceAll('#', '0xFF')));
            return GestureDetector(
              onTap: () => setState(() => _editCategory = c.label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? color : theme.inputBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 3),
                    Text(c.label, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : theme.textColor,
                    )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Amount
        Text('预算金额', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
        const SizedBox(height: 6),
        TextField(
          controller: _editAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 14, color: theme.textColor),
          decoration: InputDecoration(
            hintText: '0.00',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.primaryColor),
            ),
            filled: true,
            fillColor: theme.inputBgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
        // Threshold
        Text('提醒阈值 (%)', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
        const SizedBox(height: 6),
        TextField(
          controller: _editThresholdController,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 14, color: theme.textColor),
          decoration: InputDecoration(
            hintText: '80',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.primaryColor),
            ),
            filled: true,
            fillColor: theme.inputBgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _cancelEditing,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.borderColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text('取消', style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _saveEditing(budget),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('保存', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
