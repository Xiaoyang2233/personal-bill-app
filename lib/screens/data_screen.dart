import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/ledger_provider.dart';
import '../database/backup_service.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import '../widgets/glass_container.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _backupService = BackupService();
  bool _encryptBackup = false;
  final _passwordController = TextEditingController();
  String _exportRange = 'month';
  bool _loading = false;
  String? _loadingLabel;

  bool _autoBackup = false;
  String _autoBackupPeriod = 'weekly'; // 'daily', 'weekly', 'monthly'

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoBackup = prefs.getBool('auto_backup') ?? false;
      _autoBackupPeriod = prefs.getString('auto_backup_period') ?? 'weekly';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup', _autoBackup);
    await prefs.setString('auto_backup_period', _autoBackupPeriod);
  }

  Future<void> _loadData() async {
    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger != null) {
      await context.read<BillProvider>().loadBills(ledger.id!);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  ({String? start, String? end}) _getDateFilter() {
    if (_exportRange == 'month') {
      final now = DateTime.now();
      final m = now.month.toString().padLeft(2, '0');
      final lastDay = DateTime(now.year, now.month + 1, 0).day.toString().padLeft(2, '0');
      return (start: '${now.year}-$m-01', end: '${now.year}-$m-$lastDay');
    }
    if (_exportRange == 'week') {
      return (start: getDaysAgo(7), end: getToday());
    }
    return (start: null, end: null);
  }

  Future<void> _createBackup() async {
    setState(() { _loading = true; _loadingLabel = 'backup'; });
    try {
      final path = await _backupService.createBackup(
        password: _encryptBackup ? _passwordController.text : null,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('备份成功'),
            content: Text('备份文件已保存到:\n$path'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
              TextButton(
                onPressed: () {
                  Share.shareXFiles([XFile(path)]);
                  Navigator.pop(ctx);
                },
                child: const Text('分享'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('备份失败: $e')));
      }
    }
    setState(() { _loading = false; _loadingLabel = null; });
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    setState(() { _loading = true; _loadingLabel = 'restore'; });
    try {
      await _backupService.restoreBackup(
        result.files.first.path!,
        password: _encryptBackup ? _passwordController.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('恢复成功，请重启应用以加载完整数据')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('恢复失败: $e')));
      }
    }
    setState(() { _loading = false; _loadingLabel = null; });
  }

  Future<void> _exportCsv() async {
    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger == null) return;

    setState(() { _loading = true; _loadingLabel = 'csv'; });
    try {
      final filter = _getDateFilter();
      final path = await _backupService.exportToCsv(ledger.id!, startDate: filter.start, endDate: filter.end);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导出成功'),
            content: const Text('CSV文件已生成'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
              TextButton(
                onPressed: () {
                  Share.shareXFiles([XFile(path)]);
                  Navigator.pop(ctx);
                },
                child: const Text('分享'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
    setState(() { _loading = false; _loadingLabel = null; });
  }

  Future<void> _exportExcel() async {
    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger == null) return;

    setState(() { _loading = true; _loadingLabel = 'excel'; });
    try {
      final filter = _getDateFilter();
      final path = await _backupService.exportToExcel(ledger.id!, startDate: filter.start, endDate: filter.end);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导出成功'),
            content: const Text('Excel文件已生成'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
              TextButton(
                onPressed: () {
                  Share.shareXFiles([XFile(path)]);
                  Navigator.pop(ctx);
                },
                child: const Text('分享'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
    setState(() { _loading = false; _loadingLabel = null; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final billProvider = context.watch<BillProvider>();
    final topSafe = MediaQuery.of(context).padding.top;
    final stats = billProvider.allTimeStats;

    return ListView(
      padding: EdgeInsets.only(top: topSafe + 8, left: 16, right: 16, bottom: 90),
      children: [
        // Backup Section
        GlassContainer(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('数据备份与恢复', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('加密备份', style: TextStyle(fontSize: 14, color: theme.textColor)),
                  Switch(
                    value: _encryptBackup,
                    onChanged: (v) => setState(() => _encryptBackup = v),
                    activeColor: theme.primaryColor,
                  ),
                ],
              ),
              if (_encryptBackup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      hintText: '设置备份密码',
                      hintStyle: TextStyle(color: theme.textSecondaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.borderColor),
                      ),
                      filled: true,
                      fillColor: theme.inputBgColor,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _buildButton(
                label: '创建备份',
                loading: _loadingLabel == 'backup',
                color: theme.primaryColor,
                textColor: Colors.white,
                onTap: _loading ? null : _createBackup,
              ),
              const SizedBox(height: 8),
              _buildOutlinedButton(
                label: '从备份恢复',
                loading: _loadingLabel == 'restore',
                borderColor: theme.primaryColor,
                textColor: theme.primaryColor,
                onTap: _loading ? null : _restore,
              ),
            ],
          ),
        ),

        // Auto Backup Settings
        GlassContainer(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('自动备份设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('自动备份', style: TextStyle(fontSize: 14, color: theme.textColor)),
                  Switch(
                    value: _autoBackup,
                    onChanged: (v) {
                      setState(() => _autoBackup = v);
                      _saveSettings();
                    },
                    activeColor: theme.primaryColor,
                  ),
                ],
              ),
              if (_autoBackup) ...[
                const SizedBox(height: 12),
                Text('备份周期', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChip('每日', 'daily'),
                    const SizedBox(width: 8),
                    _buildChip('每周', 'weekly'),
                    const SizedBox(width: 8),
                    _buildChip('每月', 'monthly'),
                  ],
                ),
                const SizedBox(height: 12),
                Text('开启后，APP将在备份周期内自动创建加密备份文件',
                  style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
              ],
            ],
          ),
        ),

        // Export Section
        GlassContainer(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('数据导出', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChip('本月', 'month'),
                  const SizedBox(width: 8),
                  _buildChip('近7天', 'week'),
                  const SizedBox(width: 8),
                  _buildChip('全部', 'all'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      label: '导出 CSV',
                      loading: _loadingLabel == 'csv',
                      color: theme.incomeColor,
                      textColor: Colors.white,
                      onTap: _loading ? null : _exportCsv,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildButton(
                      label: '导出 Excel',
                      loading: _loadingLabel == 'excel',
                      color: theme.primaryColor,
                      textColor: Colors.white,
                      onTap: _loading ? null : _exportExcel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Cumulative Stats
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('累计总览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStat('${formatCurrency(stats?.totalIncome ?? 0)}', '总收入', theme.incomeColor, theme),
                  _buildStat('${formatCurrency(stats?.totalExpense ?? 0)}', '总支出', theme.expenseColor, theme),
                  _buildStat(
                    '${formatCurrency((stats?.balance ?? 0).abs())}',
                    '总结余',
                    (stats?.balance ?? 0) >= 0 ? theme.incomeColor : theme.expenseColor,
                    theme,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 0.5, color: theme.borderColor),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStat('${stats?.recordCount ?? 0}', '总记录', theme.textColor, theme),
                  _buildStat(stats?.topCategory ?? '-', '最大支出类', theme.textColor, theme),
                  _buildStat(formatCurrency(stats?.avgExpense ?? 0), '笔均支出', theme.textColor, theme),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, String value) {
    final theme = context.watch<ThemeProvider>();
    final selected = value == 'daily' || value == 'weekly' || value == 'monthly'
        ? _autoBackupPeriod == value
        : _exportRange == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (value == 'daily' || value == 'weekly' || value == 'monthly') {
            _autoBackupPeriod = value;
            _saveSettings();
          } else {
            _exportRange = value;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.primaryColor : theme.inputBgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: selected ? Colors.white : theme.textColor,
        )),
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color, ThemeProvider theme) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required bool loading,
    required Color color,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withAlpha(50),
        highlightColor: color.withAlpha(30),
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(label, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required String label,
    required bool loading,
    required Color borderColor,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: borderColor.withAlpha(30),
        highlightColor: borderColor.withAlpha(20),
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
                : Text(label, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
