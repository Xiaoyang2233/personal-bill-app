import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/bill_provider.dart';
import '../database/bill_service.dart';
import '../database/category_service.dart';
import '../models/category.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_background.dart';

class BillDetailScreen extends StatefulWidget {
  final int billId;
  const BillDetailScreen({super.key, required this.billId});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  final _billService = BillService();
  final _categoryService = CategoryService();
  var _isEditing = false;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _dateCtrl;
  String _editType = 'expense';
  String _editCategory = '';
  List<CustomCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _dateCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _startEdit(bill) {
    _amountCtrl.text = bill.amount.toString();
    _editCategory = bill.category;
    _noteCtrl.text = bill.note;
    _editType = bill.type;
    _dateCtrl.text = bill.date;
    _loadCategories();
    setState(() => _isEditing = true);
  }

  Future<void> _loadCategories() async {
    _categories = await _categoryService.getCategories(_editType);
    setState(() {});
  }

  Future<void> _save(bill) async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    await context.read<BillProvider>().updateBill(widget.billId,
      amount: amount, category: _editCategory, note: _noteCtrl.text,
      type: _editType, date: _dateCtrl.text);
    setState(() => _isEditing = false);
  }

  Future<void> _delete(bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后将无法恢复，确定要删除这条账单吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      await context.read<BillProvider>().deleteBill(widget.billId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    return FutureBuilder(
      future: _billService.getBillById(widget.billId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return AppBackground(
            child: Center(
              child: Text('账单不存在或已被删除',
                style: TextStyle(color: theme.textSecondaryColor)),
            ),
          );
        }
        final bill = snapshot.data!;

        return AppBackground(
          child: ListView(
            padding: EdgeInsets.only(top: topSafe, left: 16, right: 16, bottom: 90),
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text('← 返回', style: TextStyle(fontSize: 16, color: theme.primaryColor)),
                    ),
                    Text('账单详情', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textColor)),
                    GestureDetector(
                      onTap: () => _isEditing ? _save(bill) : _startEdit(bill),
                      child: Text(_isEditing ? '保存' : '编辑',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.primaryColor)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: _isEditing ? _buildEditView(bill, theme) : _buildViewView(bill, theme),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewView(bill, ThemeProvider theme) {
    return Column(
      children: [
        Text(
          '${bill.type == 'expense' ? '-' : '+'}${formatCurrency(bill.amount)}',
          style: TextStyle(
            fontSize: 40, fontWeight: FontWeight.w700,
            color: bill.type == 'expense' ? theme.expenseColor : theme.incomeColor,
          ),
        ),
        const SizedBox(height: 20),
        _detailRow('类型', bill.type == 'expense' ? '支出' : '收入', theme),
        _detailRow('分类', bill.category, theme),
        _detailRow('日期', '${formatDisplayDate(bill.date)} (${bill.date})', theme),
        if (bill.note.isNotEmpty) _detailRow('备注', bill.note, theme),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _delete(bill),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.dangerColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('删除此账单', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildEditView(bill, ThemeProvider theme) {
    return Column(
      children: [
        // Type toggle
        Row(
          children: [
            Expanded(child: _buildTypeBtn('expense', '支出', theme)),
            const SizedBox(width: 8),
            Expanded(child: _buildTypeBtn('income', '收入', theme)),
          ],
        ),
        const SizedBox(height: 12),

        // Amount
        TextField(
          controller: _amountCtrl,
          style: TextStyle(
            fontSize: 36, fontWeight: FontWeight.w700,
            color: _editType == 'expense' ? theme.expenseColor : theme.incomeColor,
          ),
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '金额',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            filled: true,
            fillColor: theme.inputBgColor,
          ),
        ),
        const SizedBox(height: 12),

        // Categories
        Align(
          alignment: Alignment.centerLeft,
          child: Text('分类', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: _categories.map((c) {
            final selected = _editCategory == c.label;
            final color = Color(int.parse(c.color.replaceAll('#', '0xFF')));
            return GestureDetector(
              onTap: () => setState(() => _editCategory = c.label),
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

        // Date
        Align(
          alignment: Alignment.centerLeft,
          child: Text('日期', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _dateCtrl,
          style: TextStyle(fontSize: 14, color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            filled: true,
            fillColor: theme.inputBgColor,
          ),
        ),
        const SizedBox(height: 12),

        // Note
        Align(
          alignment: Alignment.centerLeft,
          child: Text('备注', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _noteCtrl,
          style: TextStyle(fontSize: 14, color: theme.textColor),
          maxLength: 100,
          decoration: InputDecoration(
            hintText: '备注',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.borderColor),
            ),
            filled: true,
            fillColor: theme.inputBgColor,
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBtn(String type, String label, ThemeProvider theme) {
    final active = _editType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _editType = type);
        _loadCategories();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? (type == 'expense' ? theme.expenseColor : theme.incomeColor)
              : theme.inputBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : theme.textColor,
        )),
      ),
    );
  }

  Widget _detailRow(String label, String value, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.textColor)),
        ],
      ),
    );
  }
}
