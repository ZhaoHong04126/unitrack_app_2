import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unitrack_app_2/models/course.dart';
import 'package:unitrack_app_2/screens/dashboard_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // 建立測試課程
  final sampleCourses = [
    // 週五 第 1 節 (08:10 - 09:00)
    const Course(
      id: 'c1',
      name: '高等微積分',
      classroom: '理館 201',
      professor: '王教授',
      weekday: 5, // 週五
      startSection: 1,
      endSection: 1,
      credits: 3,
    ),
    // 週五 第 3-4 節 (10:10 - 12:00)
    const Course(
      id: 'c2',
      name: '演算法導論',
      classroom: '工館 402',
      professor: '李教授',
      weekday: 5, // 週五
      startSection: 3,
      endSection: 4,
      credits: 3,
    ),
    // 週一 第 2 節 (09:10 - 10:00)
    const Course(
      id: 'c3',
      name: '計算機網路',
      classroom: '電資 103',
      professor: '陳教授',
      weekday: 1, // 週一
      startSection: 2,
      endSection: 2,
      credits: 2,
    ),
  ];

  testWidgets('當前處於上課時間時，卡片顯示「上課中」及當前課程教室資訊', (WidgetTester tester) async {
    // 模擬週五 08:30 (落在高等微積分 08:10 - 09:00 期間)
    final fridayDuringClass = DateTime(2026, 10, 16, 8, 30); // 2026/10/16 is Friday

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          customNow: fridayDuringClass,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 驗證卡片即時狀態
    expect(find.textContaining('上課中'), findsOneWidget);
    expect(find.text('高等微積分'), findsOneWidget);
    expect(find.textContaining('理館 201'), findsOneWidget);
    expect(find.textContaining('王教授'), findsOneWidget);
    // 驗證學分計算 (3 + 3 + 2 = 8 學分)
    expect(find.text('8 / 128'), findsOneWidget);
  });

  testWidgets('當前處於課前時，卡片顯示「下一堂」及即將開始的課程資訊', (WidgetTester tester) async {
    // 模擬週五 07:30 (高等微積分 08:10 開始)
    final fridayBeforeClass = DateTime(2026, 10, 16, 7, 30);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          customNow: fridayBeforeClass,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('下一堂'), findsOneWidget);
    expect(find.text('高等微積分'), findsOneWidget);
  });

  testWidgets('今日所有課程皆已結束時，卡片顯示「今日課程已全部結束」', (WidgetTester tester) async {
    // 模擬週五 14:00 (週五最後一門在 12:00 結束)
    final fridayAfterClasses = DateTime(2026, 10, 16, 14, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          customNow: fridayAfterClasses,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日課程已全部結束 🎉'), findsOneWidget);
    expect(find.textContaining('今天辛苦了'), findsOneWidget);
  });

  testWidgets('今日沒有任何排定課程時，卡片顯示「今日尚無排定課程」', (WidgetTester tester) async {
    // 模擬週日 (2026/10/18 is Sunday)
    final sundayNoClass = DateTime(2026, 10, 18, 10, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          customNow: sundayNoClass,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日尚無排定課程'), findsOneWidget);
    expect(find.textContaining('今天沒有排定課程'), findsOneWidget);
  });

  testWidgets('頂部總覽卡片為純展示無跳轉，而下方功能捷徑卡片可觸發分頁導航', (WidgetTester tester) async {
    int? navigatedTab;
    final sundayNoClass = DateTime(2026, 10, 18, 10, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          customNow: sundayNoClass,
          coursesStream: Stream.value(sampleCourses),
          onNavigateToTab: (index) {
            navigatedTab = index;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 點擊頂部總覽卡片文字不會觸發導航 (純展示)
    await tester.tap(find.text('今日尚無排定課程'));
    await tester.pumpAndSettle();
    expect(navigatedTab, isNull);

    // 點擊總覽卡片內的指標亦不會觸發導航 (純展示)
    await tester.tap(find.text('畢業學分'));
    await tester.pumpAndSettle();
    expect(navigatedTab, isNull);

    // 點擊下方功能捷徑卡片「課表」跳轉課表 (Tab 1)
    await tester.tap(find.text('課表'));
    await tester.pumpAndSettle();
    expect(navigatedTab, 1);

    // 點擊下方功能捷徑卡片「記帳本」跳轉記帳本 (Tab 4)
    await tester.tap(find.text('記帳本'));
    await tester.pumpAndSettle();
    expect(navigatedTab, 4);

    // 點擊下方功能捷徑卡片「學分進度」跳轉畢業審查 (Tab 3)
    await tester.tap(find.text('學分進度'));
    await tester.pumpAndSettle();
    expect(navigatedTab, 3);
  });

  testWidgets('新增待辦事項、切換完成狀態與刪除待辦功能正常', (WidgetTester tester) async {
    final customTodos = [
      TodoItem(
        id: 't1',
        title: '作業一',
        subtitle: '備註一',
        category: '作業',
        icon: Icons.assignment_outlined,
        color: Colors.indigo,
        isCompleted: false,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          initialTodoItems: customTodos,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 初始有 1 項未完成待辦
    expect(find.text('1 項'), findsOneWidget);
    expect(find.text('作業一'), findsOneWidget);

    // 勾選完成狀態
    final checkbox = find.byType(Checkbox).first;
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    // 未完成數變為 0 項
    expect(find.text('0 項'), findsOneWidget);

    // 點擊「新增」按鈕打開新增待辦對話框
    final addBtn = find.widgetWithText(FilledButton, '新增');
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // 填入待辦名稱並儲存
    expect(find.text('新增待辦事項'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '複習期中考');
    await tester.tap(find.widgetWithText(FilledButton, '確認新增'));
    await tester.pumpAndSettle();

    // 驗證新增成功且計數變為 1 項
    expect(find.text('複習期中考'), findsOneWidget);
    expect(find.text('1 項'), findsOneWidget);

    // 刪除剛才新增的待辦
    final deleteButtons = find.byTooltip('刪除待辦事項');
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    // 驗證已被刪除
    expect(find.text('複習期中考'), findsNothing);

    // 排空 AppNotification 自動消失的延遲計時器 (3.5s)
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('學期副標題純資訊靜態呈現，不顯示編輯按鈕且不可彈出對話框', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardScreen(
          coursesStream: Stream.empty(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 驗證靜態顯示學期資訊
    expect(find.text('113學年度 第 1 學期'), findsOneWidget);
    // 不再顯示編輯鉛筆圖示
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
