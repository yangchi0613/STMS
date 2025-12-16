import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _selectedSegment = 0; // 0 for Login, 1 for Register
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // 封裝一個通用的 CupertinoTextField 樣式
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
    // 判斷是否為註冊模式
    final bool isRegisterMode = _selectedSegment == 1;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isRegisterMode ? '註冊' : '登入'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 登入/註冊 切換按鈕 (此處已固定，無需修改)
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      onPressed: () {
                        setState(() {
                          _selectedSegment = 0;
                        });
                      },
                      color: _selectedSegment == 0
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.systemGrey6,
                      child: Text(
                        '登入',
                        style: TextStyle(
                          color: _selectedSegment == 0
                              ? CupertinoColors.white
                              : CupertinoColors.activeBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoButton(
                      onPressed: () {
                        setState(() {
                          _selectedSegment = 1;
                        });
                      },
                      color: _selectedSegment == 1
                          ? CupertinoColors.activeBlue
                          : CupertinoColors.systemGrey6,
                      child: Text(
                        '註冊',
                        style: TextStyle(
                          color: _selectedSegment == 1
                              ? CupertinoColors.white
                              : CupertinoColors.activeBlue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // 使用者名稱 (登入/註冊皆有)
              _buildTextField(
                controller: _usernameController,
                placeholder: '使用者名稱',
              ),

              const SizedBox(height: 16),

              // 電子郵件 (僅註冊有，使用 Visibility 保持空間)
              Visibility(
                visible: isRegisterMode,
                maintainSize: true, // 保持佔用空間
                maintainAnimation: true,
                maintainState: true,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _emailController,
                      placeholder: '電子郵件',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16), // Email 下方的間距
                  ],
                ),
              ),

              // 密碼 (登入/註冊皆有)
              _buildTextField(
                controller: _passwordController,
                placeholder: '密碼',
                obscureText: true,
              ),

              const SizedBox(height: 16),

              // 確認密碼 (僅註冊有，使用 Visibility 保持空間)
              Visibility(
                visible: isRegisterMode,
                maintainSize: true, // 保持佔用空間
                maintainAnimation: true,
                maintainState: true,
                child: _buildTextField(
                  controller: _confirmPasswordController,
                  placeholder: '確認密碼',
                  obscureText: true,
                ),
              ),

              const SizedBox(height: 32),

              // 主要動作按鈕
              CupertinoButton.filled(
                child: Text(isRegisterMode ? '註冊' : '登入'),
                onPressed: () {
                  if (_selectedSegment == 0) {
                    // TODO: Implement login logic
                    _performAction(
                      '登入',
                      _usernameController.text,
                      _passwordController.text,
                    );
                  } else {
                    // TODO: Implement registration logic
                    _performAction(
                      '註冊',
                      _usernameController.text,
                      _passwordController.text,
                      _emailController.text,
                      _confirmPasswordController.text,
                    );
                  }

                  // 導航到 HomeScreen
                  Navigator.of(context).pushReplacement(
                    CupertinoPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 簡易的動作執行函式（可替換為實際的登入/註冊邏輯）
  void _performAction(
    String action,
    String username,
    String password, [
    String? email,
    String? confirmPassword,
  ]) {
    print('$action 資訊:');
    print('使用者名稱: $username');
    print('密碼: $password');
    if (action == '註冊') {
      print('電子郵件: $email');
      print('確認密碼: $confirmPassword');
      if (password != confirmPassword) {
        print('錯誤: 密碼與確認密碼不一致！');
        // 實際應用中應該在這裡顯示錯誤訊息給使用者
      }
    }
  }
}
