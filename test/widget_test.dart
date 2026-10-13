import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack_app_2/main.dart';

void main() {
  testWidgets('點擊通知按鈕在桌面視窗寬度下於右上角彈出通知卡片', (WidgetTester tester) async {
    // 設置桌面寬度 1280x800
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CampusAssistantApp());
    await tester.pumpAndSettle();

    // 找到系統通知按鈕
    final notificationBtn = find.byTooltip('系統通知');
    expect(notificationBtn, findsOneWidget);

    // 點擊系統通知按鈕
    await tester.tap(notificationBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 驗證通知卡片內容
    expect(find.text('目前沒有新的系統通知'), findsOneWidget);
    expect(find.text('系統通知'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // 測試點擊關閉按鈕
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 驗證通知已被關閉移除
    expect(find.text('目前沒有新的系統通知'), findsNothing);
  });

  testWidgets('手機窄螢幕尺寸下點擊通知按鈕使用 SnackBar 顯示', (WidgetTester tester) async {
    // 設置手機尺寸 400x800
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CampusAssistantApp());
    await tester.pumpAndSettle();

    final notificationBtn = find.byTooltip('系統通知');
    expect(notificationBtn, findsOneWidget);

    await tester.tap(notificationBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 驗證底部出現 SnackBar
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('目前沒有新的系統通知'), findsOneWidget);
  });
}
