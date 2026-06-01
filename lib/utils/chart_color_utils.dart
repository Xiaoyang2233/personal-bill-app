import 'package:shared_preferences/shared_preferences.dart';

class ChartColorUtils {
  static Map<String, String>? _cache;
  static String? _trendIncome;
  static String? _trendExpense;
  static bool _loaded = false;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cache = {};
    final keys = prefs.getKeys().where((k) => k.startsWith('chart_color_'));
    for (final k in keys) {
      _cache![k.replaceFirst('chart_color_', '')] = prefs.getString(k)!;
    }
    _trendIncome = prefs.getString('chart_trend_income');
    _trendExpense = prefs.getString('chart_trend_expense');
    _loaded = true;
  }

  static Future<void> reload() async {
    await load();
  }

  static void ensureLoaded() {
    if (!_loaded) {
      SharedPreferences.getInstance().then((prefs) {
        _cache = {};
        final keys = prefs.getKeys().where((k) => k.startsWith('chart_color_'));
        for (final k in keys) {
          _cache![k.replaceFirst('chart_color_', '')] = prefs.getString(k)!;
        }
        _trendIncome = prefs.getString('chart_trend_income');
        _trendExpense = prefs.getString('chart_trend_expense');
        _loaded = true;
      });
    }
  }

  static String getCategoryColor(String category, String defaultColor) {
    ensureLoaded();
    return _cache?[category] ?? defaultColor;
  }

  static String? getTrendIncomeColor() {
    ensureLoaded();
    return _trendIncome;
  }

  static String? getTrendExpenseColor() {
    ensureLoaded();
    return _trendExpense;
  }
}
