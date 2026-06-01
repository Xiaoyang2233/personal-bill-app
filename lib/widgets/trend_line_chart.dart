import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/bill.dart';
import '../utils/chart_color_utils.dart';
import 'glass_container.dart';

class TrendLineChart extends StatelessWidget {
  final List<DailyTotal> data;

  const TrendLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    final incomeColor = Color(int.parse((ChartColorUtils.getTrendIncomeColor() ?? '#4ECDC4').replaceAll('#', '0xFF')));
    final expenseColor = Color(int.parse((ChartColorUtils.getTrendExpenseColor() ?? '#FF6B6B').replaceAll('#', '0xFF')));

    // Generate fixed 7-day date range
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });

    // Build a map for quick lookup
    final dataMap = <String, DailyTotal>{};
    for (final d in data) {
      dataMap[d.date] = d;
    }

    // Create spots for all 7 days
    final spotsExpense = <FlSpot>[];
    final spotsIncome = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      final d = dataMap[last7Days[i]];
      spotsExpense.add(FlSpot(i.toDouble(), d?.expense ?? 0));
      spotsIncome.add(FlSpot(i.toDouble(), d?.income ?? 0));
    }

    String formatDate(String dateStr) {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${int.parse(parts[1])}月${int.parse(parts[2])}日';
      }
      return dateStr;
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('近7天收支趋势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textColor)),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
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
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max) return const Text('');
                      if (value == meta.min) return const Text('');
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 10, color: theme.textSecondaryColor),
                      );
                    },
                  )),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.round();
                      if (idx >= 0 && idx < 7) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(formatDate(last7Days[idx]),
                            style: TextStyle(fontSize: 9, color: theme.textSecondaryColor)),
                        );
                      }
                      return const Text('');
                    },
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsExpense,
                    color: expenseColor,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: spotsIncome,
                    color: incomeColor,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend('支出', expenseColor, theme),
              const SizedBox(width: 16),
              _legend('收入', incomeColor, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color, ThemeProvider theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
      ],
    );
  }
}
