// 登入與註冊頁面表單驗證與切換元件測試
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack_app_2/main.dart';
import 'package:unitrack_app_2/screens/auth/login_screen.dart';

void main() {
  testWidgets('登入頁面欄位檢查與空欄位驗證提示', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CampusAssistantApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 驗證標題與輸入框元件存在
    expect(find.text('UniTrack Pro'), findsOneWidget);
    expect(find.text('電子信箱'), findsOneWidget);
    expect(find.text('登入密碼'), findsOneWidget);
    expect(find.text('登入'), findsOneWidget);
    expect(find.text('立即註冊'), findsOneWidget);

    // 點擊登入按鈕（未輸入內容）
    await tester.tap(find.text('登入'));
    await tester.pumpAndSettle();

    // 應出現驗證錯誤訊息
    expect(find.text('請輸入電子信箱'), findsOneWidget);
    expect(find.text('請輸入密碼'), findsOneWidget);
  });

  testWidgets('點擊立即註冊導向註冊頁面且驗證密碼一致性', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CampusAssistantApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 點擊切換至註冊頁面
    await tester.tap(find.text('立即註冊'));
    await tester.pumpAndSettle();

    // 驗證已導向註冊頁面
    expect(find.text('建立新帳號'), findsOneWidget);
    expect(find.text('設定密碼'), findsOneWidget);
    expect(find.text('確認密碼'), findsOneWidget);

    // 輸入不符格式之密碼進行驗證
    final passwordField = find.widgetWithText(TextFormField, '設定密碼');
    final confirmPasswordField = find.widgetWithText(TextFormField, '確認密碼');

    await tester.enterText(passwordField, '123456');
    await tester.enterText(confirmPasswordField, '654321');

    final registerBtn = find.text('建立帳號');
    await tester.ensureVisible(registerBtn);
    await tester.pumpAndSettle();

    await tester.tap(registerBtn);
    await tester.pumpAndSettle();

    expect(find.text('兩次輸入的密碼不一致'), findsOneWidget);
  });
}
