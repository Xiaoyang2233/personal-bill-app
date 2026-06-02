import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';
import '../providers/auto_bookkeeping_provider.dart';
import '../providers/pending_transaction_provider.dart';
import '../database/storage_channel.dart';
import '../widgets/glass_container.dart';
import 'ledger_manage_screen.dart';
import 'budget_manage_screen.dart';
import 'category_manage_screen.dart';
import 'developer_screen.dart';
import 'test_listener_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const presetColors = [
    '#F5F7FA', '#FFF8E1', '#E8F5E9', '#E3F2FD',
    '#FCE4EC', '#F3E5F5', '#EFEBE9', '#ECEFF1',
    '#1C1C1E', '#263238', '#1B5E20', '#0D47A1',
  ];

  static const _notificationCheckChannel = MethodChannel('com.finance.app/notification_check');
  AutoBookkeepingProvider? _pendingProvider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingProvider != null) {
      _checkPermissionAndEnable(_pendingProvider!);
      _pendingProvider = null;
    }
  }

  Future<void> _checkPermissionAndEnable(AutoBookkeepingProvider provider) async {
    final hasPermission = await provider.hasPermission();
    if (hasPermission) {
      provider.toggle(true);
      try {
        await _notificationCheckChannel.invokeMethod('showNotification');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = context.watch<ThemeProvider>();
    final topSafe = MediaQuery.of(context).padding.top;

    return ListView(
      padding: EdgeInsets.only(top: topSafe + 8, left: 16, right: 16, bottom: 90),
      children: [
        // Theme Mode
        GlassContainer(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('外观设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildThemeBtn('☀️ 白天', ThemeMode.light, theme),
                  const SizedBox(width: 8),
                  _buildThemeBtn('🌙 黑夜', ThemeMode.dark, theme),
                  const SizedBox(width: 8),
                  _buildThemeBtn('📱 跟随系统', ThemeMode.system, theme),
                ],
              ),
            ],
          ),
        ),

        // Background Settings
        GlassContainer(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('背景设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildToggleBtn('选择背景图', theme.backgroundType == 'image', () => theme.pickBackgroundImage(), theme),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildToggleBtn('纯色背景', theme.backgroundType == 'color',
                      () {
                        if (theme.backgroundType == 'image' && theme.backgroundImage.isNotEmpty) {
                          _showSwitchToColorDialog(theme);
                        } else {
                          theme.setBackgroundColor(theme.backgroundColor);
                        }
                      }, theme),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (theme.backgroundType == 'image' && theme.backgroundImage.isNotEmpty)
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: FileImage(File(theme.backgroundImage)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('背景透明度', style: TextStyle(fontSize: 13, color: theme.textColor)),
                  Text('${(theme.backgroundOpacity * 100).round()}%',
                    style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                ],
              ),
              Slider(
                value: theme.backgroundOpacity,
                min: 0,
                max: 1,
                activeColor: theme.primaryColor,
                inactiveColor: theme.borderColor,
                onChanged: (v) {
                  theme.setBackgroundOpacity(v);
                },
              ),
              if (theme.backgroundType == 'color')
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presetColors.map((c) {
                    final color = Color(int.parse(c.replaceAll('#', '0xFF')));
                    final selected = theme.backgroundColor == c;
                    return GestureDetector(
                      onTap: () => theme.setBackgroundColor(c),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? const Color(0xFF4A90D9) : Colors.transparent,
                            width: selected ? 3 : 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 10),
              _buildTextButton('重置背景', () => _showClearDialog(theme), theme),
            ],
          ),
        ),

        // Data Management
        GlassContainer(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('数据管理', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              _buildMenuItem('多账本管理', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerManageScreen())), theme),
              _buildMenuItem('预算管理', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetManageScreen())), theme),
              _buildMenuItem('分类管理', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManageScreen())), theme),
            ],
          ),
        ),

        // Auto Bookkeeping
        _buildAutoBookkeepingCard(theme),

        // About
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('关于', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('版本', style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
                  Text('1.3.0', style: TextStyle(fontSize: 14, color: theme.textColor)),
                ],
              ),
              const SizedBox(height: 4),
              _buildMenuItem('开发者', () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DeveloperScreen())), theme),
              _buildMenuItem('分享', () async {
                final apkPath = await StorageChannel.getApkPath();
                if (apkPath != null) {
                  Share.shareXFiles([XFile(apkPath)], text: '记一笔 - 简洁好用的个人记账APP');
                }
              }, theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoBookkeepingCard(ThemeProvider theme) {
    return Consumer<AutoBookkeepingProvider>(
      builder: (context, provider, _) {
        return GlassContainer(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('自动记账', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
                  GestureDetector(
                    onTap: _showAutoBookkeepingHelp,
                    child: Icon(Icons.help_outline, size: 20, color: theme.textSecondaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('检测微信、支付宝、云闪付支付通知，自动生成账单（仅支持Android）',
                style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('开启自动记账', style: TextStyle(fontSize: 14, color: theme.textColor)),
                  Switch(
                    value: provider.isEnabled,
                    onChanged: (v) {
                      if (v) {
                        _showPrivacyConfirmDialog(provider);
                      } else {
                        _showDisableConfirmDialog(provider);
                      }
                    },
                    activeColor: theme.primaryColor,
                  ),
                ],
              ),
              if (provider.isEnabled) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      provider.isListening ? Icons.check_circle : Icons.info_outline,
                      size: 16,
                      color: provider.isListening ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      provider.isListening ? '正在检测支付通知' : '等待权限授权...',
                      style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: theme.borderColor),
                const SizedBox(height: 8),
                Text('待处理提醒', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.textColor)),
                const SizedBox(height: 8),
                _buildReminderSettings(theme),
                const SizedBox(height: 12),
                _buildMenuItem('测试检测', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TestListenerPage()));
                }, theme),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildReminderSettings(ThemeProvider theme) {
    return Consumer<PendingTransactionProvider>(
      builder: (context, pendingProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('开启提醒', style: TextStyle(fontSize: 13, color: theme.textColor)),
                Switch(
                  value: pendingProvider.reminderEnabled,
                  onChanged: (v) => pendingProvider.setReminderEnabled(v),
                  activeColor: theme.primaryColor,
                ),
              ],
            ),
            if (pendingProvider.reminderEnabled) ...[
              const SizedBox(height: 8),
              Text('提醒时间', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildReminderChip('4小时', 4, pendingProvider, theme),
                  const SizedBox(width: 8),
                  _buildReminderChip('8小时', 8, pendingProvider, theme),
                  const SizedBox(width: 8),
                  _buildReminderChip('24小时', 24, pendingProvider, theme),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('自动忽略天数', style: TextStyle(fontSize: 13, color: theme.textColor)),
                  Text('${pendingProvider.autoIgnoreDays}天', style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
                ],
              ),
              const SizedBox(height: 4),
              Slider(
                value: pendingProvider.autoIgnoreDays.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                activeColor: theme.primaryColor,
                inactiveColor: theme.borderColor,
                onChanged: (v) => pendingProvider.setAutoIgnoreDays(v.round()),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildReminderChip(String label, int hours, PendingTransactionProvider provider, ThemeProvider theme) {
    final selected = provider.reminderHours == hours;
    return GestureDetector(
      onTap: () => provider.setReminderHours(hours),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.primaryColor : theme.inputBgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : theme.textColor,
        )),
      ),
    );
  }

  void _showPrivacyConfirmDialog(AutoBookkeepingProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 8),
            Text('隐私权限确认'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            '开启自动记账功能需要读取您的支付通知。\n\n'
            '✅ 所有数据仅在您的手机本地处理，绝对不会上传到任何服务器\n'
            '✅ 只会读取微信、支付宝、云闪付的支付通知，不会读取其他通知\n'
            '✅ 您可以随时关闭此功能，关闭后将立即停止检测\n\n'
            '是否确认开启自动记账功能？',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openNotificationListenerSettings(provider);
            },
            child: const Text('确认开启'),
          ),
        ],
      ),
    );
  }

  void _showDisableConfirmDialog(AutoBookkeepingProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭自动记账'),
        content: const Text('确定要关闭自动记账吗？关闭后将停止检测支付通知，不再自动生成账单。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.toggle(false);
            },
            child: const Text('确定关闭'),
          ),
        ],
      ),
    );
  }

  void _openNotificationListenerSettings(AutoBookkeepingProvider provider) async {
    _pendingProvider = provider;
    try {
      await _notificationCheckChannel.invokeMethod('openNotificationListenerSettings');
    } catch (_) {
      await openAppSettings();
    }
    // Permission check happens in didChangeAppLifecycleState when user returns
  }

  void _showAutoBookkeepingHelp() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text('自动记账功能使用指南', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Text(
                    '📖 什么是自动记账？\n'
                    '自动记账是「记一笔」的核心特色功能，它可以自动检测微信、支付宝、云闪付的支付通知，自动解析交易信息，弹出确认框，一键完成记账，无需你手动输入，大大提升记账效率！\n\n'
                    '🚀 开启自动记账的步骤\n\n'
                    '第一步：开启功能开关\n'
                    '1. 打开「记一笔」APP，进入设置页面\n'
                    '2. 找到「自动记账」选项，打开开关\n'
                    '3. 阅读隐私说明，确认开启\n\n'
                    '第二步：开启「通知使用权」权限\n'
                    '1. 点击开关后，会自动跳转到系统的「通知访问权限」页面\n'
                    '2. 在列表中找到「记一笔」，开启它的开关\n'
                    '3. 系统会弹出提示，点击「允许」确认\n'
                    '⚠️ 这是通知检测必须的权限，只有开启了这个权限，APP才能读取支付通知\n\n'
                    '第三步：开启「后台弹出界面」权限\n'
                    '1. 开启通知权限后，会引导你开启「后台弹出界面」权限\n'
                    '2. 找到「记一笔」，开启它的开关\n'
                    '⚠️ 这个权限是为了让APP在后台也能弹出确认框，否则锁屏或后台时无法弹出\n\n'
                    '第四步：开启后台保活权限（关键！）\n'
                    '这是最容易忽略的一步，也是功能是否稳定的关键！\n'
                    '不同品牌的手机设置位置不同：\n\n'
                    '📱 小米/Redmi手机\n'
                    '设置 → 应用设置 → 应用管理 → 记一笔\n'
                    '• 权限 → 后台弹出界面 → 允许\n'
                    '• 省电策略 → 无限制\n'
                    '• 自启动 → 开启\n'
                    '• 后台活动 → 开启\n\n'
                    '📱 华为手机\n'
                    '设置 → 应用和服务 → 应用管理 → 记一笔\n'
                    '• 权限 → 后台弹出界面 → 允许\n'
                    '• 电池 → 无限制\n'
                    '• 启动管理 → 关闭自动管理，开启允许自启动、允许后台活动\n\n'
                    '📱 OPPO/realme手机\n'
                    '设置 → 应用管理 → 应用管理 → 记一笔\n'
                    '• 权限 → 后台弹出界面 → 允许\n'
                    '• 电池 → 允许后台活动\n'
                    '• 自启动管理 → 开启\n\n'
                    '📱 vivo/iQOO手机\n'
                    '设置 → 应用与权限 → 应用管理 → 记一笔\n'
                    '• 权限 → 后台弹出界面 → 允许\n'
                    '• 电池 → 后台高耗电 → 开启\n'
                    '• 自启动 → 开启\n\n'
                    'ℹ️ 功能说明\n\n'
                    '✅ 支持的支付APP：\n'
                    '• 微信支付\n'
                    '• 支付宝\n'
                    '• 云闪付\n\n'
                    '🔧 工作原理：\n'
                    '1. 当你使用微信/支付宝/云闪付完成支付后，系统会收到一条支付通知\n'
                    '2.「记一笔」会在本地读取这条通知，自动解析出金额、商户、交易类型\n'
                    '3. 解析完成后，会弹出一个悬浮确认框，你只需要点击「确认记账」即可完成记账\n'
                    '4. 整个过程都是在你的手机本地完成的，不会上传任何数据到服务器！\n\n'
                    '🔒 隐私保护：\n'
                    '• 所有通知解析都是在你的手机本地完成，不会上传任何数据到任何服务器\n'
                    '• 我们只会读取微信/支付宝/云闪付的支付通知，其他所有通知都会被直接忽略\n'
                    '• 我们不会读取你的短信、聊天记录或任何其他私人数据\n'
                    '• 所有代码开源，你可以随时查看源码审计我们的逻辑\n\n'
                    '❓ 常见问题与排查\n\n'
                    'Q1：为什么支付后没有弹出确认框？\n'
                    'A：请检查以下几点：\n'
                    '• 检查「通知使用权」是否已经开启\n'
                    '• 检查「后台弹出界面」权限是否已经开启\n'
                    '• 检查微信/支付宝的通知权限是否开启\n'
                    '• 检查是否开启了后台保活权限，APP是否被系统杀死了\n\n'
                    'Q2：为什么有时候自动记账会失效？\n'
                    'A：大部分情况是系统把APP的后台服务杀死了，请：\n'
                    '• 按照上面的步骤，开启后台保活、自启动、无限制耗电权限\n'
                    '• 把APP加入到后台白名单，不要在最近任务里上滑关闭它\n'
                    '• 如果还是失效，可以重新打开「记一笔」，服务会自动重启\n\n'
                    'Q3：微信/支付宝的支付通知收不到？\n'
                    'A：请检查：\n'
                    '• 微信/支付宝的通知权限是否开启\n'
                    '• 微信/支付宝是否开启了「消息免打扰」\n'
                    '• 系统是否屏蔽了这两个APP的通知\n\n'
                    'Q4：这个功能会不会泄露我的隐私？\n'
                    'A：绝对不会！\n'
                    '• 所有数据处理都是在你的手机本地完成，没有任何网络请求\n'
                    '• 我们只会读取支付通知的内容，而且只会处理微信/支付宝/云闪付的通知\n'
                    '• 其他所有通知我们都会直接忽略，不会做任何处理\n'
                    '• 所有代码开源，你可以随时查看源码，确认我们的逻辑\n\n'
                    'Q5：为什么有些交易没有被识别？\n'
                    'A：目前我们支持大部分常见的支付通知格式，如果遇到没有识别的情况：\n'
                    '• 请确认支付后微信/支付宝确实弹出了通知\n'
                    '• 可以联系我们，把通知的内容发给我们，我们会更新解析规则',
                    style: TextStyle(fontSize: 14, height: 1.6),
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('知道了'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeBtn(String label, ThemeMode mode, ThemeProvider theme) {
    final active = theme.mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => theme.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? theme.primaryColor : theme.inputBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
            fontSize: 13,
            color: active ? Colors.white : theme.textColor,
          )),
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool active, VoidCallback onTap, ThemeProvider theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? theme.primaryColor : theme.inputBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          fontSize: 13,
          color: active ? Colors.white : theme.textColor,
        )),
      ),
    );
  }

  Widget _buildMenuItem(String label, VoidCallback onTap, ThemeProvider theme) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: theme.textColor)),
            Icon(Icons.chevron_right, color: theme.textSecondaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTextButton(String label, VoidCallback onTap, ThemeProvider theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 13, color: theme.textSecondaryColor)),
        ),
      ),
    );
  }

  void _showSwitchToColorDialog(ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('切换背景'),
        content: const Text('确定要切换为纯色背景吗？当前自定义背景将被清除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              theme.setBackgroundColor(theme.backgroundColor);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置背景'),
        content: const Text('确定要重置背景设置吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              theme.clearBackground();
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
