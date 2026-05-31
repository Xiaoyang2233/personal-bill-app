import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  String _backgroundType = 'color';
  String get backgroundType => _backgroundType;

  String _backgroundColor = '#F5F7FA';
  String get backgroundColor => _backgroundColor;

  String _backgroundImage = '';
  String get backgroundImage => _backgroundImage;

  double _backgroundOpacity = 0.5;
  double get backgroundOpacity => _backgroundOpacity;

  bool get isDark {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }

  Color get primaryColor => const Color(0xFF4A90D9);
  Color get expenseColor => const Color(0xFFE74C3C);
  Color get incomeColor => const Color(0xFF2ECC71);
  Color get successColor => const Color(0xFF27AE60);
  Color get dangerColor => const Color(0xFFE74C3C);
  Color get warningColor => const Color(0xFFF39C12);

  Color get cardColor => isDark
      ? const Color.fromRGBO(0, 0, 0, 0.85)
      : const Color.fromRGBO(255, 255, 255, 0.85);

  Color get inputBgColor => isDark
      ? const Color.fromRGBO(30, 30, 30, 0.7)
      : const Color.fromRGBO(255, 255, 255, 0.7);

  Color get tabBarColor => isDark
      ? const Color.fromRGBO(20, 20, 22, 0.85)
      : const Color.fromRGBO(255, 255, 255, 0.85);

  Color get borderColor => isDark
      ? const Color.fromRGBO(56, 56, 58, 0.5)
      : const Color.fromRGBO(229, 229, 234, 0.7);

  Color get textColor => isDark ? Colors.white : Colors.black;
  Color get textSecondaryColor => isDark ? const Color(0xFFBBBBBB) : const Color(0xFF555555);

  Color get overlayColor => Colors.black.withAlpha((0.4 * 255).round());

  ThemeProvider() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  Future<void> _ensurePrefs() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      _loadSettings();
    }
  }

  void _loadSettings() {
    if (_prefs == null) return;

    final modeStr = _prefs!.getString('theme_mode') ?? 'system';
    _mode = _parseThemeMode(modeStr);

    _backgroundType = _prefs!.getString('background_type') ?? 'color';
    _backgroundColor = _prefs!.getString('background_color') ?? '#F5F7FA';
    _backgroundImage = _prefs!.getString('background_image') ?? '';
    _backgroundOpacity = _prefs!.getDouble('background_opacity') ?? 0.5;

    notifyListeners();
  }

  ThemeMode _parseThemeMode(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _mode = mode;
    await _ensurePrefs();
    final str = mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system';
    await _prefs?.setString('theme_mode', str);
    notifyListeners();
  }

  Future<void> setBackgroundImage(String path) async {
    _backgroundImage = path;
    _backgroundType = 'image';
    await _ensurePrefs();
    await _prefs?.setString('background_image', path);
    await _prefs?.setString('background_type', 'image');
    notifyListeners();
  }

  Future<void> pickBackgroundImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (result != null) {
      final dir = await getApplicationDocumentsDirectory();
      final destPath = p.join(dir.path, 'background.jpg');
      await File(result.path).copy(destPath);
      await setBackgroundImage(destPath);
    }
  }

  Future<void> setBackgroundColor(String color) async {
    _backgroundColor = color;
    _backgroundType = 'color';
    await _ensurePrefs();
    await _prefs?.setString('background_color', color);
    await _prefs?.setString('background_type', 'color');
    notifyListeners();
  }

  Future<void> setBackgroundOpacity(double opacity) async {
    _backgroundOpacity = opacity;
    await _ensurePrefs();
    await _prefs?.setDouble('background_opacity', opacity);
    notifyListeners();
  }

  Future<void> clearBackground() async {
    _backgroundType = 'color';
    _backgroundColor = '#F5F7FA';
    _backgroundImage = '';
    _backgroundOpacity = 0.5;
    await _ensurePrefs();
    await _prefs?.setString('background_type', 'color');
    await _prefs?.setString('background_color', '#F5F7FA');
    await _prefs?.setString('background_image', '');
    await _prefs?.setDouble('background_opacity', 0.5);
    notifyListeners();
  }
}
