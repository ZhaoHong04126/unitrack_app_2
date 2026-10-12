// 行事曆畫面
import 'package:flutter/material.dart';
import '../widgets/responsive_layout.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: ResponsiveLayout.buildDrawerLeading(context),
        title: const Text('校園行事曆'),
      ),
      body: const Center(child: Text('行事曆畫面（製作中）')),
    );
  }
}