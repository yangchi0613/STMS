import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // 為了使用 Colors
import 'package:firebase_auth/firebase_auth.dart'; // [核心]
import '../theme_manager.dart';
import 'login_screen.dart'; // 為了在需要時導向重新登入

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? get user => FirebaseAuth.instance.currentUser;

  // --- 通用：顯示輸入框彈窗 (用於改名、改Email) ---
  void _showEditDialog({
    required String title,
    required String initialValue,
    required String placeholder,
    required Function(String) onConfirm,
  }) {
    final TextEditingController controller =
        TextEditingController(text: initialValue);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            clearButtonMode: OverlayVisibilityMode.editing,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text("儲存"),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onConfirm(controller.text);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  // --- 功能 A: 修改顯示名稱 ---
  Future<void> _updateDisplayName(String newName) async {
    try {
      await user?.updateDisplayName(newName);
      await user?.reload(); // 強制重新整理使用者資料
      setState(() {}); // 更新畫面
      _showSuccessDialog("暱稱已更新");
    } catch (e) {
      _showErrorDialog("更新失敗：$e");
    }
  }

  // --- 功能 B: 修改 Email ---
  Future<void> _updateEmail(String newEmail) async {
    try {
      // 注意：這通常需要重新驗證 (re-authenticate)
      await user?.verifyBeforeUpdateEmail(newEmail); // 發送驗證信到新信箱
      _showSuccessDialog("驗證信已寄出！\n請至新信箱 $newEmail 收信驗證後，變更才會生效。");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showReLoginDialog();
      } else {
        _showErrorDialog("更新失敗：${e.message}");
      }
    } catch (e) {
      _showErrorDialog("發生錯誤：$e");
    }
  }

  // --- 功能 C: 修改密碼 ---
  void _showChangePasswordDialog() {
    final TextEditingController passController = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("更改密碼"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: passController,
            placeholder: "輸入新密碼 (至少6碼)",
            obscureText: true,
            clearButtonMode: OverlayVisibilityMode.editing,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("確認更改"),
            onPressed: () {
              if (passController.text.length >= 6) {
                Navigator.pop(context);
                _updatePassword(passController.text);
              } else {
                // 簡單提示
                passController.clear();
                passController.text = "密碼太短";
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updatePassword(String newPassword) async {
    try {
      await user?.updatePassword(newPassword);
      _showSuccessDialog("密碼修改成功！下次登入請使用新密碼。");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showReLoginDialog();
      } else if (e.code == 'weak-password') {
        _showErrorDialog("密碼強度不足");
      } else {
        _showErrorDialog("修改失敗：${e.message}");
      }
    } catch (e) {
      _showErrorDialog("發生錯誤：$e");
    }
  }

  // --- 輔助顯示彈窗 ---
  void _showErrorDialog(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("錯誤"),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text("確定"),
            onPressed: () => Navigator.pop(c),
          )
        ],
      ),
    );
  }

  void _showSuccessDialog(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("成功"),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text("好"),
            onPressed: () => Navigator.pop(c),
          )
        ],
      ),
    );
  }

  void _showReLoginDialog() {
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("需要重新登入"),
        content: const Text("為了安全起見，修改此資料需要您重新登入。"),
        actions: [
          CupertinoDialogAction(
            child: const Text("稍後"),
            onPressed: () => Navigator.pop(c),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("現在登出"),
            onPressed: () async {
              Navigator.pop(c);
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                 Navigator.of(context, rootNavigator: true).pushReplacement(
                    CupertinoPageRoute(builder: (context) => const LoginScreen()),
                  );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeManager.value == ThemeMode.dark;
    // 確保拿到最新的 user 資料
    final currentUser = FirebaseAuth.instance.currentUser;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('設定'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection(
              header: const Text('帳戶資訊'),
              children: [
                // 1. 編輯暱稱
                CupertinoListTile(
                  title: const Text('暱稱'),
                  // 顯示目前名字，如果沒有就是 "未命名"
                  additionalInfo: Text(currentUser?.displayName ?? "未命名"),
                  leading: const Icon(CupertinoIcons.person),
                  trailing: const Icon(CupertinoIcons.pencil, size: 20),
                  onTap: () {
                    _showEditDialog(
                      title: "修改暱稱",
                      initialValue: currentUser?.displayName ?? "",
                      placeholder: "輸入新暱稱",
                      onConfirm: (val) => _updateDisplayName(val),
                    );
                  },
                ),
                // 2. 編輯 Email
                CupertinoListTile(
                  title: const Text('電子郵件'),
                  additionalInfo: SizedBox(
                    width: 150, // 限制寬度避免超出
                    child: Text(
                      currentUser?.email ?? "",
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  leading: const Icon(CupertinoIcons.mail),
                  trailing: const Icon(CupertinoIcons.pencil, size: 20),
                  onTap: () {
                    _showEditDialog(
                      title: "修改電子郵件",
                      initialValue: currentUser?.email ?? "",
                      placeholder: "輸入新 Email",
                      onConfirm: (val) => _updateEmail(val),
                    );
                  },
                ),
                // 3. 修改密碼
                CupertinoListTile(
                  title: const Text('更改密碼'),
                  leading: const Icon(CupertinoIcons.lock),
                  trailing: const Icon(CupertinoIcons.right_chevron),
                  onTap: () {
                    _showChangePasswordDialog();
                  },
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