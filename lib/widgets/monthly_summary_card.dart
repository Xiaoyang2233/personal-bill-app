import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/bill.dart';
import '../utils/currency_utils.dart';
import 'glass_container.dart';

class MonthlySummaryCard extends StatelessWidget {
  final int year;
  final String month;
  final MonthlyTotals totals;

  const MonthlySummaryCard({
    super.key,
    required this.year,
    required this.month,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Text(
            '${year}年$month',
            style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('收入', style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
                    const SizedBox(height: 6),
                    Text(
                      formatCurrency(totals.income),
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: theme.incomeColor),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: theme.borderColor),
              Expanded(
                child: Column(
                  children: [
                    Text('支出', style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
                    const SizedBox(height: 6),
                    Text(
                      formatCurrency(totals.expense),
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: theme.expenseColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 0.5, color: theme.borderColor),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('本月结余', style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
              Text(
                '${formatCurrency(totals.balance.abs())}${totals.balance < 0 ? ' (超支)' : ''}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: totals.balance >= 0 ? theme.incomeColor : theme.expenseColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
