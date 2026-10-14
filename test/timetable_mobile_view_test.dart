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

    // 驗證頂部星期 Tab（包含週一至週日）
    expect(find.text('週一'), findsOneWidget);
    expect(find.text('週二'), findsOneWidget);
    expect(find.text('週三'), findsOneWidget);
    expect(find.text('週日'), findsOneWidget);

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

  testWidgets('手機模式下可切換展開/折疊修課統計卡片', (WidgetTester tester) async {
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

    // 初始狀態為折疊：顯示「總計 2 門 · 6 學分」與「統計詳情」
    expect(find.text('總計 2 門 · 6 學分'), findsOneWidget);
    expect(find.text('統計詳情'), findsOneWidget);
    expect(find.text('學期修課統計'), findsNothing);

    // 點擊展開統計
    await tester.tap(find.text('統計詳情'));
    await tester.pumpAndSettle();

    // 展開後顯示「學期修課統計」與「收合」按鈕
    expect(find.text('學期修課統計'), findsOneWidget);
    expect(find.text('收合'), findsOneWidget);
    expect(find.text('必/選/通：'), findsOneWidget);

    // 點擊收合
    await tester.tap(find.text('收合'));
    await tester.pumpAndSettle();

    expect(find.text('統計詳情'), findsOneWidget);
    expect(find.text('學期修課統計'), findsNothing);
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

    // 驗證整週網格的左右滑動提示出現
    expect(find.textContaining('手機整週檢視：可左右滑動瀏覽課表'), findsOneWidget);

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
    // 桌面模式顯示完整的週一至週五 FilterChip
    expect(find.text('週一至週五'), findsOneWidget);
    // 桌面模式不顯示手機專屬的切換單日模式 tooltip
    expect(find.byTooltip('切換為整週網格模式'), findsNothing);
  });
}
