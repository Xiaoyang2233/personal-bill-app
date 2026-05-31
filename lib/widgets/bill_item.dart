import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../models/bill.dart';
import '../utils/currency_utils.dart';

class BillItem extends StatelessWidget {
  final Bill bill;
  final String icon;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const BillItem({
    super.key,
    required this.bill,
    required this.icon,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
            bottom: BorderSide(color: theme.borderColor, width: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: theme.inputBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.category, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.textColor)),
                  if (bill.note.isNotEmpty)
                    Text(bill.note, style: TextStyle(fontSize: 12, color: theme.textSecondaryColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text(
              '${bill.type == 'expense' ? '-' : '+'}${formatCurrency(bill.amount)}',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: bill.type == 'expense' ? theme.expenseColor : theme.incomeColor,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.dangerColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('删除', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
