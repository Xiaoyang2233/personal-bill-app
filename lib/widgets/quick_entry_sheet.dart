import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/ledger_provider.dart';
import '../database/category_service.dart';
import '../models/category.dart';
import '../models/ledger.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';

class QuickEntrySheet extends StatefulWidget {
  const QuickEntrySheet({super.key});

  @override
  State<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<QuickEntrySheet> {
  String _type = 'expense';
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = '';
  bool _saved = false;

  List<CustomCategory> _categories = [];
  final _categoryService = CategoryService();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _categoryService.getCategories('expense');
      setState(() {
        _categories = cats;
        _category = cats.isNotEmpty ? cats.first.label : '';
      });
    } catch (_) {
      setState(() {
        _categories = CategoryService.defaultExpenseCategories;
        _category = _categories.isNotEmpty ? _categories.first.label : '';
      });
    }
  }

  Future<void> _switchType(String type) async {
    try {
      final cats = await _categoryService.getCategories(type);
      setState(() {
        _type = type;
        _categories = cats;
        _category = cats.isNotEmpty ? cats.first.label : '';
      });
    } catch (_) {
      final defaults = type == 'expense'
          ? CategoryService.defaultExpenseCategories
          : CategoryService.defaultIncomeCategories;
      setState(() {
        _type = type;
        _categories = defaults;
        _category = defaults.isNotEmpty ? defaults.first.label : '';
      });
    }
  }

  Future<void> _save() async {
    final amount = parseAmountInput(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    final ledgerProvider = context.read<LedgerProvider>();
    Ledger ledger;
    try {
      ledger = await ledgerProvider.ensureLedger();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化账本失败: $e')),
        );
      }
      return;
    }

    try {
      await context.read<BillProvider>().addBill(
        ledgerId: ledger.id!,
        type: _type,
        amount: amount,
        category: _category.isNotEmpty ? _category : '其他',
        note: _noteController.text.trim(),
        date: getToday(),
      );

      setState(() => _saved = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: theme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Type toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchType('expense'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'expense' ? theme.expenseColor : const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text('支 出', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: _type == 'expense' ? Colors.white : theme.textColor,
                      )),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchType('income'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _type == 'income' ? theme.incomeColor : const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text('收 入', style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: _type == 'income' ? Colors.white : theme.textColor,
                      )),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Amount input
            TextField(
              controller: _amountController,
              autofocus: true,
              style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.w700,
                color: _type == 'expense' ? theme.expenseColor : theme.incomeColor,
              ),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: theme.textSecondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.borderColor, width: 0.5),
                ),
                filled: true,
                fillColor: theme.inputBgColor,
              ),
              onChanged: (v) {
                _amountController.value = TextEditingValue(
                  text: formatAmountInput(v),
                  selection: TextSelection.collapsed(offset: formatAmountInput(v).length),
                );
              },
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),

            // Category chips
            Align(
              alignment: Alignment.centerLeft,
              child: Text('分类', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final selected = _category == cat.label;
                  final color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat.label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? color : theme.inputBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(cat.label, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : theme.textColor,
                          )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Note input
            TextField(
              controller: _noteController,
              style: TextStyle(fontSize: 14, color: theme.textColor),
              maxLength: 100,
              decoration: InputDecoration(
                hintText: '添加备注...',
                hintStyle: TextStyle(color: theme.textSecondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.borderColor, width: 0.5),
                ),
                filled: true,
                fillColor: theme.inputBgColor,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saved ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saved
                      ? theme.successColor
                      : (_type == 'expense' ? theme.expenseColor : theme.incomeColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _saved ? '✓ 已保存' : '保存',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
