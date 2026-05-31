import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/ledger_provider.dart';
import '../widgets/glass_container.dart';

const ledgerColors = ['#4A90D9', '#E74C3C', '#2ECC71', '#F39C12', '#9B59B6', '#1ABC9C', '#E67E22'];

class LedgerManageScreen extends StatefulWidget {
  const LedgerManageScreen({super.key});

  @override
  State<LedgerManageScreen> createState() => _LedgerManageScreenState();
}

class _LedgerManageScreenState extends State<LedgerManageScreen> {
  bool _showCreate = false;
  final _nameController = TextEditingController();
  String _selectedColor = '#4A90D9';
  int? _editingId;
  final _editController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入账本名称')));
      return;
    }
    await context.read<LedgerProvider>().createLedger(name, color: _selectedColor);
    _nameController.clear();
    setState(() { _showCreate = false; _selectedColor = '#4A90D9'; });
  }

  Future<void> _delete(int id) async {
    final provider = context.read<LedgerProvider>();
    if (provider.ledgers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('至少保留一个账本')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除账本将同时删除其下所有账单数据'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('确认删除')),
        ],
      ),
    );
    if (confirmed == true) {
      provider.deleteLedger(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final ledgerProvider = context.watch<LedgerProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    return ListView(
      padding: EdgeInsets.only(top: topSafe, left: 16, right: 16, bottom: 30),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text('← 返回', style: TextStyle(fontSize: 16, color: theme.primaryColor)),
              ),
              Text('账本管理', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textColor)),
              GestureDetector(
                onTap: () => setState(() => _showCreate = !_showCreate),
                child: Text(_showCreate ? '取消' : '+ 新增',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.primaryColor)),
              ),
            ],
          ),
        ),

        // Create form
        if (_showCreate)
          GlassContainer(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: TextStyle(fontSize: 14, color: theme.textColor),
                  decoration: InputDecoration(
                    hintText: '账本名称 (如: 家庭、旅行)',
                    hintStyle: TextStyle(color: theme.textSecondaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.borderColor),
                    ),
                    filled: true,
                    fillColor: theme.inputBgColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ledgerColors.map((c) {
                    final color = Color(int.parse(c.replaceAll('#', '0xFF')));
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        width: 32, height: 32,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == c ? Colors.white : Colors.transparent,
                            width: _selectedColor == c ? 3 : 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _create,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('创建账本', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

        // Ledger list
        ...ledgerProvider.ledgers.map((ledger) {
          return GlassContainer(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: Color(int.parse(ledger.color.replaceAll('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _editingId == ledger.id
                      ? TextField(
                          controller: _editController,
                          style: TextStyle(fontSize: 16, color: theme.textColor),
                          autofocus: true,
                          decoration: InputDecoration(
                            border: UnderlineInputBorder(borderSide: BorderSide(color: theme.primaryColor)),
                          ),
                          onSubmitted: (v) {
                            if (v.trim().isNotEmpty) {
                              ledgerProvider.updateLedger(ledger.id!, v.trim());
                            }
                            setState(() => _editingId = null);
                          },
                        )
                      : GestureDetector(
                          onTap: () {
                            ledgerProvider.switchLedger(ledger.id!);
                            Navigator.pop(context);
                          },
                          child: Text(
                            '${ledger.name}${ledger.id == ledgerProvider.activeLedger?.id ? ' ✓' : ''}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.textColor),
                          ),
                        ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() { _editingId = ledger.id; _editController.text = ledger.name; });
                  },
                  child: Text('编辑', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.primaryColor)),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _delete(ledger.id!),
                  child: Text('删除', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.dangerColor)),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 60),
      ],
    );
  }
}
