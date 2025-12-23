import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme_manager.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? get user => FirebaseAuth.instance.currentUser;

  // 編輯對話框
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

  // 修改顯示名稱
  Future<void> _updateDisplayName(String newName) async {
    try {
      await user?.updateDisplayName(newName);
      await user?.reload(); // 強制重新整理使用者資料
      setState(() {}); 
      _showSuccessDialog("暱稱已更新");
    } catch (e) {
      _showErrorDialog("更新失敗：$e");
    }
  }

  // 修改 Email
  Future<void> _updateEmail(String newEmail) async {
    try {
      // 需要重新驗證
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

  // 修改密碼
  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOldPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return CupertinoAlertDialog(
              title: const Text('更改密碼'),
              content: Column(
                children: [
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: oldPasswordController,
                    placeholder: '舊密碼',
                    obscureText: obscureOldPassword,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.lock_shield),
                    ),
                    suffix: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(obscureOldPassword
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye),
                      onPressed: () {
                        setState(() {
                          obscureOldPassword = !obscureOldPassword;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: newPasswordController,
                    placeholder: '新密碼 (至少6碼)',
                    obscureText: obscureNewPassword,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.lock),
                    ),
                    suffix: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(obscureNewPassword
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye),
                      onPressed: () {
                        setState(() {
                          obscureNewPassword = !obscureNewPassword;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: confirmPasswordController,
                    placeholder: '確認新密碼',
                    obscureText: obscureConfirmPassword,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.lock),
                    ),
                    suffix: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(obscureConfirmPassword
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye),
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('取消'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('更改'),
                  onPressed: () async {
                    // 隱藏鍵盤
                    FocusScope.of(context).unfocus();

                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      _showErrorDialog('新密碼不符');
                      return;
                    }
                    if (newPasswordController.text.length < 6) {
                      _showErrorDialog('密碼長度至少需要 6 位');
                      return;
                    }

                    final user = FirebaseAuth.instance.currentUser;
                    if(user == null || user.email == null) {
                      _showErrorDialog('無法取得使用者資訊');
                      return;
                    }

                    final cred = EmailAuthProvider.credential(
                        email: user.email!,
                        password: oldPasswordController.text);

                    try {
                      await user.reauthenticateWithCredential(cred);
                      await user.updatePassword(newPasswordController.text);
                      Navigator.of(dialogContext).pop(); // 關閉對話框
                      _showSuccessDialog('密碼更改成功！');
                    } on FirebaseAuthException catch (e) {
                      String errorMessage = '發生未知錯誤';
                      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                        errorMessage = '舊密碼錯誤';
                      } else if (e.code == 'weak-password') {
                        errorMessage = '新密碼太弱';
                      }
                      _showErrorDialog(errorMessage);
                    } catch (e) {
                      _showErrorDialog('操作失敗，請稍後再試');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 輔助對話框
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
    // 取得最新使用者資料
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
                // 編輯暱稱
                CupertinoListTile(
                  title: const Text('暱稱'),
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
                // 編輯 Email
                CupertinoListTile(
                  title: const Text('電子郵件'),
                  additionalInfo: SizedBox(
                    width: 150,
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
                // 修改密碼
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