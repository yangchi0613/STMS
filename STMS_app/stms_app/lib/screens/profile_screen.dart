import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user;

  @override
  void initState() {
    super.initState();
    _refreshUser();
  }

  Future<void> _refreshUser() async {
    user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    user = FirebaseAuth.instance.currentUser;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String displayName = currentUser?.displayName ?? "未命名使用者";
    final String email = currentUser?.email ?? "無電子郵件";

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
              
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _refreshUser,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.refresh),
                    SizedBox(width: 5),
                    Text("重新整理資料"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CupertinoButton(
                color: CupertinoColors.destructiveRed,
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: const Text('登出'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}