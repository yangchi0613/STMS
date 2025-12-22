import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 引入 Auth

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 取得目前登入的使用者
    final User? user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName ?? "未命名使用者";
    final String email = user?.email ?? "無電子郵件";

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('個人資訊'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: CupertinoColors.activeBlue,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
                  style: const TextStyle(fontSize: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: const TextStyle(
                    fontSize: 16, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 32),
              
              // 登出按鈕
              CupertinoButton(
                color: CupertinoColors.destructiveRed.withOpacity(0.1),
                child: const Text(
                  '登出',
                  style: TextStyle(color: CupertinoColors.destructiveRed),
                ),
                onPressed: () async {
                  // 1. 執行登出
                  await FirebaseAuth.instance.signOut();
                  
                  // 2. 因為 main.dart 有監聽，登出後會自動跳回 Login 畫面，
                  // 所以這裡只要把目前的 Profile 頁面關掉就好
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}