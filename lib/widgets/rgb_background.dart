import 'dart:math';
import 'package:flutter/material.dart';

/// Animated RGB gradient background with subtle motion and glow.
class RGBBackground extends StatefulWidget {
  final Widget? child;
  const RGBBackground({super.key, this.child});

  @override
  State<RGBBackground> createState() => _RGBBackgroundState();
}

class _RGBBackgroundState extends State<RGBBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  LinearGradient _makeGradient(double t) {
    // t in [0,1)
    final r = (sin(2 * pi * t) * 0.5 + 0.5);
    final g = (sin(2 * pi * (t + 0.33)) * 0.5 + 0.5);
    final b = (sin(2 * pi * (t + 0.66)) * 0.5 + 0.5);

    final c1 = Color.lerp(Colors.deepPurple, Colors.cyan, r) ?? Colors.cyan;
    final c2 = Color.lerp(Colors.indigo, Colors.pink, g) ?? Colors.pink;
    final c3 = Color.lerp(Colors.blueGrey, Colors.orange, b) ?? Colors.orange;

    return LinearGradient(
      begin: Alignment(-1 + 2 * r, -1 + 2 * g),
      end: Alignment(1 - 2 * b, 1 - 2 * r),
      colors: [c1.withAlpha((0.16 * 255).round()), c2.withAlpha((0.12 * 255).round()), c3.withAlpha((0.08 * 255).round())],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: _makeGradient(t),
            // subtle vignette
            boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.45 * 255).round()), blurRadius: 40, spreadRadius: 10, offset: const Offset(0, 8))],
          ),
          child: widget.child,
        );
      },
    );
  }
}
