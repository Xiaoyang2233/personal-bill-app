import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/ledger_provider.dart';
import '../database/backup_service.dart';
import '../database/storage_channel.dart';
import '../utils/currency_utils.dart';
import '../utils/date_utils.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_background.dart';
import 'chart_color_screen.dart';

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
  String _autoBackupPeriod = 'weekly';
  int? _loadedLedgerId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _requestPermission();
    final ledgerProvider = context.read<LedgerProvider>();
    ledgerProvider.addListener(_onLedgerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDataIfReady());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _onLedgerChanged() {
    _loadDataIfReady();
  }

  void _loadDataIfReady() {
    final ledger = context.read<LedgerProvider>().activeLedger;
    if (ledger != null && ledger.id != _loadedLedgerId) {
      _loadedLedgerId = ledger.id;
      _loadData();
    }
  }

  Future<void> _requestPermission() async {
    await StorageChannel.requestStoragePermission();
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

  String _defaultExportName() {
    final now = DateTime.now();
    final d = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '记一笔_账单导出_$d';
  }

  void _showBackupHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('数据备份说明'),
        content: const SingleChildScrollView(
          child: Text(
            '1. 备份文件保存到手机公共下载目录：\n   /Download/记一笔/备份/\n\n'
            '2. 导出文件保存到：\n   /Download/记一笔/导出/\n\n'
            '3. 备份文件名格式：记一笔_备份_2026-06-01_16-26.db\n\n'
            '4. 开启「加密备份」可为备份文件设置密码保护\n\n'
            '5. 自动备份功能会在设定周期内自动创建备份\n\n'
            '6. 可在文件管理器的Download/记一笔目录中找到所有文件',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
  }

  void _showBackupSuccess(BackupResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('备份成功'),
        content: Text('文件已保存到:\n${result.path}'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageChannel.openFile(result.path);
            },
            child: const Text('打开文件'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageChannel.openFolder('content://com.android.externalstorage.documents/document/primary%3ADownload%2F记一笔');
            },
            child: const Text('打开文件夹'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  void _showExportSuccess(BackupResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出成功'),
        content: Text('文件已保存到:\n${result.path}'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageChannel.openFile(result.path);
            },
            child: const Text('打开文件'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await StorageChannel.openFolder('content://com.android.externalstorage.documents/document/primary%3ADownload%2F记一笔');
            },
            child: const Text('打开文件夹'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    await _backupService.cleanupOldBackups();

    setState(() { _loading = true; _loadingLabel = 'backup'; });
    try {
      final result = await _backupService.createBackup(
        password: _encryptBackup ? _passwordController.text : null,
      );
      if (mounted) {
        _showBackupSuccess(result);
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

    final name = await _showNameDialog(_defaultExportName());
    if (name == null) return;

    setState(() { _loading = true; _loadingLabel = 'csv'; });
    try {
      final filter = _getDateFilter();
      final result = await _backupService.exportToCsv(ledger.id!,
        startDate: filter.start, endDate: filter.end, customName: name);
      if (mounted) {
        _showExportSuccess(result);
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

    final name = await _showNameDialog(_defaultExportName());
    if (name == null) return;

    setState(() { _loading = true; _loadingLabel = 'excel'; });
    try {
      final filter = _getDateFilter();
      final result = await _backupService.exportToExcel(ledger.id!,
        startDate: filter.start, endDate: filter.end, customName: name);
      if (mounted) {
        _showExportSuccess(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
    setState(() { _loading = false; _loadingLabel = null; });
  }

  Future<String?> _showNameDialog(String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出文件名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入文件名',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.pop(ctx, name.isEmpty ? defaultName : name);
            },
            child: const Text('导出'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final billProvider = context.watch<BillProvider>();
    final topSafe = MediaQuery.of(context).padding.top;
    final stats = billProvider.allTimeStats;

    return AppBackground(
      child: ListView(
        padding: EdgeInsets.only(top: topSafe + 8, left: 16, right: 16, bottom: 90),
        children: [
          // Backup Section
          GlassContainer(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('数据备份与恢复', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
                    GestureDetector(
                      onTap: _showBackupHelp,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.help_outline, size: 20, color: theme.textSecondaryColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('备份保存到: Download/记一笔/备份/', style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
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
                  Text('开启后，APP将在备份周期内自动创建备份文件',
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
                const SizedBox(height: 8),
                Text('导出保存到: Download/记一笔/导出/', style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
                const SizedBox(height: 12),
                Text('导出时间范围', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                const SizedBox(height: 6),
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

          // Chart Color Settings
          GlassContainer(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('图表配色设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
                const SizedBox(height: 8),
                Text('自定义饼图分类颜色和趋势图线条颜色',
                  style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                const SizedBox(height: 12),
                _buildOutlinedButton(
                  label: '打开配色设置',
                  loading: false,
                  borderColor: theme.primaryColor,
                  textColor: theme.primaryColor,
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChartColorScreen())),
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
                    _buildStat(formatCurrency(stats?.totalIncome ?? 0), '总收入', theme.incomeColor, theme),
                    _buildStat(formatCurrency(stats?.totalExpense ?? 0), '总支出', theme.expenseColor, theme),
                    _buildStat(
                      formatCurrency((stats?.balance ?? 0).abs()),
                      '总结余',
                      (stats?.balance ?? 0) >= 0 ? theme.incomeColor : theme.expenseColor,
                      theme,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
      ),
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
