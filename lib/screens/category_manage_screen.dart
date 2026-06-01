import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/bill_provider.dart';
import '../database/category_service.dart';
import '../database/bill_service.dart';
import '../models/category.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_background.dart';

const colorOptions = [
  '#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF',
  '#FF9F40', '#C9CBCF', '#7BC8A4', '#E8A87C', '#95A5A6',
  '#2ECC71', '#3498DB', '#9B59B6', '#1ABC9C', '#E67E22',
];

const iconOptions = ['🍔', '🚌', '🛒', '🏠', '🎮', '💊', '📚', '📱', '🧴', '💰', '🎁', '📈', '💼', '↩️', '☕', '🐱', '✈️', '🏥', '💻', '🎵'];

class CategoryManageScreen extends StatefulWidget {
  const CategoryManageScreen({super.key});

  @override
  State<CategoryManageScreen> createState() => _CategoryManageScreenState();
}

class _CategoryManageScreenState extends State<CategoryManageScreen> {
  String _activeTab = 'expense'; // 'expense' or 'income'
  bool _showAdd = false;
  final _nameController = TextEditingController();
  String _newIcon = '📌';
  String _newColor = '#95A5A6';
  List<CustomCategory> _categories = [];
  final _categoryService = CategoryService();

  // Inline editing state
  String? _editingLabel;
  final _editController = TextEditingController();
  String? _editingIcon;
  String? _editingColor;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    _categories = await _categoryService.getCategories(_activeTab);
    setState(() {});
  }

  Future<void> _switchTab(String type) async {
    _activeTab = type;
    await _loadCategories();
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入分类名称'), duration: Duration(seconds: 1)));
      return;
    }
    if (_categories.any((c) => c.label == name)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分类名称已存在'), duration: Duration(seconds: 1)));
      return;
    }
    await _categoryService.addCategory(_activeTab, name, _newIcon, _newColor);
    _nameController.clear();
    setState(() { _showAdd = false; _newIcon = '📌'; _newColor = '#95A5A6'; });
    await _loadCategories();
    if (mounted) context.read<BillProvider>().loadBills(context.read<LedgerProvider>().activeLedger!.id!);
  }

  Future<void> _delete(CustomCategory cat) async {
    if (cat.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('默认分类不可删除，但可以编辑')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除"${cat.label}"分类后，已有账单的分类不受影响'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      await _categoryService.deleteCategory(_activeTab, cat.label);
      await _loadCategories();
      if (mounted) context.read<BillProvider>().loadBills(context.read<LedgerProvider>().activeLedger!.id!);
    }
  }

  void _startEditing(CustomCategory cat) {
    setState(() {
      _editingLabel = cat.label;
      _editController.text = cat.label;
      _editingIcon = cat.icon;
      _editingColor = cat.color;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingLabel = null;
      _editingIcon = null;
      _editingColor = null;
    });
  }

  Future<void> _saveEditing(String oldLabel) async {
    final newName = _editController.text.trim();
    final newIcon = _editingIcon;
    final newColor = _editingColor;

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('分类名称不能为空')));
      return;
    }

    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger == null) return;

    // Rename in bills if name changed
    if (newName != oldLabel) {
      await BillService().renameCategory(ledger.id!, oldLabel, newName);
    }

    // Update the category in the list
    final cats = await _categoryService.getCategories(_activeTab);
    final idx = cats.indexWhere((c) => c.label == oldLabel);
    if (idx >= 0) {
      cats[idx] = CustomCategory(
        label: newName,
        icon: newIcon ?? cats[idx].icon,
        color: newColor ?? cats[idx].color,
        isDefault: cats[idx].isDefault,
      );
      await _categoryService.saveCategories(_activeTab, cats);
    }

    setState(() {
      _editingLabel = null;
      _editingIcon = null;
      _editingColor = null;
    });

    await _loadCategories();
    if (mounted) context.read<BillProvider>().loadBills(ledger.id!);
  }

  Future<void> _moveCategory(int oldIndex, int newIndex) async {
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    setState(() {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(adjustedIndex, item);
    });
    await _categoryService.saveCategories(_activeTab, _categories);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: ListView(
          padding: EdgeInsets.only(top: topSafe, left: 16, right: 16, bottom: 100),
          children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
  ScaffoldMessenger.of(context).clearSnackBars();
  Navigator.pop(context);
},
                  child: Text('← 返回', style: TextStyle(fontSize: 16, color: theme.primaryColor)),
                ),
                Text('分类管理', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textColor)),
                GestureDetector(
                  onTap: () => setState(() => _showAdd = !_showAdd),
                  child: Text(_showAdd ? '取消' : '+ 新增',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.primaryColor)),
                ),
              ],
            ),
          ),

          // Tab toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab('expense'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _activeTab == 'expense' ? theme.primaryColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text('支出分类', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: _activeTab == 'expense' ? theme.primaryColor : theme.textSecondaryColor,
                    )),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _switchTab('income'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _activeTab == 'income' ? theme.primaryColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text('收入分类', style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: _activeTab == 'income' ? theme.primaryColor : theme.textSecondaryColor,
                    )),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Add form
          if (_showAdd)
            GlassContainer(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    style: TextStyle(fontSize: 14, color: theme.textColor),
                    decoration: InputDecoration(
                      hintText: '分类名称',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.primaryColor),
                      ),
                      filled: true,
                      fillColor: theme.inputBgColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('图标:', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: iconOptions.map((icon) => GestureDetector(
                              onTap: () => setState(() => _newIcon = icon),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: _newIcon == icon ? theme.primaryColor.withAlpha(48) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(icon, style: const TextStyle(fontSize: 22)),
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('颜色:', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: colorOptions.map((c) {
                              final color = Color(int.parse(c.replaceAll('#', '0xFF')));
                              return GestureDetector(
                                onTap: () => setState(() => _newColor = c),
                                child: Container(
                                  width: 28, height: 28,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _newColor == c ? Colors.white : Colors.transparent,
                                      width: _newColor == c ? 3 : 2,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _add,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text('添加分类', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),

          // Drag hint
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('点击分类名称可编辑，拖拽 ≡ 手柄调整排序',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
          ),

          // Category list with drag reorder
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _categories.length,
            onReorder: _moveCategory,
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                elevation: 4,
                child: child,
              );
            },
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final color = Color(int.parse(cat.color.replaceAll('#', '0xFF')));
              final isEditing = _editingLabel == cat.label;

              return GlassContainer(
                key: ValueKey(cat.label),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: isEditing
                    ? _buildEditingRow(cat, theme)
                    : _buildDisplayRow(cat, color, theme),
              );
            },
          ),
          ],
        ),
      ),
      );
    }

  Widget _buildDisplayRow(CustomCategory cat, Color color, ThemeProvider theme) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(32),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(cat.icon, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(cat.label, style: TextStyle(fontSize: 15, color: theme.textColor)),
        ),
        GestureDetector(
          onTap: () => _startEditing(cat),
          child: Text('编辑', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.primaryColor)),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _delete(cat),
          child: Text(cat.isDefault ? '默认' : '删除',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
              color: cat.isDefault ? theme.textSecondaryColor : theme.dangerColor)),
        ),
        const SizedBox(width: 8),
        ReorderableDragStartListener(
          index: _categories.indexOf(cat),
          child: Container(
            width: 36, height: 40,
            alignment: Alignment.center,
            child: Text('≡', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: theme.textSecondaryColor)),
          ),
        ),
      ],
    );
  }

  Widget _buildEditingRow(CustomCategory cat, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name input
        Row(
          children: [
            Text('名称:', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _editController,
                style: TextStyle(fontSize: 14, color: theme.textColor),
                autofocus: true,
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.primaryColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.primaryColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Icon selector
        Row(
          children: [
            Text('图标:', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: iconOptions.map((icon) => GestureDetector(
                    onTap: () => setState(() => _editingIcon = icon),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: _editingIcon == icon ? theme.primaryColor.withAlpha(48) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 18)),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Color selector
        Row(
          children: [
            Text('颜色:', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: colorOptions.map((c) {
                    final col = Color(int.parse(c.replaceAll('#', '0xFF')));
                    return GestureDetector(
                      onTap: () => setState(() => _editingColor = c),
                      child: Container(
                        width: 24, height: 24,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _editingColor == c ? Colors.white : Colors.transparent,
                            width: _editingColor == c ? 3 : 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _cancelEditing,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text('取消', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _saveEditing(cat.label),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text('保存', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
