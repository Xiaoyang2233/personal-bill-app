String getToday() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String getDaysAgo(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String getMonthName(int month) {
  const names = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
  return names[month - 1];
}

String formatDisplayDate(String date) {
  // date format: YYYY-MM-DD
  final parts = date.split('-');
  if (parts.length != 3) return date;
  final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = today.difference(target).inDays;

  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff < 7) return '$diff天前';

  return '${d.month}月${d.day}日';
}
