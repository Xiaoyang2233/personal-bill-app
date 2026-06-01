import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/bill_provider.dart';
import '../models/bill.dart';
import '../widgets/bill_item.dart';
import '../widgets/filter_bar.dart';
import '../widgets/empty_state.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import '../database/category_service.dart';
import 'bill_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filterType = 'all';
  String _dateRange = 'week';
  String _filterCategory = 'all';
  String _searchKeyword = '';
  final _searchController = TextEditingController();
  final _categoryService = CategoryService();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Bill> _getFilteredBills(BillProvider provider) {
    final now = DateTime.now();
    String? startDate, endDate;

    if (_dateRange == 'month') {
      final m = now.month.toString().padLeft(2, '0');
      final lastDay = DateTime(now.year, now.month + 1, 0).day.toString().padLeft(2, '0');
      startDate = '${now.year}-$m-01';
      endDate = '${now.year}-$m-$lastDay';
    } else if (_dateRange == 'week') {
      startDate = getDaysAgo(7);
      endDate = getToday();
    } else if (_dateRange == 'date' && _selectedDate != null) {
      final d = _selectedDate!;
      final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      startDate = ds;
      endDate = ds;
    }

    return provider.getFilteredBills(
      startDate: startDate,
      endDate: endDate,
      type: _filterType == 'all' ? null : _filterType,
      category: _filterCategory == 'all' ? null : _filterCategory,
      keyword: _searchKeyword.isEmpty ? null : _searchKeyword,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '选择查看日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateRange = 'date';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final billProvider = context.watch<BillProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    final filtered = _getFilteredBills(billProvider);

    // Group bills by date
    final grouped = <String, List<Bill>>{};
    for (final bill in filtered) {
      grouped.putIfAbsent(bill.date, () => []).add(bill);
    }
    final groups = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      children: [
        SizedBox(height: topSafe),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 14, color: theme.textColor),
              decoration: InputDecoration(
                hintText: '搜索备注...',
                hintStyle: TextStyle(color: theme.textSecondaryColor),
                prefixIcon: Icon(Icons.search, color: theme.textSecondaryColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchKeyword = v),
            ),
          ),
        ),

        // Filter bar
        FilterBar(
          filterType: _filterType,
          onTypeChanged: (v) => setState(() => _filterType = v),
          dateRange: _dateRange,
          onDateRangeChanged: (v) => setState(() => _dateRange = v),
          filterCategory: _filterCategory,
          onCategoryChanged: (v) => setState(() => _filterCategory = v),
          onPickDate: _pickDate,
        ),

        // Bill list
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(message: '暂无账单记录')
              : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final items = group.value;
                    final expSum = items.where((b) => b.type == 'expense').fold(0.0, (s, b) => s + b.amount);
                    final incSum = items.where((b) => b.type == 'income').fold(0.0, (s, b) => s + b.amount);

                    return Column(
                      children: [
                        // Date header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.transparent,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatDisplayDate(group.key),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textSecondaryColor)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.inputBgColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('支 ${formatCurrency(expSum)}',
                                      style: TextStyle(fontSize: 12, color: theme.expenseColor)),
                                    Text(' | ', style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
                                    Text('收 ${formatCurrency(incSum)}',
                                      style: TextStyle(fontSize: 12, color: theme.incomeColor)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bills
                        ...items.map((bill) => FutureBuilder<String?>(
                          future: _categoryService.getCategoryIcon(bill.category, bill.type),
                          builder: (ctx, snap) => BillItem(
                            bill: bill,
                            icon: snap.data ?? '📌',
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => BillDetailScreen(billId: bill.id!))),
                            onDelete: () => _confirmDelete(bill),
                          ),
                        )),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmDelete(Bill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await context.read<BillProvider>().deleteBill(bill.id!);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
