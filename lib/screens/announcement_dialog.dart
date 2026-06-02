import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/announcement_manager.dart';

class AnnouncementDialog extends StatelessWidget {
  final AnnouncementData announcement;

  const AnnouncementDialog({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              announcement.title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textColor),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'v${announcement.version}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.primaryColor),
              ),
            ),
            const SizedBox(height: 20),
            ...announcement.content.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  style: TextStyle(fontSize: 15, height: 1.6, color: theme.textColor),
                ),
              ),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await AnnouncementManager().markAsRead();
                  if (context.mounted) Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('我已了解', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
