// 身分驗證狀態流閘門（AuthGate）
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../main_screen.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

/// 根據 Firebase Auth 的登入狀態串流，自動分流 MainScreen 或 LoginScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // 連線中載入畫面
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '載入驗證狀態中...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 若已登入且具有使用者實例，導向主介面 MainScreen
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          final displayName = user.displayName?.trim() ?? '';
          final email = user.email ?? '';
          final fallbackName = email.isNotEmpty ? email.split('@').first : '同學';

          return MainScreen(
            userName: displayName.isNotEmpty ? displayName : fallbackName,
            userDepartment: email,
          );
        }

        // 未登入，導向登入頁面
        return const LoginScreen();
      },
    );
  }
}
