import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auto_bookkeeping_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_background.dart';

class TestListenerPage extends StatelessWidget {
  const TestListenerPage({super.key});

  static const _scenarios = [
    {
      'id': 'wechat_pay',
      'icon': '💚',
      'name': '微信支付',
      'description': '模拟微信支付 ¥88.00（测试超市）',
    },
    {
      'id': 'wechat_red_packet',
      'icon': '🧧',
      'name': '微信红包',
      'description': '模拟微信红包 ¥6.66',
    },
    {
      'id': 'alipay',
      'icon': '💙',
      'name': '支付宝',
      'description': '模拟支付宝付款 ¥25.50（测试便利店）',
    },
  ];

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
                    onTap: () => Navigator.pop(context),
                    child: Text('← 返回', style: TextStyle(fontSize: 16, color: theme.primaryColor)),
                  ),
                  Text('功能测试', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textColor)),
                  const SizedBox(width: 60),
                ],
              ),
            ),

            // Info card
            GlassContainer(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '模拟发送支付通知，测试自动记账功能是否正常工作。测试数据将出现在首页的待处理面板中。',
                      style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
                    ),
                  ),
                ],
              ),
            ),

            // Test scenarios
            GlassContainer(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('测试场景', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
                  const SizedBox(height: 12),
                  ..._scenarios.map((s) => _buildScenarioItem(context, s, theme)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioItem(BuildContext context, Map<String, String> scenario, ThemeProvider theme) {
    return GestureDetector(
      onTap: () => _showConfirmAndTest(context, scenario, theme),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.inputBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(scenario['icon']!, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scenario['name']!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.textColor)),
                  const SizedBox(height: 2),
                  Text(scenario['description']!, style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.textSecondaryColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showConfirmAndTest(BuildContext context, Map<String, String> scenario, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('测试通知'),
        content: Text('将模拟发送一条${scenario['name']}通知，确认继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AutoBookkeepingProvider>().sendTestNotification(
                scenario: scenario['id']!,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('测试通知已发送，请查看首页待处理面板')),
              );
            },
            child: const Text('发送测试'),
          ),
        ],
      ),
    );
  }
}
