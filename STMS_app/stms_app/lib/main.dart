import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';


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
    return const CupertinoApp(
      title: 'STMS',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('zh', 'TW'), Locale('en', 'US')],
      locale: Locale('zh', 'TW'),
      home: LoginScreen(),
    );
  }
}