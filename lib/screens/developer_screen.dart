import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_background.dart';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

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
                    onTap: () {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      Navigator.pop(context);
                    },
                    child: Text('← 返回', style: TextStyle(fontSize: 16, color: theme.primaryColor)),
                  ),
                  Text('开发者', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textColor)),
                  const SizedBox(width: 60),
                ],
              ),
            ),

            // Developer Card
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Avatar
                  ClipOval(
                    child: Image.asset(
                      'qq_avatar.jpg',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stack) => Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.inputBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person, size: 40, color: theme.textSecondaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xiaoyang', style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600, color: theme.textColor)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(const ClipboardData(text: '3606898583'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('QQ号已复制到剪贴板'),
                                duration: Duration(seconds: 2)),
                            );
                          },
                          child: Text('QQ: 3606898583', style: TextStyle(
                            fontSize: 14, color: theme.primaryColor)),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(const ClipboardData(
                              text: 'https://github.com/Xiaoyang2233/personal-bill-app'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('GitHub地址已复制到剪贴板'),
                                duration: Duration(seconds: 2)),
                            );
                          },
                          child: Text(
                            'GitHub: https://github.com/Xiaoyang2233/personal-bill-app',
                            style: TextStyle(fontSize: 14, color: theme.primaryColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
