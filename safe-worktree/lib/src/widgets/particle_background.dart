// lib/src/widgets/particle_background.dart
import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final Color color;
  final int count;
  final double opacity;
  const ParticleBackground({
    super.key,
    this.color = Colors.cyanAccent,
    this.count = 20,
    this.opacity = 0.06,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctl;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticlePainter(
              progress: _ctl.value,
              rng: _rng,
              color: widget.color,
              count: widget.count,
              opacity: widget.opacity,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Random rng;
  final Color color;
  final double opacity;
  final int count;
  _ParticlePainter({
    required this.progress,
    required this.rng,
    required this.color,
    required this.count,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withAlpha((opacity * 255).round());
    for (int i = 0; i < count; i++) {
      final baseX = (rng.nextDouble() * size.width);
      final baseY = (rng.nextDouble() * size.height);
      // subtle movement controlled by progress
      final dx = (baseX + sin(progress * 2 * pi + i) * 28) % size.width;
      final dy = (baseY + cos(progress * 2 * pi + i) * 18) % size.height;
      final r = 3 +
          (rng.nextDouble() * 10) * (0.6 + 0.4 * sin(progress * 2 * pi + i));
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.progress != progress;
}
