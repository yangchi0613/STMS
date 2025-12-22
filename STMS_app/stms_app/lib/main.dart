import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart'; // [新增]

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // [新增] 初始化通知服務
  await NotificationService.init();

  // Load the theme
  await themeManager.init();

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
            brightness: currentTheme == ThemeMode.dark
                ? Brightness.dark
                : Brightness.light,
            primaryColor: CupertinoColors.activeBlue,
            scaffoldBackgroundColor: currentTheme == ThemeMode.dark
                ? CupertinoColors.black
                : CupertinoColors.systemGroupedBackground,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
          locale: const Locale('zh', 'TW'),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CupertinoPageScaffold(
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}