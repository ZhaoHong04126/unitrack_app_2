// 應用程式入口
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'services/settings_service.dart';
import 'widgets/responsive_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Firebase 配置（依據平台自動載入對應 options）
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 初始化系統設定與偏好配置（主題模式、主題色調、偏好資訊）
  await SettingsService().initialize();

  runApp(const CampusAssistantApp());
}

class CampusAssistantApp extends StatelessWidget {
  final Widget? home;
  const CampusAssistantApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeSettings>(
      valueListenable: SettingsService().themeNotifier,
      builder: (context, themeSettings, _) {
        return MaterialApp(
          title: '校園生活助手 UniTrack Pro',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AdaptiveScrollBehavior(),
          themeMode: themeSettings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: themeSettings.seedColor,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: themeSettings.seedColor,
            brightness: Brightness.dark,
          ),
          home: home ?? const AuthGate(),
        );
      },
    );
  }
}
