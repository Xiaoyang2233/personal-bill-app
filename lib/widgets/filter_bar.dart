import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../database/category_service.dart';
import '../models/category.dart';

class FilterBar extends StatefulWidget {
  final String filterType; // 'all', 'expense', 'income'
  final ValueChanged<String> onTypeChanged;
  final String dateRange; // 'month', 'week', 'all'
  final ValueChanged<String> onDateRangeChanged;
  final String filterCategory;
  final ValueChanged<String> onCategoryChanged;

  const FilterBar({
    super.key,
    required this.filterType,
    required this.onTypeChanged,
    required this.dateRange,
    required this.onDateRangeChanged,
    required this.filterCategory,
    required this.onCategoryChanged,
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  List<CustomCategory> _expenseCats = [];
  List<CustomCategory> _incomeCats = [];
  final _categoryService = CategoryService();

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    _expenseCats = await _categoryService.getCategories('expense');
    _incomeCats = await _categoryService.getCategories('income');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    final typeOptions = [
      ('全部', 'all'), ('支出', 'expense'), ('收入', 'income'),
    ];
    final dateOptions = [
      ('本月', 'month'), ('近7天', 'week'), ('全部', 'all'),
    ];

    // Gather relevant categories
    final catOptions = <(String, String)>[('全部分类', 'all')];
    if (widget.filterType == 'expense' || widget.filterType == 'all') {
      catOptions.addAll(_expenseCats.map((c) => (c.label, c.label)));
    }
    if (widget.filterType == 'income' || widget.filterType == 'all') {
      catOptions.addAll(_incomeCats.map((c) => (c.label, c.label)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type filter
          Wrap(
            spacing: 8,
            children: typeOptions.map((opt) => _buildChip(
              label: opt.$1,
              selected: widget.filterType == opt.$2,
              onTap: () => widget.onTypeChanged(opt.$2),
              theme: theme,
            )).toList(),
          ),
          const SizedBox(height: 6),
          // Date range filter
          Wrap(
            spacing: 8,
            children: dateOptions.map((opt) => _buildChip(
              label: opt.$1,
              selected: widget.dateRange == opt.$2,
              onTap: () => widget.onDateRangeChanged(opt.$2),
              theme: theme,
            )).toList(),
          ),
          const SizedBox(height: 6),
          // Category filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: catOptions.take(10).map((opt) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(
                  label: opt.$1,
                  selected: widget.filterCategory == opt.$2,
                  onTap: () => widget.onCategoryChanged(opt.$2),
                  theme: theme,
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ThemeProvider theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: selected ? Colors.white : theme.textColor,
        )),
      ),
    );
  }
}
