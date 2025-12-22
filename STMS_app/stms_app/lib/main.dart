import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart'; // [新增] 驗證套件
import 'screens/login_screen.dart';
import 'screens/home_screen.dart'; // [新增] 需要引用首頁
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
          // [關鍵修改] 這裡不再寫死 LoginScreen，而是用 StreamBuilder 監聽登入狀態
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // 1. 如果正在檢查中，顯示轉圈圈
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CupertinoPageScaffold(
                  child: Center(child: CupertinoActivityIndicator()),
                );
              }
              // 2. 如果 snapshot 有資料 (User 不是 null)，代表已登入 -> 進首頁
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              // 3. 否則 -> 進登入頁
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}