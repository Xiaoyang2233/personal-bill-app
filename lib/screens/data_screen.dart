import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
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
  String _nextBackupCountdown = '';

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
    _updateCountdown();
  }

  void _updateCountdown() {
    if (!_autoBackup) {
      setState(() => _nextBackupCountdown = '');
      return;
    }
    SharedPreferences.getInstance().then((prefs) {
      final now = DateTime.now();
      DateTime nextBackup;

      switch (_autoBackupPeriod) {
        case 'daily':
          // Next midnight (00:00 of next day)
          nextBackup = DateTime(now.year, now.month, now.day + 1);
          break;
        case 'weekly':
          // Next Monday at midnight
          final daysUntilMonday = (8 - now.weekday) % 7;
          final days = daysUntilMonday == 0 ? 7 : daysUntilMonday;
          nextBackup = DateTime(now.year, now.month, now.day + days);
          break;
        case 'monthly':
          // Next 1st of month at midnight
          if (now.month == 12) {
            nextBackup = DateTime(now.year + 1, 1, 1);
          } else {
            nextBackup = DateTime(now.year, now.month + 1, 1);
          }
          break;
        default:
          nextBackup = DateTime(now.year, now.month, now.day + 7);
      }

      final diff = nextBackup.difference(now);
      final totalMinutes = diff.inMinutes;
      final days = totalMinutes ~/ (24 * 60);
      final hours = (totalMinutes % (24 * 60)) ~/ 60;
      final minutes = totalMinutes % 60;
      String text = '距离下次自动备份还有：';
      if (days > 0) {
        text += '${days}天';
      } else {
        if (hours > 0) text += '${hours}小时';
        if (minutes > 0) text += '${minutes}分钟';
        if (hours == 0 && minutes == 0) text += '即将执行';
      }
      setState(() => _nextBackupCountdown = text);
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

  void _showChartColorHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('图表配色自定义使用指南'),
        content: const SingleChildScrollView(
          child: Text(
            '在这里你可以自定义每个分类的图表颜色，让你的收支图表更符合你的喜好。\n\n'
            '点击分类对应的颜色块，选择你想要的颜色\n'
            '选择完成后，点击保存\n\n'
            '⚠️ 注意：设置完成后，需要回到首页下拉刷新一下，图表颜色才会同步更新\n\n'
            '重启 APP 后，你的自定义配色会永久保存，不会丢失',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
  }

  void _showBackupHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('数据备份与恢复使用指南'),
        content: const SingleChildScrollView(
          child: Text(
            '💾 手动备份\n'
            '点击「更改」可以选择备份文件保存的位置（默认保存在手机下载文件夹）\n'
            '开启「加密备份」后，备份文件会用你设置的密码加密，别人拿到文件也看不到你的账单\n'
            '⚠️ 重要提醒：加密密码一定要记牢！忘记密码无法恢复备份数据！\n'
            '点击「创建备份」，等待几秒即可完成，备份文件会自动带上时间戳\n\n'
            '🔄 自动备份\n'
            '开启自动备份后，APP 会按照你选择的周期（每日 / 每周 / 每月）自动在后台创建备份\n'
            '每日备份在零点执行，每周备份在周一零点执行，每月备份在1号零点执行\n'
            '自动备份文件同样保存在你设置的位置，最多保留最近 10 个备份，旧备份会自动删除\n'
            '页面会显示距离下次自动备份的剩余时间，不足24小时会显示小时和分钟\n\n'
            '📥 从备份恢复\n'
            '点击「从备份恢复」，在文件管理器中选择你之前保存的.db 备份文件\n'
            '如果是加密备份，需要输入正确的密码才能恢复\n'
            '恢复会覆盖当前 APP 内的所有数据，建议恢复前先手动备份一次当前数据\n\n'
            '⚠️ 重要注意事项\n'
            '备份文件是你的账单数据唯一保障，建议定期手动备份并保存到云盘或电脑\n'
            '卸载 APP 会删除 APP 内的所有数据，但不会删除你保存在下载文件夹的备份文件\n'
            '更换手机时，把备份文件复制到新手机，即可一键恢复所有账单',
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
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(result.path)]);
            },
            child: const Text('分享'),
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
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(result.path)]);
            },
            child: const Text('分享'),
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
                        if (v) {
                          _showAutoBackupConfirm();
                        } else {
                          _showAutoBackupDisableConfirm();
                        }
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
                  if (_nextBackupCountdown.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_nextBackupCountdown,
                      style: TextStyle(fontSize: 12, color: theme.primaryColor)),
                  ],
                  const SizedBox(height: 8),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('图表配色设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
                    GestureDetector(
                      onTap: _showChartColorHelp,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.help_outline, size: 20, color: theme.textSecondaryColor),
                      ),
                    ),
                  ],
                ),
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
    final isBackupPeriod = value == 'daily' || value == 'weekly' || value == 'monthly';
    final selected = isBackupPeriod
        ? _autoBackupPeriod == value
        : _exportRange == value;
    return GestureDetector(
      onTap: () {
        if (isBackupPeriod && _autoBackupPeriod != value) {
          _showPeriodChangeConfirm(value);
        } else if (!isBackupPeriod) {
          setState(() => _exportRange = value);
        }
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

  void _showAutoBackupConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('开启自动备份'),
        content: const Text('确定要开启自动备份吗？开启后APP将按照设定周期自动创建备份文件。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _autoBackup = true);
              _saveSettings();
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('auto_backup_last_time', DateTime.now().toIso8601String());
                _updateCountdown();
              });
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAutoBackupDisableConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭自动备份'),
        content: const Text('确定要关闭自动备份吗？关闭后将不再自动创建备份文件，建议定期手动备份。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _autoBackup = false);
              _saveSettings();
              _updateCountdown();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showPeriodChangeConfirm(String newPeriod) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更改备份周期'),
        content: const Text('确定要更改备份周期吗？更改后会重置自动备份的倒计时，下次备份时间将重新计算。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _autoBackupPeriod = newPeriod);
              _saveSettings();
              // Reset last backup time so countdown starts fresh
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('auto_backup_last_time', DateTime.now().toIso8601String());
                _updateCountdown();
              });
            },
            child: const Text('确定'),
          ),
        ],
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
