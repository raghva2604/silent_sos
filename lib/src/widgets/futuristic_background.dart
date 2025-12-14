import 'dart:math' as math;
import 'package:flutter/material.dart';

class FuturisticBackground extends StatefulWidget {
  final Color base1;
  final Color base2;
  const FuturisticBackground({super.key, this.base1 = const Color(0xFF0B1220), this.base2 = const Color(0xFF0F1724)});

  @override
  State<FuturisticBackground> createState() => _FuturisticBackgroundState();
}

class _FuturisticBackgroundState extends State<FuturisticBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, child) {
        final t = _ctl.value;
        // moving centers for radial gradients
        final cx = 0.5 + 0.3 * math.cos(2 * math.pi * t);
        final cy = 0.5 + 0.25 * math.sin(2 * math.pi * t * 1.3);

        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(cx * 2 - 1, cy * 2 - 1),
                    radius: 1.1,
                    colors: [widget.base1.withValues(alpha: 0.9), widget.base2.withValues(alpha: 0.95)],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            // soft moving glow layers
            Positioned.fill(
              child: CustomPaint(
                painter: _OrbPainter(t),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double t;
  _OrbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.screen;
    // RNG removed - deterministic visuals are derived from phase/time.
    for (int i = 0; i < 6; i++) {
      final phase = (i / 6) + t * (0.2 + i * 0.05);
      final x = size.width * (0.2 + 0.6 * ((math.cos(phase * 2 * math.pi) + 1) / 2));
      final y = size.height * (0.2 + 0.6 * ((math.sin(phase * 2 * math.pi) + 1) / 2));
      final radius = 80.0 + 60.0 * math.sin(phase * 2 * math.pi + i);
      final c = Color.lerp(const Color(0xFF00FFC2), const Color(0xFF3B82F6), (i / 6))!.withValues(alpha: 0.06 + 0.02 * i);
      paint.color = c;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => old.t != t;
}
