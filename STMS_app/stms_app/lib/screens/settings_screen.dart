import 'package:flutter/cupertino.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  title: const Text('主題'),
                  leading: const Icon(CupertinoIcons.paintbrush),
                  trailing: const Icon(CupertinoIcons.right_chevron),
                  onTap: () {},
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
