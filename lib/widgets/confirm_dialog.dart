import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'glass_container.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool destructive;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = '确认',
    this.cancelText = '取消',
    required this.onConfirm,
    required this.onCancel,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: context.watch<ThemeProvider>().textColor)),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 14, color: context.watch<ThemeProvider>().textSecondaryColor, height: 1.4)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildButton(
                    context: context,
                    label: cancelText,
                    onTap: onCancel,
                    bgColor: context.watch<ThemeProvider>().inputBgColor,
                    textColor: context.watch<ThemeProvider>().textColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildButton(
                    context: context,
                    label: confirmText,
                    onTap: onConfirm,
                    bgColor: destructive ? context.watch<ThemeProvider>().dangerColor : context.watch<ThemeProvider>().primaryColor,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '确认',
    String cancelText = '取消',
    VoidCallback? onConfirm,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        destructive: destructive,
        onConfirm: () {
          onConfirm?.call();
          Navigator.pop(ctx, true);
        },
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    required Color bgColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
      ),
    );
  }
}
