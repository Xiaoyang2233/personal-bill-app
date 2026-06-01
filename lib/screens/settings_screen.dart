import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/glass_container.dart';
import 'ledger_manage_screen.dart';
import 'budget_manage_screen.dart';
import 'category_manage_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const presetColors = [
    '#F5F7FA', '#FFF8E1', '#E8F5E9', '#E3F2FD',
    '#FCE4EC', '#F3E5F5', '#EFEBE9', '#ECEFF1',
    '#1C1C1E', '#263238', '#1B5E20', '#0D47A1',
  ];

  @override
  Widget build(BuildContext context) {
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
                  Text('1.1.0', style: TextStyle(fontSize: 14, color: theme.textColor)),
                ],
              ),
            ],
          ),
        ),

      ],
    );
  }

  Widget _buildThemeBtn(String label, ThemeMode mode, ThemeProvider theme) {
    final active = theme.mode == mode;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => theme.setThemeMode(mode),
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.primaryColor.withAlpha(60),
          highlightColor: theme.primaryColor.withAlpha(40),
          child: Ink(
            decoration: BoxDecoration(
              color: active ? theme.primaryColor : theme.inputBgColor,
              borderRadius: BorderRadius.circular(16),
              border: active ? Border.all(color: theme.primaryColor, width: 2) : null,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: active ? Colors.white : theme.textColor,
              )),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool active, VoidCallback onTap, ThemeProvider theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: theme.primaryColor.withAlpha(50),
        highlightColor: theme.primaryColor.withAlpha(30),
        child: Ink(
          decoration: BoxDecoration(
            color: active ? theme.primaryColor : theme.inputBgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : theme.textColor,
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(String label, VoidCallback onTap, ThemeProvider theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: theme.primaryColor.withAlpha(30),
        highlightColor: theme.primaryColor.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 15, color: theme.textColor)),
              Text('→', style: TextStyle(fontSize: 16, color: theme.textSecondaryColor)),
            ],
          ),
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
        splashColor: theme.primaryColor.withAlpha(30),
        highlightColor: theme.primaryColor.withAlpha(20),
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
              theme.clearBackground();
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
        title: const Text('恢复默认背景'),
        content: const Text('确定要清除自定义背景，恢复为默认背景吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              theme.clearBackground();
              Navigator.pop(ctx);
            },
            child: const Text('恢复'),
          ),
        ],
      ),
    );
  }
}
