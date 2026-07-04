import 'package:flutter/material.dart';

import '../src/screens/home_screen.dart';

class SafetyHomeScreen extends StatelessWidget {
  const SafetyHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // simply delegate to the existing home screen
    return const HomeScreen();
  }
}
