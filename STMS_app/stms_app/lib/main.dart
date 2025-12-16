import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme_manager.dart';

void main() {
  initializeDateFormatting('zh_TW', null).then((_) {
    Intl.defaultLocale = 'zh_TW';
    runApp(const STMSApp());
  });
}

class STMSApp extends StatelessWidget {
  const STMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeManager,
      builder: (context, currentTheme, child) {
        return CupertinoApp(
          title: 'STMS',
          debugShowCheckedModeBanner: false,
          theme: CupertinoThemeData(
            brightness: currentTheme == ThemeMode.dark ? Brightness.dark : Brightness.light,
            primaryColor: CupertinoColors.activeBlue,
            scaffoldBackgroundColor: currentTheme == ThemeMode.dark ? CupertinoColors.black : CupertinoColors.systemGroupedBackground,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
          locale: const Locale('zh', 'TW'),
          home: const LoginScreen(),
        );
      },
    );
  }
}