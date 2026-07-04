import 'package:flutter/material.dart';

class FuturisticOption extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double elevation;
  const FuturisticOption(
      {super.key, required this.child, this.onTap, this.elevation = 8});

  @override
  State<FuturisticOption> createState() => _FuturisticOptionState();
}

class _FuturisticOptionState extends State<FuturisticOption>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _scale = Tween<double>(begin: 0.96, end: 1.0)
        .animate(CurvedAnimation(parent: _ctl, curve: Curves.elasticOut));
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(60),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.06),
                  blurRadius: widget.elevation,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.08)),
              gradient: LinearGradient(colors: [
                Colors.white.withValues(alpha: 0.02),
                Colors.white.withValues(alpha: 0.01)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
