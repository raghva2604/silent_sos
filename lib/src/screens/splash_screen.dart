// lib/src/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
// provider not required in this UI-only file
import '../widgets/particle_background.dart';

class SplashScreen extends StatefulWidget {
  final Duration duration;
  final String title;
  const SplashScreen({super.key, this.duration = const Duration(milliseconds: 1700), this.title = 'Silent SOS'});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    Timer(widget.duration, () {
      // push to permissions route (your app's route)
      if (mounted) Navigator.of(context).pushReplacementNamed('/permissions');
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // background gradient with particle layer
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground(color: Colors.cyanAccent, count: 22, opacity: 0.05)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _ctl, curve: Curves.elasticOut),
                    child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha((0.35 * 255).round()),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                          BoxShadow(color: Colors.cyanAccent.withAlpha((0.08 * 255).round()), blurRadius: 24, spreadRadius: 2),
                      ],
                    ),
                    child: const Icon(Icons.security, size: 64, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 18),
                FadeTransition(
                  opacity: _ctl,
                  child: Column(
                    children: [
                      Text(widget.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Securing your every step', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
