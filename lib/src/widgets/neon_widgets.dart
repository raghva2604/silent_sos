// lib/src/widgets/neon_widgets.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// NeonButton: glowing rounded button used in permission and other places.
class NeonButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Gradient? gradient;
  final double radius;
  final EdgeInsets padding;
  const NeonButton({
    super.key,
    required this.child,
    required this.onTap,
    this.gradient,
    this.radius = 14,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gradient ??
        LinearGradient(colors: [Colors.cyanAccent, Colors.tealAccent]);
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, child) {
          final glow = 6 + _ctl.value * 18;
          return Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: g,
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withAlpha(((0.12 + _ctl.value * 0.12) * 255).round()),
                  blurRadius: glow,
                  spreadRadius: 2,
                )
              ],
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// AnimatedGlowingSOS: big circular SOS button with pulsing outer glow.
/// `onLongPressStart` should start the countdown; `onLongPressCancel` cancels.
class AnimatedGlowingSOS extends StatefulWidget {
  final String label;
  final bool showCounter;
  final void Function()? onLongPressStart;
  final void Function()? onLongPressCancel;

  const AnimatedGlowingSOS({
    super.key,
    required this.label,
    this.showCounter = false,
    this.onLongPressStart,
    this.onLongPressCancel,
  });

  @override
  State<AnimatedGlowingSOS> createState() => _AnimatedGlowingSOSState();
}

class _AnimatedGlowingSOSState extends State<AnimatedGlowingSOS>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPressStart,
      onLongPressUp: widget.onLongPressCancel,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          final outer = 220.0 + math.sin(t * 2 * math.pi) * 18;
          final glowAlpha = 0.16 + 0.12 * math.sin(t * 2 * math.pi);
          return Container(
            width: outer,
            height: outer,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // outer glow ring
                Container(
                  width: outer,
                  height: outer,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.red.withAlpha((glowAlpha * 255).round()), Colors.transparent],
                    ),
                  ),
                ),
                // main ring
                Container(
                  width: outer - 28,
                  height: outer - 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.red.shade700, Colors.redAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withAlpha((0.28 * 255).round()),
                        blurRadius: 34,
                        spreadRadius: 6,
                      )
                    ],
                  ),
                ),
                // inner core
                Container(
                  width: outer - 92,
                  height: outer - 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withAlpha((0.22 * 255).round()),
                    border: Border.all(color: Colors.white12, width: 2),
                  ),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: widget.showCounter ? 42 : 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Small neon icon used for AI button
class NeonIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NeonIcon({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Colors.cyanAccent, Colors.tealAccent]),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withAlpha((0.24 * 255).round()),
              blurRadius: 12,
              spreadRadius: 2,
            )
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 22),
      ),
    );
  }
}
