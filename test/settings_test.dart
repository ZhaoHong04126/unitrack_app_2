import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack_app_2/main.dart';
import 'package:unitrack_app_2/main_screen.dart';
import 'package:unitrack_app_2/screens/settings_screen.dart';
import 'package:unitrack_app_2/services/settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsService 單元測試', () {
    test('初始化並切換主題模式與色調種子持久化', () async {
      final service = SettingsService();
      await service.initialize();

      expect(service.themeNotifier.value.themeMode, ThemeMode.system);
      expect(service.semester, '113學年度 第 1 學期');

      // 切換為深色模式
      await service.setThemeMode(ThemeMode.dark);
      expect(service.themeNotifier.value.themeMode, ThemeMode.dark);

      // 切換主題色調為蔚藍海灣
      await service.setSeedColor(SettingsService.availableColors[1]);
      expect(service.themeNotifier.value.colorName, '蔚藍海灣');

      // 設定系所與學號
      await service.setDepartment('資訊工程學系');
      await service.setStudentId('B11234567');
      expect(service.department, '資訊工程學系');
      expect(service.studentId, 'B11234567');

      // 匯出 JSON 格式驗證
      final jsonStr = service.exportSettingsJson();
      expect(jsonStr.contains('資訊工程學系'), isTrue);
      expect(jsonStr.contains('B11234567'), isTrue);
      expect(jsonStr.contains('蔚藍海灣'), isTrue);

      // 重設為預設值
      await service.resetToDefaults();
      expect(service.themeNotifier.value.themeMode, ThemeMode.system);
      expect(service.department, '');
      expect(service.studentId, '');
    });
  });

  group('SettingsScreen 介面渲染測試', () {
    testWidgets('渲染系統設定畫面各項設定分區與控制項', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 驗證標題與各核心分區
      expect(find.text('系統設定'), findsOneWidget);
      expect(find.text('個人帳號與基本資料'), findsOneWidget);
      expect(find.text('介面外觀與主題模式'), findsOneWidget);
      expect(find.text('課表與學業偏好'), findsOneWidget);

      // 滾動檢查後續分區
      await tester.scrollUntilVisible(
        find.text('通知與提醒通知'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('通知與提醒通知'), findsOneWidget);

      // 驗證主題模式按鈕
      expect(find.text('跟隨系統'), findsOneWidget);
      expect(find.text('淺色模式'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);

      // 點擊切換為深色模式
      await tester.tap(find.text('深色模式'));
      await tester.pumpAndSettle();

      // 點擊匯出按鈕彈出 JSON 對話框
      final exportBtn = find.byTooltip('匯出設定 JSON');
      expect(exportBtn, findsOneWidget);
      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      expect(find.text('匯出個人與系統設定'), findsOneWidget);
      expect(find.text('關閉'), findsOneWidget);
      await tester.tap(find.text('關閉'));
      await tester.pumpAndSettle();
    });

    testWidgets('桌面端點擊側邊欄底部設定按鈕可順暢切換至系統設定', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const CampusAssistantApp(home: MainScreen()));
      await tester.pumpAndSettle();

      // 初始頁面為首頁總覽
      expect(find.text('首頁總覽'), findsWidgets);

      // 尋找底部使用者卡片中的「系統設定」按鈕
      final settingsIconBtn = find.byTooltip('系統設定');
      expect(settingsIconBtn, findsWidgets);

      // 點擊底部卡片的系統設定
      await tester.tap(settingsIconBtn.first);
      await tester.pumpAndSettle();

      // 驗證切換至系統設定畫面
      expect(find.text('個人帳號與基本資料'), findsOneWidget);
      expect(find.text('介面外觀與主題模式'), findsOneWidget);
    });
  });
}
