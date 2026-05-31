import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/bill_provider.dart';
import 'providers/ledger_provider.dart';
import 'providers/budget_provider.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/data_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/quick_entry_sheet.dart';
import 'widgets/center_button.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: '记账',
            debugShowCheckedModeBanner: false,
            themeMode: theme.mode,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(seedColor: theme.primaryColor),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(
                seedColor: theme.primaryColor,
                brightness: Brightness.dark,
              ),
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            home: AppShell(),
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

  final _screens = const [
    HomeScreen(),
    HistoryScreen(),
    SizedBox(), // placeholder for center button
    DataScreen(),
    SettingsScreen(),
  ];

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
          // Background layer
          Positioned.fill(
            child: _buildBackground(theme),
          ),
          // Content layer
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
    return Stack(
      children: [
        // Base color
        Container(
          color: theme.backgroundType == 'color'
              ? Color(int.parse(theme.backgroundColor.replaceAll('#', '0xFF')))
              : const Color(0xFFF5F7FA),
        ),
        // Background image
        if (theme.backgroundType == 'image' && theme.backgroundImage.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: theme.backgroundOpacity,
              child: Image.file(
                File(theme.backgroundImage),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar(ThemeProvider theme) {
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
          padding: const EdgeInsets.only(top: 6, bottom: 8),
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
    final theme = context.watch<ThemeProvider>();

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
              Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? theme.primaryColor : theme.textSecondaryColor,
            )),
          ],
        ),
      ),
    );
  }
}
