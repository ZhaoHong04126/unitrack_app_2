// 應用程式入口
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'widgets/responsive_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Firebase 配置（依據平台自動載入對應 options）
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CampusAssistantApp());
}

class CampusAssistantApp extends StatelessWidget {
  final Widget? home;
  const CampusAssistantApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '校園生活助手 UniTrack Pro',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AdaptiveScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      home: home ?? const AuthGate(),
    );
  }
}
