import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat('#,##0.00');

String formatCurrency(double amount) {
  return '¥${_currencyFormat.format(amount)}';
}

String formatAmountInput(String text) {
  // Allow only digits and one decimal point
  String cleaned = text.replaceAll(RegExp(r'[^\d.]'), '');

  // Ensure only one decimal point
  final parts = cleaned.split('.');
  if (parts.length > 2) {
    cleaned = '${parts[0]}.${parts.sublist(1).join()}';
  }

  // Limit decimal places to 2
  if (parts.length == 2 && parts[1].length > 2) {
    cleaned = '${parts[0]}.${parts[1].substring(0, 2)}';
  }

  return cleaned;
}

double parseAmountInput(String text) {
  return double.tryParse(text) ?? 0;
}
