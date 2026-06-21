// 基础冒烟测试：确认应用能正常构建并显示底部两个页签。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reminder/main.dart';

void main() {
  testWidgets('App builds and shows bottom navigation', (tester) async {
    await tester.pumpWidget(const ReminderApp());
    await tester.pump();

    // 底部导航的两个页签文字。
    expect(find.text('我的一天'), findsWidgets);
    expect(find.text('待办'), findsWidgets);
    // 中间的新建按钮（加号图标）。
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
