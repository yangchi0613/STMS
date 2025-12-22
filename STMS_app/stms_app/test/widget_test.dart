import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stms_app/main.dart';

void main() {
  testWidgets('App start smoke test', (WidgetTester tester) async {
    // 確保這裡是 STMSApp()
    await tester.pumpWidget(const STMSApp());
  });
}