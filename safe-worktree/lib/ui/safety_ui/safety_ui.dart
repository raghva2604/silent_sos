import 'package:flutter/material.dart';
import '../../screens/safety_home_screen.dart';

/// Safety UI is the default emergency interface.
///
/// This wrapper is intended to be the root widget when AppUIMode.safety is active.
class SafetyUI extends StatelessWidget {
  const SafetyUI({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafetyHomeScreen();
  }
}
