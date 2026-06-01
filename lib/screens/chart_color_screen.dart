import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../database/category_service.dart';
import '../models/category.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_background.dart';

class ChartColorScreen extends StatefulWidget {
  const ChartColorScreen({super.key});

  @override
  State<ChartColorScreen> createState() => _ChartColorScreenState();
}

class _ChartColorScreenState extends State<ChartColorScreen> {
  List<CustomCategory> _expenseCats = [];
  List<CustomCategory> _incomeCats = [];
  final _categoryService = CategoryService();
  Map<String, String> _customColors = {};
  String _trendIncomeColor = '#4ECDC4';
  String _trendExpenseColor = '#FF6B6B';

  static const presetColors = [
    '#FF6B6B', '#FF9F43', '#54A0FF', '#4ECDC4', '#45B7D1',
    '#96CEB4', '#FFEAA7', '#A29BFE', '#DDA0DD', '#98D8C8',
    '#FF6384', '#36A2EB', '#FFCE56', '#9966FF', '#2ECC71',
    '#E67E22', '#1ABC9C', '#F39C12', '#E74C3C', '#3498DB',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _expenseCats = await _categoryService.getCategories('expense');
    _incomeCats = await _categoryService.getCategories('income');
    final prefs = await SharedPreferences.getInstance();
    final colors = <String, String>{};
    for (final cat in [..._expenseCats, ..._incomeCats]) {
      final c = prefs.getString('chart_color_${cat.label}');
      if (c != null) colors[cat.label] = c;
    }
    setState(() {
      _customColors = colors;
      _trendIncomeColor = prefs.getString('chart_trend_income') ?? '#4ECDC4';
      _trendExpenseColor = prefs.getString('chart_trend_expense') ?? '#FF6B6B';
    });
  }

  Future<void> _setColor(String category, String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chart_color_$category', color);
    setState(() => _customColors[category] = color);
  }

  Future<void> _setTrendColor(String key, String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, color);
    setState(() {
      if (key == 'chart_trend_income') _trendIncomeColor = color;
      if (key == 'chart_trend_expense') _trendExpenseColor = color;
    });
  }

  Future<void> _resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final cat in [..._expenseCats, ..._incomeCats]) {
      await prefs.remove('chart_color_${cat.label}');
    }
    await prefs.remove('chart_trend_income');
    await prefs.remove('chart_trend_expense');
    setState(() {
      _customColors = {};
      _trendIncomeColor = '#4ECDC4';
      _trendExpenseColor = '#FF6B6B';
    });
  }

  String _effectiveColor(CustomCategory cat) {
    return _customColors[cat.label] ?? cat.color;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: ListView(
          padding: EdgeInsets.only(top: topSafe, left: 16, right: 16, bottom: 100),
          children: [
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
                  Text('图表配色', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textColor)),
                  GestureDetector(
                    onTap: _resetAll,
                    child: Text('重置', style: TextStyle(fontSize: 15, color: theme.dangerColor)),
                  ),
                ],
              ),
            ),

            // Expense categories
            GlassContainer(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('支出分类配色', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textColor)),
                  const SizedBox(height: 12),
                  ..._expenseCats.map((cat) => _buildColorRow(cat, theme)),
                ],
              ),
            ),

            // Income categories
            GlassContainer(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('收入分类配色', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textColor)),
                  const SizedBox(height: 12),
                  ..._incomeCats.map((cat) => _buildColorRow(cat, theme)),
                ],
              ),
            ),

            // Trend chart colors
            GlassContainer(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('趋势图配色', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textColor)),
                  const SizedBox(height: 12),
                  _buildTrendColorRow('收入线条', _trendIncomeColor, 'chart_trend_income', theme),
                  const SizedBox(height: 8),
                  _buildTrendColorRow('支出线条', _trendExpenseColor, 'chart_trend_expense', theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow(CustomCategory cat, ThemeProvider theme) {
    final current = _effectiveColor(cat);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(cat.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(cat.label, style: TextStyle(fontSize: 14, color: theme.textColor)),
          ),
          _colorDot(current, cat.label, 'category'),
        ],
      ),
    );
  }

  Widget _buildTrendColorRow(String label, String current, String key, ThemeProvider theme) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 14, color: theme.textColor)),
        ),
        _colorDot(current, key, 'trend'),
      ],
    );
  }

  Widget _colorDot(String currentColor, String identifier, String type) {
    return GestureDetector(
      onTap: () => _showColorPicker(currentColor, identifier, type),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Color(int.parse(currentColor.replaceAll('#', '0xFF'))),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
    );
  }

  void _showColorPicker(String currentColor, String identifier, String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = context.watch<ThemeProvider>();
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: theme.borderColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('选择颜色', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presetColors.map((c) {
                  final color = Color(int.parse(c.replaceAll('#', '0xFF')));
                  return GestureDetector(
                    onTap: () {
                      if (type == 'trend') {
                        _setTrendColor(identifier, c);
                      } else {
                        _setColor(identifier, c);
                      }
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: currentColor == c ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
