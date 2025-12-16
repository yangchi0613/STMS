import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    //
    final isDarkMode = themeManager.value == ThemeMode.dark;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('設定'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection(
              header: const Text('帳戶'),
              children: [
                CupertinoListTile(
                  title: const Text('編輯個人資料'),
                  leading: const Icon(CupertinoIcons.person),
                  trailing: const Icon(CupertinoIcons.right_chevron),
                  onTap: () {},
                ),
                CupertinoListTile(
                  title: const Text('更改密碼'),
                  leading: const Icon(CupertinoIcons.lock),
                  trailing: const Icon(CupertinoIcons.right_chevron),
                  onTap: () {},
                ),
              ],
            ),
            CupertinoListSection(
              header: const Text('外觀'),
              children: [
                CupertinoListTile(
                  title: const Text('深色模式'),
                  leading: const Icon(CupertinoIcons.moon_stars),
                  trailing: CupertinoSwitch(
                    value: isDarkMode,
                    onChanged: (bool value) {
                      setState(() {
                        themeManager.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
            CupertinoListSection(
              header: const Text('關於'),
              children: [
                CupertinoListTile(
                  title: const Text('版本'),
                  leading: const Icon(CupertinoIcons.info),
                  additionalInfo: const Text('1.0.0'),
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
