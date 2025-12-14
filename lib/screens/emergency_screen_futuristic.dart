import 'package:flutter/material.dart';
import 'emergency_screen_fixed.dart';

/// Lightweight wrapper that forwards to the restored implementation.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmergencyScreenFixed();
  }
}

