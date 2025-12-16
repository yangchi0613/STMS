import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ThemeManager extends ValueNotifier<ThemeMode> {
  ThemeManager() : super(_getInitialThemeMode());

  static ThemeMode _getInitialThemeMode() {
    try {
      return SchedulerBinding.instance.window.platformBrightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
    } catch (e) {
      return ThemeMode.light;
    }
  }

  void setThemeMode(ThemeMode mode) {
    value = mode;
  }
}

// Global singleton instance
final themeManager = ThemeManager();
