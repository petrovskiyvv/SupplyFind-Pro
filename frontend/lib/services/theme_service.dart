import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String themeKey = "theme_mode";
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  ThemeService() {
    _loadTheme();
  }

  void toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeKey, _themeMode.toString());
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeStr = prefs.getString(themeKey);
    if (themeStr != null) {
      _themeMode = themeStr == ThemeMode.dark.toString() ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }
}
