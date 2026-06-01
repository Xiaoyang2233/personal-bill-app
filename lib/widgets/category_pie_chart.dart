import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/bill.dart';
import '../utils/currency_utils.dart';
import '../utils/chart_color_utils.dart';
import 'glass_container.dart';

class CategoryPieChart extends StatelessWidget {
  final List<CategoryBreakdown> data;
  final String title;

  const CategoryPieChart({super.key, required this.data, this.title = '支出分类'});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    if (data.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('暂无数据', style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
        ),
      );
    }

    final chartData = data.take(8).toList();

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textColor)),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: chartData.map((d) {
                  final c = ChartColorUtils.getCategoryColor(d.category, d.color);
                  final color = Color(int.parse(c.replaceAll('#', '0xFF')));
                  return PieChartSectionData(
                    value: d.total,
                    title: '${d.percentage.toStringAsFixed(0)}%',
                    color: color,
                    titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    radius: 60,
                  );
                }).toList(),
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...chartData.map((d) {
            final c = ChartColorUtils.getCategoryColor(d.category, d.color);
            final color = Color(int.parse(c.replaceAll('#', '0xFF')));
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d.category, style: TextStyle(fontSize: 13, color: theme.textColor))),
                  Text(formatCurrency(d.total), style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text('(${d.percentage.toStringAsFixed(1)}%)',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
