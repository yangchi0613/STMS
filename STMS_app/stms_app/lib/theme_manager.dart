import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ValueNotifier<ThemeMode> {
  ThemeManager() : super(ThemeMode.light); // Start with a default

  static const _kThemeModeKey = 'theme_mode';

  Future<void> init() async {
    value = await _getSavedThemeMode();
  }

  Future<ThemeMode> _getSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_kThemeModeKey);
    if (themeIndex != null) {
      return ThemeMode.values[themeIndex];
    }
    // If no saved theme, use system theme
    try {
      return SchedulerBinding.instance.window.platformBrightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (e) {
      return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeModeKey, mode.index);
  }
}

// Global singleton instance
final themeManager = ThemeManager();
