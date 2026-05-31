import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/bill.dart';
import 'glass_container.dart';

class TrendLineChart extends StatelessWidget {
  final List<DailyTotal> data;

  const TrendLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    if (data.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('暂无趋势数据', style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
        ),
      );
    }

    final displayData = data.length > 7 ? data.sublist(data.length - 7) : data;

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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
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
                      if (value.toInt() >= 0 && value.toInt() < displayData.length) {
                        final parts = displayData[value.toInt()].date.split('-');
                        return Text('${int.parse(parts[1])}/${int.parse(parts[2])}',
                          style: TextStyle(fontSize: 9, color: theme.textSecondaryColor));
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
                    spots: displayData.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value.expense)).toList(),
                    color: theme.expenseColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: displayData.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value.income)).toList(),
                    color: theme.incomeColor,
                    barWidth: 2,
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
              _legend('支出', theme.expenseColor, theme),
              const SizedBox(width: 16),
              _legend('收入', theme.incomeColor, theme),
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
