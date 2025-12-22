import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stms_app/main.dart';

void main() {
  testWidgets('App start smoke test', (WidgetTester tester) async {
    // [修正] 改用 STMSApp()
    await tester.pumpWidget(const STMSApp());

    // 這裡我們只簡單檢查能不能啟動，不檢查計數器了，因為介面已經完全變了
    // 只要上面那一行不報錯，代表 APP 啟動正常
  });
}