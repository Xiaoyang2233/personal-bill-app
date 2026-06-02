import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/bill_provider.dart';
import 'providers/ledger_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/auto_bookkeeping_provider.dart';
import 'providers/pending_transaction_provider.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/data_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/quick_entry_sheet.dart';
import 'widgets/center_button.dart';
import 'widgets/auto_confirm_dialog.dart';
import 'utils/chart_color_utils.dart';
import 'utils/date_utils.dart';
import 'utils/announcement_manager.dart';
import 'screens/announcement_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ChartColorUtils.load();
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LedgerProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => AutoBookkeepingProvider()),
        ChangeNotifierProvider(create: (_) => PendingTransactionProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: '记一笔',
            debugShowCheckedModeBanner: false,
            themeMode: theme.mode,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(seedColor: theme.primaryColor),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(
                seedColor: theme.primaryColor,
                brightness: Brightness.dark,
              ),
            ),
            home: const AppShell(),
          );
        },
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    HistoryScreen(),
    SizedBox(),
    DataScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationListener();
      _setupAutoBookkeepingSync();
      _checkAnnouncement();
      context.read<PendingTransactionProvider>().loadPending();
    });
  }

  void _setupAutoBookkeepingSync() {
    final autoProvider = context.read<AutoBookkeepingProvider>();
    autoProvider.addListener(() {
      if (mounted) {
        context.read<PendingTransactionProvider>().loadPending();
      }
    });
  }

  void _checkAnnouncement() async {
    final manager = AnnouncementManager();
    if (await manager.shouldShowAnnouncement()) {
      final announcement = manager.getCurrentAnnouncement();
      if (announcement != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AnnouncementDialog(announcement: announcement),
        );
      }
    }
  }

  void _setupNotificationListener() {
    final provider = context.read<AutoBookkeepingProvider>();
    provider.addListener(() {
      if (provider.pendingNotification != null && mounted) {
        _showConfirmDialog(provider);
      }
    });
  }

  void _showConfirmDialog(AutoBookkeepingProvider provider) {
    final notification = provider.pendingNotification;
    if (notification == null) return;

    // Prevent showing multiple dialogs
    if (ModalRoute.of(context)?.isCurrent != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AutoConfirmDialog(
        notification: notification,
        currentIndex: provider.pendingCount > 0 ? 1 : 0,
        totalCount: provider.pendingCount,
        onConfirm: (category, note) async {
          final billProvider = context.read<BillProvider>();
          final ledgerProvider = context.read<LedgerProvider>();
          final ledger = await ledgerProvider.ensureLedger();
          await billProvider.addBill(
            ledgerId: ledger.id!,
            type: notification.type,
            amount: notification.amount,
            category: category,
            note: note.isNotEmpty ? note : (notification.merchant ?? ''),
            date: getToday(),
            source: notification.packageName,
          );
          provider.confirmCurrent();
        },
        onModify: () {
          provider.confirmCurrent();
          _showEntrySheet();
        },
        onCancel: () {
          provider.cancelCurrent();
        },
      ),
    );
  }

  void _showEntrySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickEntrySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildBackground(theme),
          ),
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget _buildBackground(ThemeProvider theme) {
    final isDark = theme.isDark;
    final defaultColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F7FA);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: defaultColor),
        if (theme.backgroundType == 'color')
          Container(
            color: Color(int.parse(theme.backgroundColor.replaceAll('#', '0xFF'))),
          ),
        if (theme.backgroundType == 'image' && theme.backgroundImage.isNotEmpty)
          Opacity(
            opacity: theme.backgroundOpacity,
            child: Image.file(
              File(theme.backgroundImage),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar(ThemeProvider theme) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.tabBarColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: theme.borderColor, width: 0.5)),
          ),
          padding: EdgeInsets.only(top: 6, bottom: 8 + bottomPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tabItem('📊', '首页', 0),
              _tabItem('📋', '历史', 1),
              const SizedBox(width: 54),
              _tabItem('💾', '数据', 3),
              _tabItem('⚙️', '设置', 4),
            ],
          ),
        ),
        Positioned(
          top: -20,
          child: CenterButton(onTap: _showEntrySheet),
        ),
      ],
    );
  }

  Widget _tabItem(String icon, String label, int index) {
    final selected = _currentIndex == index;
    final theme = context.read<ThemeProvider>();

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: selected ? 24 : 22)),
            if (selected)
              Container(
                width: 4, height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle),
              ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? theme.primaryColor : theme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
