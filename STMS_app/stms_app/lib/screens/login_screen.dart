import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _selectedSegment = 0; // 0: 登入, 1: 註冊
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("發生錯誤"),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text("確定"),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog("請輸入電子郵件和密碼");
      return;
    }

    if (_selectedSegment == 1) {
      if (username.isEmpty) {
        _showErrorDialog("請輸入使用者名稱");
        return;
      }
      if (password != confirmPassword) {
        _showErrorDialog("兩次密碼輸入不一致");
        return;
      }
      if (password.length < 6) {
        _showErrorDialog("密碼長度至少需要 6 個字元");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedSegment == 0) {
        // --- 登入邏輯 ---
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        // [修正] 登入成功後，如果這個頁面是被 push 上來的（殭屍頁面），就把它關掉
        if (mounted && Navigator.canPop(context)) {
           Navigator.pop(context);
        }
      } else {
        // --- 註冊邏輯 ---
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          await userCredential.user!.updateDisplayName(username);
          await userCredential.user!.reload();
        }
        // [修正] 註冊成功後同理
        if (mounted && Navigator.canPop(context)) {
           Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "發生未知錯誤";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        errorMessage = "帳號或密碼錯誤 (或帳號不存在)";
      } else if (e.code == 'wrong-password') {
        errorMessage = "密碼錯誤";
      } else if (e.code == 'email-already-in-use') {
        errorMessage = "此電子郵件已被註冊過";
      } else if (e.code == 'invalid-email') {
        errorMessage = "電子郵件格式不正確";
      } else if (e.code == 'weak-password') {
        errorMessage = "密碼太弱";
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscureText,
      keyboardType: keyboardType,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isRegisterMode = _selectedSegment == 1;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isRegisterMode ? '註冊帳號' : '登入系統'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: CupertinoSegmentedControl<int>(
                  children: const {
                    0: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text("登入")),
                    1: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text("註冊")),
                  },
                  onValueChanged: (int val) {
                    setState(() {
                      _selectedSegment = val;
                      _usernameController.clear();
                      _emailController.clear();
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    });
                  },
                  groupValue: _selectedSegment,
                ),
              ),

              const SizedBox(height: 32),

              if (isRegisterMode) ...[
                _buildTextField(
                  controller: _usernameController,
                  placeholder: '使用者名稱 (暱稱)',
                ),
                const SizedBox(height: 16),
              ],

              _buildTextField(
                controller: _emailController,
                placeholder: '電子郵件',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _passwordController,
                placeholder: '密碼',
                obscureText: true,
              ),

              if (isRegisterMode) ...[
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _confirmPasswordController,
                  placeholder: '再次確認密碼',
                  obscureText: true,
                ),
              ],

              const SizedBox(height: 32),

              if (_isLoading)
                const CupertinoActivityIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _handleAuth,
                    child: Text(isRegisterMode ? '註冊並登入' : '登入'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}