import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack_app_2/models/course.dart';
import 'package:unitrack_app_2/screens/timetable_screen.dart';

void main() {
  final sampleCourses = [
    const Course(
      id: 'c1',
      name: '演算法分析',
      classroom: '電301',
      professor: '林教授',
      weekday: 1, // 週一
      startSection: 1,
      endSection: 2,
      credits: 3,
      type: CourseType.required,
      color: Colors.indigo,
    ),
    const Course(
      id: 'c2',
      name: '作業系統',
      classroom: '工205',
      professor: '陳教授',
      weekday: 2, // 週二
      startSection: 3,
      endSection: 4,
      credits: 3,
      type: CourseType.elective,
      color: Colors.teal,
    ),
  ];

  testWidgets('手機窄螢幕下預設進入單日時間軸清單，並可切換星期 Tab', (WidgetTester tester) async {
    // 設置手機尺寸 400x800
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableScreen(
          initialCourses: sampleCourses,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 驗證頂部星期 Tab（包含週一至週日）及對應當週日期（月/日）
    expect(find.text('週一'), findsOneWidget);
    expect(find.text('週二'), findsOneWidget);
    expect(find.text('週三'), findsOneWidget);
    expect(find.text('週日'), findsOneWidget);

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: now.weekday - 1),
    );
    final mondayDateStr = '${monday.month}/${monday.day}';
    expect(find.text(mondayDateStr), findsOneWidget);

    // 點擊「週一」Tab
    await tester.tap(find.text('週一'));
    await tester.pumpAndSettle();

    // 驗證週一顯示「演算法分析」卡片
    expect(find.text('演算法分析'), findsOneWidget);
    expect(find.text('第 1-2 節'), findsOneWidget);
    expect(find.text('電301'), findsOneWidget);
    expect(find.text('林教授'), findsOneWidget);

    // 點擊「週二」Tab
    await tester.tap(find.text('週二'));
    await tester.pumpAndSettle();

    // 驗證切換為週二「作業系統」卡片
    expect(find.text('作業系統'), findsOneWidget);
    expect(find.text('第 3-4 節'), findsOneWidget);
    expect(find.text('工205'), findsOneWidget);

    // 點擊「週三」Tab（無排課）
    await tester.tap(find.text('週三'));
    await tester.pumpAndSettle();

    // 驗證顯示無課空狀態提示
    expect(find.text('星期三 無排定課程'), findsOneWidget);
    expect(find.text('新增 星期三 課程'), findsOneWidget);
  });

  testWidgets('手機與電腦模式下均不再顯示佔位修課統計卡片', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableScreen(
          initialCourses: sampleCourses,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 驗證手機版不再顯示修課統計或統計詳情卡片
    expect(find.text('學期修課統計'), findsNothing);
    expect(find.text('統計詳情'), findsNothing);
  });

  testWidgets('手機模式下右下角顯示 FloatingActionButton 新增按鈕且點擊開啟對話框', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableScreen(
          initialCourses: sampleCourses,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 驗證右下角顯示 FloatingActionButton
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    expect(find.descendant(of: fab, matching: find.text('新增課程')), findsOneWidget);
    expect(find.descendant(of: fab, matching: find.byIcon(Icons.add_rounded)), findsOneWidget);

    // 點擊 FAB 開啟新增課程對話框
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // 驗證新增對話框開啟
    expect(find.textContaining('課程名稱'), findsOneWidget);

    // 點擊取消關閉對話框
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('手機模式下可於 AppBar 切換單日清單與整週網格檢視', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableScreen(
          initialCourses: sampleCourses,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 初始為單日清單模式，尋找「切換為整週網格模式」按鈕
    final toggleModeBtn = find.byTooltip('切換為整週網格模式');
    expect(toggleModeBtn, findsOneWidget);

    // 點擊切換為整週網格模式
    await tester.tap(toggleModeBtn);
    await tester.pumpAndSettle();

    // 驗證按鈕 tooltip 變為「切換為單日清單模式」
    expect(find.byTooltip('切換為單日清單模式'), findsOneWidget);

    // 驗證整週網格的一覽提示出現
    expect(find.textContaining('手機整週檢視'), findsOneWidget);

    // 再次點擊切換回單日模式
    await tester.tap(find.byTooltip('切換為單日清單模式'));
    await tester.pumpAndSettle();

    // 驗證回到了單日模式（顯示週一至週日 Tab 列）
    expect(find.text('週一'), findsOneWidget);
    expect(find.byTooltip('切換為整週網格模式'), findsOneWidget);
  });

  testWidgets('桌面寬螢幕模式下維持整週網格檢視', (WidgetTester tester) async {
    // 設置桌面尺寸 1280x800
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableScreen(
          initialCourses: sampleCourses,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 桌面寬螢幕模式下顯示「節次 / 時間」表格標題
    expect(find.text('節次 / 時間'), findsOneWidget);
    // 桌面模式顯示新增課程按鈕
    expect(find.text('新增課程'), findsOneWidget);
    // 桌面模式不顯示手機專屬的切換單日模式 tooltip
    expect(find.byTooltip('切換為整週網格模式'), findsNothing);
    // 驗證雙位數節次標籤（第 10 節 ~ 第 14 節）完整渲染且無文字換行溢出
    expect(find.text('第 10 節'), findsOneWidget);
    expect(find.text('第 14 節'), findsOneWidget);
  });

  testWidgets('手機直立寬度下進入整週檢視模式，一覽完整週一至週五且無水平滾動軸', (WidgetTester tester) async {
    // 設置標準手機直立螢幕尺寸 390x844
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableScreen(
          initialCourses: sampleCourses,
          coursesStream: Stream.value(sampleCourses),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 點擊切換為整週網格模式
    await tester.tap(find.byTooltip('切換為整週網格模式'));
    await tester.pumpAndSettle();

    // 驗證手機整週模式下不包含任何橫向滾動容器
    final horizontalScrollViews = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScrollViews, findsNothing);

    // 驗證表頭同時可見週一、週二、週三、週四、週五
    expect(find.text('週一'), findsOneWidget);
    expect(find.text('週二'), findsOneWidget);
    expect(find.text('週三'), findsOneWidget);
    expect(find.text('週四'), findsOneWidget);
    expect(find.text('週五'), findsOneWidget);

    // 驗證週一的演算法分析與週二的作業系統卡片均能正常顯示
    expect(find.text('演算法分析'), findsOneWidget);
    expect(find.text('作業系統'), findsOneWidget);

    // 驗證左側節次欄精簡為「節次」標題與純數字「1」、「2」等
    expect(find.text('節次'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
  });
}
