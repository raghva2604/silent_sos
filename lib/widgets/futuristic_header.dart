import 'package:flutter/material.dart';

class FuturisticHeader extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  const FuturisticHeader({super.key, required this.title});

  @override
  State<FuturisticHeader> createState() => _FuturisticHeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(88);
}

class _FuturisticHeaderState extends State<FuturisticHeader> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _anim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _anim.value;
        final color1 = Color.lerp(const Color(0xFF00FFD5), const Color(0xFF7C4DFF), t)!;
        final color2 = Color.lerp(const Color(0xFF0AB9FF), const Color(0xFFFF7CDA), (t + 0.5) % 1.0)!;
        return Container(
          height: widget.preferredSize.height,
          padding: const EdgeInsets.only(top: 28, left: 20, right: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color1.withAlpha((0.12 * 255).round()), color2.withAlpha((0.08 * 255).round())], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border(bottom: BorderSide(color: Colors.white.withAlpha((0.03 * 255).round()), width: 1.0)),
            // subtle glow
            boxShadow: [BoxShadow(color: color1.withAlpha((0.06 * 255).round()), blurRadius: 24.0, spreadRadius: 1.0, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Center(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2)))),
              // small animated orb
                Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [color2, color1]),
                  boxShadow: [BoxShadow(color: color2.withAlpha((0.5 * 255).round()), blurRadius: 12, spreadRadius: 1)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
