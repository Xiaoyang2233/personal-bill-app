import 'dart:convert';
import 'database_helper.dart';
import '../models/category.dart';

class CategoryService {
  final _db = DatabaseHelper.instance;

  static final defaultExpenseCategories = [
    CustomCategory(label: '餐饮', icon: '🍔', color: '#FF6B6B', isDefault: true),
    CustomCategory(label: '奶茶', icon: '🧋', color: '#FF9F43', isDefault: true),
    CustomCategory(label: '饮料', icon: '🥤', color: '#54A0FF', isDefault: true),
    CustomCategory(label: '交通', icon: '🚌', color: '#4ECDC4', isDefault: true),
    CustomCategory(label: '购物', icon: '🛒', color: '#45B7D1', isDefault: true),
    CustomCategory(label: '娱乐', icon: '🎮', color: '#96CEB4', isDefault: true),
    CustomCategory(label: '生活费', icon: '🏠', color: '#A29BFE', isDefault: true),
    CustomCategory(label: '其他', icon: '📌', color: '#98D8C8', isDefault: true),
  ];

  static final defaultIncomeCategories = [
    CustomCategory(label: '工资', icon: '💰', color: '#FFEAA7', isDefault: true),
    CustomCategory(label: '转账', icon: '↩️', color: '#DDA0DD', isDefault: true),
    CustomCategory(label: '其他', icon: '📌', color: '#98D8C8', isDefault: true),
  ];

  static const categoryColorMap = {
    '餐饮': '#FF6B6B', '奶茶': '#FF9F43', '饮料': '#54A0FF',
    '交通': '#4ECDC4', '购物': '#45B7D1', '娱乐': '#96CEB4',
    '工资': '#FFEAA7', '生活费': '#A29BFE', '转账': '#DDA0DD', '其他': '#98D8C8',
  };

  String _key(String type) => 'custom_categories_$type';

  Future<List<CustomCategory>> getCategories(String type) async {
    final json = await _db.getSetting(_key(type));
    if (json.isEmpty) {
      final defaults = type == 'expense' ? defaultExpenseCategories : defaultIncomeCategories;
      await saveCategories(type, defaults);
      return List.from(defaults);
    }
    try {
      final list = jsonDecode(json) as List;
      final categories = list.map((e) => CustomCategory.fromJson(e as Map<String, dynamic>)).toList();
      if (categories.isEmpty) {
        final defaults = type == 'expense' ? defaultExpenseCategories : defaultIncomeCategories;
        await saveCategories(type, defaults);
        return List.from(defaults);
      }
      return categories;
    } catch (_) {
      final defaults = type == 'expense' ? defaultExpenseCategories : defaultIncomeCategories;
      await saveCategories(type, defaults);
      return List.from(defaults);
    }
  }

  Future<void> saveCategories(String type, List<CustomCategory> categories) async {
    final json = jsonEncode(categories.map((c) => c.toJson()).toList());
    await _db.setSetting(_key(type), json);
  }

  Future<void> addCategory(String type, String label, String icon, String color) async {
    final categories = await getCategories(type);
    categories.add(CustomCategory(label: label, icon: icon, color: color));
    await saveCategories(type, categories);
  }

  Future<void> deleteCategory(String type, String label) async {
    final categories = await getCategories(type);
    categories.removeWhere((c) => c.label == label);
    await saveCategories(type, categories);
  }

  Future<List<CustomCategory>> moveCategory(String type, int from, int to) async {
    final categories = await getCategories(type);
    if (from < 0 || from >= categories.length || to < 0 || to >= categories.length) {
      return categories;
    }
    final item = categories.removeAt(from);
    categories.insert(to, item);
    await saveCategories(type, categories);
    return categories;
  }

  Future<String?> getCategoryIcon(String category, String type) async {
    final categories = await getCategories(type);
    for (final c in categories) {
      if (c.label == category) return c.icon;
    }
    return '📌';
  }

  Future<String?> getCategoryColor(String category, String type) async {
    final categories = await getCategories(type);
    for (final c in categories) {
      if (c.label == category) return c.color;
    }
    return '#95A5A6';
  }
}
