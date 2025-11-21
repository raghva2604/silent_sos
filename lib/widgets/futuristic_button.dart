import 'package:flutter/material.dart';

enum FuturisticButtonStyle { primary, secondary, danger }

class FuturisticButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final FuturisticButtonStyle style;
  final double height;
  final EdgeInsets padding;

  const FuturisticButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.style = FuturisticButtonStyle.primary,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  State<FuturisticButton> createState() => _FuturisticButtonState();
}

class _FuturisticButtonState extends State<FuturisticButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _primaryColor() {
    switch (widget.style) {
      case FuturisticButtonStyle.danger:
        return Colors.deepOrangeAccent;
      case FuturisticButtonStyle.secondary:
        return Colors.cyanAccent;
      case FuturisticButtonStyle.primary:
        return Colors.blueAccent;
    }
  // No fallback needed — switch is exhaustive for the enum
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primaryColor();
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final glow = (_anim.value * 0.6) + 0.4;
        return Opacity(
          opacity: widget.onPressed == null ? 0.6 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: widget.height,
                padding: widget.padding,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary.withAlpha((0.9 * 255).round()), primary.withAlpha((0.6 * 255).round())],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withAlpha(((0.25 * glow) * 255).clamp(0, 255).round()),
                      blurRadius: 18 * glow,
                      spreadRadius: 1 * glow,
                      offset: Offset(0, 6 * glow),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(((0.18 * glow) * 255).clamp(0, 255).round()),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), child: widget.child)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FuturisticIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const FuturisticIconButton({super.key, required this.icon, required this.onPressed, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: Colors.blueAccent.withAlpha((0.25 * 255).round()), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
