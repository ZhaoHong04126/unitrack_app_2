// 畢業審查畫面

import 'package:flutter/material.dart';
import '../widgets/responsive_layout.dart';

class GraduationScreen extends StatelessWidget {
  const GraduationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: ResponsiveLayout.buildDrawerLeading(context),
        title: const Text('畢業審查'),
      ),
      body: const Center(child: Text('畢業審查畫面（製作中）')),
    );
  }
}