import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/pending_transaction_provider.dart';
import '../providers/ledger_provider.dart';
import '../database/category_service.dart';
import '../models/pending_transaction.dart';
import '../models/category.dart';
import '../utils/currency_utils.dart';

class PendingTransactionEditScreen extends StatefulWidget {
  final PendingTransaction transaction;

  const PendingTransactionEditScreen({super.key, required this.transaction});

  @override
  State<PendingTransactionEditScreen> createState() => _PendingTransactionEditScreenState();
}

class _PendingTransactionEditScreenState extends State<PendingTransactionEditScreen> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late String _selectedCategory;
  List<CustomCategory> _categories = [];
  final _categoryService = CategoryService();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.transaction.amount.toStringAsFixed(2));
    _noteController = TextEditingController(text: widget.transaction.merchant ?? '');
    _selectedCategory = widget.transaction.suggestedCategory;
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      _categories = await _categoryService.getCategories(widget.transaction.type);
    } catch (_) {
      _categories = CategoryService.defaultExpenseCategories;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final topSafe = MediaQuery.of(context).padding.top;
    final isExpense = widget.transaction.type == 'expense';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: theme.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F7FA),
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
                  Text('编辑交易', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textColor)),
                  const SizedBox(width: 60),
                ],
              ),
            ),

            // Source info
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.inputBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(widget.transaction.sourceName, style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                  const SizedBox(width: 8),
                  Text(isExpense ? '支出' : '收入', style: TextStyle(
                    fontSize: 12,
                    color: isExpense ? theme.expenseColor : theme.incomeColor,
                    fontWeight: FontWeight.w500,
                  )),
                  const Spacer(),
                  Text(formatCurrency(widget.transaction.amount),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textColor)),
                ],
              ),
            ),

            // Amount
            Text('金额', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
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

            const SizedBox(height: 16),

            // Category
            Text('分类', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final selected = _selectedCategory == c.label;
                final color = Color(int.parse(c.color.replaceAll('#', '0xFF')));
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = c.label),
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

            const SizedBox(height: 16),

            // Note
            Text('备注', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
            const SizedBox(height: 6),
            TextField(
              controller: _noteController,
              style: TextStyle(fontSize: 14, color: theme.textColor),
              decoration: InputDecoration(
                hintText: '添加备注...',
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

            const SizedBox(height: 24),

            // Confirm button
            GestureDetector(
              onTap: _confirm,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text('确认保存', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 10),

            // Ignore button
            GestureDetector(
              onTap: _ignore,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dangerColor, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text('忽略', style: TextStyle(color: theme.dangerColor, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirm() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }

    final provider = context.read<PendingTransactionProvider>();
    final ledgerProvider = context.read<LedgerProvider>();
    final ledger = await ledgerProvider.ensureLedger();

    await provider.confirmTransaction(
      widget.transaction,
      category: _selectedCategory,
      note: _noteController.text.trim(),
      ledgerId: ledger.id!,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存到账本')));
      Navigator.pop(context);
    }
  }

  void _ignore() async {
    final provider = context.read<PendingTransactionProvider>();
    await provider.ignoreTransaction(widget.transaction);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已忽略')));
      Navigator.pop(context);
    }
  }
}
