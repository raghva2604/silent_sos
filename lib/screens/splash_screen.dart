import 'package:flutter/material.dart';
import 'dart:async';
import 'permission_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _glowAnim = Tween<double>(begin: 0.0, end: 36.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 1.0, curve: Curves.easeInOut)));

    _ctrl.forward();

    // After the animation finishes, navigate to PermissionScreen.
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Timer(const Duration(milliseconds: 600), () {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PermissionScreen()));
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final accent = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [const Color(0xFF05050A), primary.withAlpha(30), accent.withAlpha(20)],
                center: Alignment(-0.3, -0.5),
                radius: 1.2,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: _scaleAnim.value,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withAlpha(160),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withAlpha(180),
                            blurRadius: _glowAnim.value,
                            spreadRadius: _glowAnim.value / 6,
                          ),
                          BoxShadow(
                            color: accent.withAlpha(120),
                            blurRadius: _glowAnim.value / 2,
                            spreadRadius: _glowAnim.value / 12,
                          ),
                        ],
                      ),
                      child: Icon(Icons.security, size: 110, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Opacity(
                    opacity: _ctrl.value.clamp(0.0, 1.0),
                    child: Column(
                      children: [
                        Text('SilentSOS', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white.withAlpha((0.98 * 255).round()), letterSpacing: 2)),
                        const SizedBox(height: 8),
                        Text('Your silent guardian', style: TextStyle(fontSize: 14, color: Colors.white70.withAlpha(200))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}