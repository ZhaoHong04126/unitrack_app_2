// 應用程式入口
import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'widgets/responsive_layout.dart';

void main() {
  runApp(const CampusAssistantApp());
}

class CampusAssistantApp extends StatelessWidget {
  const CampusAssistantApp({super.key});

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
      home: const MainScreen(),
    );
  }
}
