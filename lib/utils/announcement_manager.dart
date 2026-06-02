import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementData {
  final String version;
  final String title;
  final List<String> content;
  const AnnouncementData({required this.version, required this.title, required this.content});
}

class AnnouncementManager {
  static const currentVersion = '1.3.0';

  static const Map<String, AnnouncementData> _announcements = {
    '1.3.0': AnnouncementData(
      version: '1.3.0',
      title: '新版本发布 🎉',
      content: [
        '✨ 新增待处理交易面板，通知栏记账更方便',
        '🔔 新增交易提醒功能，不再遗漏任何一笔',
        '🧪 新增功能测试，轻松验证通知权限',
        '🐛 修复已知问题，提升稳定性',
      ],
    ),
  };

  Future<bool> shouldShowAnnouncement() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRead = prefs.getString('last_read_announcement_version') ?? '';
    return _announcements.containsKey(currentVersion) && lastRead != currentVersion;
  }

  Future<void> markAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_read_announcement_version', currentVersion);
  }

  AnnouncementData? getCurrentAnnouncement() {
    return _announcements[currentVersion];
  }
}
