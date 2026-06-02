import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/bill.dart';
import '../utils/currency_utils.dart';
import '../utils/chart_color_utils.dart';
import 'glass_container.dart';

class CategoryBarChart extends StatelessWidget {
  final List<CategoryBreakdown> data;

  const CategoryBarChart({super.key, required this.data});

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

    final sorted = List<CategoryBreakdown>.from(data)
      ..sort((a, b) => b.total.compareTo(a.total));
    final display = sorted.take(8).toList();

    return RepaintBoundary(
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('支出分类对比', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textColor)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: display.isNotEmpty ? display.first.total * 1.2 : 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.borderColor,
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 10, color: theme.textSecondaryColor),
                      ),
                    )),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < display.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              display[value.toInt()].category.length > 2
                                  ? display[value.toInt()].category.substring(0, 2)
                                  : display[value.toInt()].category,
                              style: TextStyle(fontSize: 10, color: theme.textSecondaryColor),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: display.asMap().entries.map((e) {
                    final c = ChartColorUtils.getCategoryColor(e.value.category, e.value.color);
                    final color = Color(int.parse(c.replaceAll('#', '0xFF')));
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [BarChartRodData(
                        toY: e.value.total,
                        color: color,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      )],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...display.map((d) {
              final c = ChartColorUtils.getCategoryColor(d.category, d.color);
              final color = Color(int.parse(c.replaceAll('#', '0xFF')));
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d.category, style: TextStyle(fontSize: 12, color: theme.textColor))),
                    Text(formatCurrency(d.total), style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
