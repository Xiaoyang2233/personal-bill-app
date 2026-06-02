import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/pending_transaction_provider.dart';
import '../models/pending_transaction.dart';
import '../utils/currency_utils.dart';
import 'pending_transaction_edit_screen.dart';

class PendingTransactionsPanel extends StatelessWidget {
  const PendingTransactionsPanel({super.key});

  static const _sourceIcons = {
    'com.tencent.mm': '💚',
    'com.eg.android.AlipayGphone': '💙',
    'com.unionpay': '🔴',
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final provider = context.watch<PendingTransactionProvider>();
    final panelWidth = MediaQuery.of(context).size.width * 0.85;

    return Stack(
      children: [
        // Scrim overlay (only when panel is open)
        if (provider.isPanelOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: provider.closePanel,
              child: Container(color: Colors.black26),
            ),
          ),
        // Panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: provider.isPanelOpen ? 0 : -panelWidth + 40,
          top: 0,
          bottom: 0,
          width: panelWidth,
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
                provider.closePanel();
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 10,
                          offset: const Offset(2, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildHeader(context, provider, theme),
                        if (provider.showReminder)
                          _buildReminderBanner(provider, theme),
                        Expanded(
                          child: provider.pendingItems.isEmpty
                              ? _buildEmptyState(theme)
                              : _buildTransactionList(context, provider, theme),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!provider.isPanelOpen)
                  GestureDetector(
                    onTap: provider.togglePanel,
                    child: Container(
                      width: 40,
                      margin: const EdgeInsets.only(top: 120),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_right, color: theme.textSecondaryColor.withAlpha(120), size: 20),
                          if (provider.pendingCount > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.dangerColor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${provider.pendingCount}',
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, PendingTransactionProvider provider, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('待处理交易', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textColor)),
              if (provider.pendingCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${provider.pendingCount}',
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _showPendingHelp(context, theme),
                child: Icon(Icons.help_outline, color: theme.textSecondaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: provider.closePanel,
                child: Icon(Icons.close, color: theme.textSecondaryColor, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPendingHelp(BuildContext context, ThemeProvider theme) {
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
                child: Text('待处理交易功能使用指南', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Text(
                    '📖 什么是待处理交易？\n'
                    '待处理交易是「记一笔」的核心特色功能，它可以自动检测微信、支付宝、云闪付的支付通知，自动解析交易信息，将未确认的交易保存到待处理列表。你可以在空闲时统一处理这些交易，确认后一键完成记账，既不会错过任何一笔交易，又能保持账单的准确性！\n\n'
                    '🚀 开启待处理交易功能\n\n'
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
                    '⚠️ 这个权限是为了让APP在后台也能处理交易通知，否则锁屏或后台时无法正常工作\n\n'
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
                    '3. 解析完成后，交易会自动保存到「待处理交易」列表中\n'
                    '4. 你可以点击主页右上角的角标，查看并处理待处理交易\n'
                    '5. 确认无误后，点击「记账」即可完成记账\n'
                    '6. 整个过程都是在你的手机本地完成的，不会上传任何数据到服务器！\n\n'
                    '🔒 隐私保护：\n'
                    '• 所有通知解析都是在你的手机本地完成，不会上传任何数据到任何服务器\n'
                    '• 我们只会读取微信/支付宝/云闪付的支付通知，其他所有通知都会被直接忽略\n'
                    '• 我们不会读取你的短信、聊天记录或任何其他私人数据\n'
                    '• 所有代码开源，你可以随时查看源码审计我们的逻辑\n\n'
                    '❓ 常见问题与排查\n\n'
                    'Q1：为什么支付后待处理列表没有新交易？\n'
                    'A：请检查以下几点：\n'
                    '• 检查「通知使用权」是否已经开启\n'
                    '• 检查微信/支付宝的通知权限是否开启\n'
                    '• 检查是否开启了后台保活权限，APP是否被系统杀死了\n\n'
                    'Q2：为什么有时候待处理交易会失效？\n'
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
                    '• 可以联系我们，把通知的内容发给我们，我们会更新解析规则\n\n'
                    'Q6：如何处理待处理列表中的交易？\n'
                    'A：在待处理交易面板中，你可以：\n'
                    '• 点击交易查看详情\n'
                    '• 点击「记账」按钮，交易会自动添加到账本中\n'
                    '• 点击「删除」按钮，可以删除不需要的交易\n'
                    '• 点击「全部记账」，可以一键将所有交易记账\n'
                    '• 点击「全部删除」，可以一键清空待处理列表',
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

  Widget _buildReminderBanner(PendingTransactionProvider provider, ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.warningColor.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: theme.warningColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '有 ${provider.overdueCount} 笔交易超过 ${provider.reminderHours} 小时未处理',
              style: TextStyle(fontSize: 12, color: theme.warningColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: theme.textSecondaryColor.withAlpha(100)),
          const SizedBox(height: 12),
          Text('暂无待处理交易', style: TextStyle(fontSize: 14, color: theme.textSecondaryColor)),
          const SizedBox(height: 4),
          Text('支付后会自动出现在这里', style: TextStyle(fontSize: 12, color: theme.textSecondaryColor.withAlpha(150))),
        ],
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context, PendingTransactionProvider provider, ThemeProvider theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: provider.pendingItems.length,
      itemBuilder: (context, index) {
        final item = provider.pendingItems[index];
        return _buildTransactionCard(context, item, provider, theme);
      },
    );
  }

  Widget _buildTransactionCard(BuildContext context, PendingTransaction item, PendingTransactionProvider provider, ThemeProvider theme) {
    final icon = _sourceIcons[item.packageName] ?? '💳';
    final isExpense = item.type == 'expense';
    final timeStr = _formatRelativeTime(item.createdAt);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PendingTransactionEditScreen(transaction: item),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.inputBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.merchant ?? item.sourceName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 11, color: theme.textSecondaryColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '-' : '+'}${formatCurrency(item.amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isExpense ? theme.expenseColor : theme.incomeColor,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: item.status == 'pending'
                        ? theme.warningColor.withAlpha(30)
                        : item.status == 'confirmed'
                            ? theme.successColor.withAlpha(30)
                            : theme.textSecondaryColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.status == 'pending' ? '待处理' : item.status == 'confirmed' ? '已确认' : '已忽略',
                    style: TextStyle(
                      fontSize: 10,
                      color: item.status == 'pending'
                          ? theme.warningColor
                          : item.status == 'confirmed'
                              ? theme.successColor
                              : theme.textSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }
}
