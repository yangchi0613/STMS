import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('個人資訊'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(CupertinoIcons.person, size: 50),
              ),
              const SizedBox(height: 16),
              const Text(
                '使用者名稱',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'user@example.com',
                style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 32),
              CupertinoButton(
                child: const Text('登出'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pushReplacement(
                    CupertinoPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
