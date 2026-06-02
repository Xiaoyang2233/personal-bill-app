import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/pending_transaction_service.dart';

class ParsedNotification {
  final String packageName;
  final String sourceName;
  final String title;
  final String text;
  final double amount;
  final String type; // 'expense' or 'income'
  final String? merchant;
  final String? suggestedCategory;
  final DateTime timestamp;

  ParsedNotification({
    required this.packageName,
    required this.sourceName,
    required this.title,
    required this.text,
    required this.amount,
    required this.type,
    this.merchant,
    this.suggestedCategory,
    required this.timestamp,
  });
}

class AutoBookkeepingProvider extends ChangeNotifier {
  static const _eventChannel = EventChannel('com.finance.app/notification_events');
  static const _methodChannel = MethodChannel('com.finance.app/notification_check');

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  bool _isListening = false;
  bool get isListening => _isListening;

  // Queue system: up to 5 pending notifications
  final List<ParsedNotification> _pendingQueue = [];
  static const int _maxQueueSize = 5;
  List<ParsedNotification> get pendingQueue => List.unmodifiable(_pendingQueue);
  ParsedNotification? get pendingNotification => _pendingQueue.isNotEmpty ? _pendingQueue.first : null;
  int get pendingCount => _pendingQueue.length;

  // Deduplication: track recent notifications within 60 seconds
  final Map<String, DateTime> _recentNotifications = {};
  static const _deduplicationWindow = Duration(seconds: 60);

  StreamSubscription? _subscription;

  static const _packageNames = {
    'com.tencent.mm': '微信支付',
    'com.eg.android.AlipayGphone': '支付宝',
    'com.unionpay': '云闪付',
  };

  static const defaultCategoryRules = {
    '美团': '餐饮', '饿了么': '餐饮', '肯德基': '餐饮', '麦当劳': '餐饮', '瑞幸': '餐饮',
    '星巴克': '餐饮', '喜茶': '餐饮', '奈雪': '餐饮', '必胜客': '餐饮', '海底捞': '餐饮',
    '淘宝': '购物', '京东': '购物', '拼多多': '购物', '天猫': '购物', '苏宁': '购物',
    '唯品会': '购物', '得物': '购物', '抖音商城': '购物',
    '滴滴': '交通', '高德': '交通', '地铁': '交通', '公交': '交通', '铁路': '交通',
    '12306': '交通', '携程': '交通', '飞猪': '交通', '哈啰': '交通',
    '腾讯视频': '娱乐', '爱奇艺': '娱乐', '网易': '娱乐', 'B站': '娱乐', 'bilibili': '娱乐',
    '优酷': '娱乐', '芒果': '娱乐', 'Steam': '娱乐',
    '中国移动': '生活费', '中国联通': '生活费', '中国电信': '生活费',
    '电费': '生活费', '水费': '生活费', '燃气': '生活费', '物业': '生活费',
  };

  AutoBookkeepingProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('auto_bookkeeping_enabled') ?? false;

