import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CenterButton extends StatelessWidget {
  final VoidCallback onTap;

  const CenterButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54, height: 54,
        margin: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          color: theme.primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withAlpha(80),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text('+', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w300)),
      ),
    );
  }
}
