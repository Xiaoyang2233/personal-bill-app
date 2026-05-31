import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
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
        child,
      ],
    );
  }
}