    if (_isEnabled) {
      final hasPermission = await this.hasPermission();
      if (hasPermission) {
        _startListening();
      } else {
        _isEnabled = false;
        await prefs.setBool('auto_bookkeeping_enabled', false);
      }
    }
    notifyListeners();
  }

  Future<bool> hasPermission() async {
    try {
      final result = await _methodChannel.invokeMethod('isNotificationListenerEnabled');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  void toggle(bool enabled) {
    if (enabled) {
      _isEnabled = true;
      _saveEnabled(true);
      _startListening();
    } else {
      _isEnabled = false;
      _saveEnabled(false);
      _stopListening();
    }
    notifyListeners();
  }

  void _startListening() {
    print('[AutoBookkeeping] Starting notification listener');
    _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        print('[AutoBookkeeping] Event received: $event');
        if (event is Map) {
          _processNotification(event);
        }
      },
      onError: (error) {
        print('[AutoBookkeeping] EventChannel error: $error');
      },
    );
    _isListening = true;
    print('[AutoBookkeeping] Listener started, isListening=$_isListening');
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _pendingQueue.clear();
  }

  void _processNotification(Map<dynamic, dynamic> data) async {
    final packageName = data['packageName'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    final timestamp = data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

    print('=== 收到支付通知 ===');
    print('应用包名：$packageName');
    print('通知标题：$title');
    print('通知内容：$text');

    if (!_packageNames.containsKey(packageName)) {
      print('[跳过] 非目标应用');
      return;
    }

    // Check if this is a payment-related notification by title keywords
    if (!_isPaymentNotification(packageName, title)) {
      print('[跳过] 非支付通知');
      return;
    }

    final sourceName = _packageNames[packageName]!;

    final amount = _extractAmount('$title $text');
    if (amount == null || amount <= 0) {
      print('[跳过] 未提取到金额');
      return;
    }

    final type = _detectType(title, text);
    final merchant = _extractMerchant(title, text, packageName);
    final category = _suggestCategory('$title $text', merchant);

    // Deduplication check
    final dedupKey = '$packageName:${amount.toStringAsFixed(2)}:${timestamp ~/ 10000}';
    final now = DateTime.now();
    if (_recentNotifications.containsKey(dedupKey)) {
      final lastTime = _recentNotifications[dedupKey]!;
      if (now.difference(lastTime) < _deduplicationWindow) {
        print('[跳过] 重复通知（60秒内）');
        return;
      }
    }
    _recentNotifications[dedupKey] = now;

    // Clean old entries
    _recentNotifications.removeWhere((key, time) => now.difference(time) > _deduplicationWindow);

    print('提取到的金额：$amount');
    print('交易类型：${type == "income" ? "收入" : "支出"}');
    print('商户名称：${merchant ?? "默认"}');
    print('建议分类：$category');
    print('========================');

    final parsed = ParsedNotification(
      packageName: packageName,
      sourceName: sourceName,
      title: title,
      text: text,
      amount: amount,
      type: type,
      merchant: merchant,
      suggestedCategory: category,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );

    // Add to queue (with max size limit)
    if (_pendingQueue.length >= _maxQueueSize) {
      _pendingQueue.removeAt(0); // Remove oldest
    }
    _pendingQueue.add(parsed);

    // Persist to database
    try {
      final pendingService = PendingTransactionService();
      await pendingService.insert(parsed);
    } catch (e) {
      print('[AutoBookkeeping] Failed to persist: $e');
    }

    notifyListeners();
  }

  bool _isPaymentNotification(String packageName, String title) {
    if (packageName == 'com.tencent.mm') {
      return title.contains('微信支付') ||
          title.contains('[转账]') ||
          title.contains('微信红包') ||
          title.contains('收款到账') ||
          title.contains('支付成功');
    }
    if (packageName == 'com.eg.android.AlipayGphone') {
      return title.contains('支付宝') ||
          title.contains('支付成功') ||
          title.contains('收款成功') ||
          title.contains('转账到账');
    }
    if (packageName == 'com.unionpay') {
      return title.contains('支付') ||
          title.contains('消费') ||
          title.contains('收款') ||
          title.contains('转账');
    }
    return false;
  }

  double? _extractAmount(String text) {
    final patterns = [
      RegExp(r'[¥￥]\s*(\d+\.?\d*)'),
      RegExp(r'(\d+\.?\d*)\s*元'),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1) ?? '');
      }
    }
    return null;
  }

  String _detectType(String title, String text) {
    final incomeKeywords = ['收款', '转账已接收', '红包已领取', '红包', '到账', '收款到账'];
    for (final kw in incomeKeywords) {
      if (title.contains(kw)) return 'income';
    }
    final expenseKeywords = ['支付', '消费', '转账给', '付款'];
    for (final kw in expenseKeywords) {
      if (title.contains(kw)) return 'expense';
    }
    return 'expense';
  }

  String? _extractMerchant(String title, String text, String packageName) {
    final combined = '$title $text';
    final patterns = [
      RegExp(r'向(.+?)付款'),
      RegExp(r'收款方[：:]\s*(.+?)[，,\s。]'),
      RegExp(r'商户[：:]\s*(.+?)[，,\s。]'),
      RegExp(r'对方[：:]\s*(.+?)[，,\s。]'),
      RegExp(r'在(.+?)(?:消费|支出|支付|付款)'),
      RegExp(r'于(.+?)(?:消费|支出|支付|付款)'),
      RegExp(r'付款给(.+?)[，,\s。]'),
      RegExp(r'^\[转账\](.+)$'),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(combined);
      if (match != null && match.group(1) != null) {
        final merchant = match.group(1)!.trim();
        if (merchant.isNotEmpty && merchant.length < 20) {
          return merchant;
        }
      }
    }
    if (packageName == 'com.tencent.mm') return '微信交易';
    if (packageName == 'com.eg.android.AlipayGphone') return '支付宝交易';
    return null;
  }

  String _suggestCategory(String text, String? merchant) {
    if (merchant != null) {
      for (final entry in defaultCategoryRules.entries) {
        if (merchant.contains(entry.key)) return entry.value;
      }
    }
    for (final entry in defaultCategoryRules.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return '其他';
  }

  // Called by UI after user confirms/cancels the first notification
  void confirmCurrent() {
    if (_pendingQueue.isNotEmpty) {
      _pendingQueue.removeAt(0);
      notifyListeners();
    }
  }

  // Called by UI to cancel the first notification without saving
  void cancelCurrent() {
    if (_pendingQueue.isNotEmpty) {
      _pendingQueue.removeAt(0);
      notifyListeners();
    }
  }

  // Clear all pending notifications
  void clearAll() {
    _pendingQueue.clear();
    notifyListeners();
  }

  Future<void> _saveEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_bookkeeping_enabled', value);
  }

  void sendTestNotification({required String scenario}) {
    ParsedNotification notification;

    switch (scenario) {
      case 'wechat_pay':
        notification = ParsedNotification(
          packageName: 'com.tencent.mm',
          sourceName: '微信支付',
          title: '微信支付',
          text: '微信支付收款 ¥88.00（测试超市）',
          amount: 88.00,
          type: 'expense',
          merchant: '测试超市',
          suggestedCategory: '购物',
          timestamp: DateTime.now(),
        );
        break;
      case 'wechat_red_packet':
        notification = ParsedNotification(
          packageName: 'com.tencent.mm',
          sourceName: '微信支付',
          title: '微信红包',
          text: '你领取了一个红包，金额 ¥6.66',
          amount: 6.66,
          type: 'income',
          merchant: '微信红包',
          suggestedCategory: '其他',
          timestamp: DateTime.now(),
        );
        break;
      case 'alipay':
        notification = ParsedNotification(
          packageName: 'com.eg.android.AlipayGphone',
          sourceName: '支付宝',
          title: '支付宝',
          text: '你在支付宝付款 ¥25.50（测试便利店）',
          amount: 25.50,
          type: 'expense',
          merchant: '测试便利店',
          suggestedCategory: '购物',
          timestamp: DateTime.now(),
        );
        break;
      default:
        return;
    }

    // Add to in-memory queue
    if (_pendingQueue.length >= _maxQueueSize) {
      _pendingQueue.removeAt(0);
    }
    _pendingQueue.add(notification);

    // Persist to database
    try {
      PendingTransactionService().insert(notification);
    } catch (e) {
      print('[AutoBookkeeping] Failed to persist test: $e');
    }

    notifyListeners();
  }
}
