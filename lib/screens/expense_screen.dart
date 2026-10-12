// 記帳本畫面

import 'package:flutter/material.dart';
import '../widgets/responsive_layout.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: ResponsiveLayout.buildDrawerLeading(context),
        title: const Text('記帳本'),
      ),
      body: const Center(child: Text('記帳本畫面（製作中）')),
    );
  }
}