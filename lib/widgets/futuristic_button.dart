import 'package:flutter/material.dart';

enum FuturisticButtonStyle { primary, secondary, danger }

/// Minimal, syntactically-safe FuturisticButton to avoid analyzer errors.
class FuturisticButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final FuturisticButtonStyle style;
  final double height;

  const FuturisticButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.style = FuturisticButtonStyle.primary,
    this.height = 48,
  });

  Color _bg(BuildContext context) {
    switch (style) {
      case FuturisticButtonStyle.secondary:
        return Theme.of(context).colorScheme.secondary;
      case FuturisticButtonStyle.danger:
        return Colors.redAccent;
      case FuturisticButtonStyle.primary:
        return Theme.of(context).primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: _bg(context), minimumSize: Size(double.infinity, height)),
      child: child,
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
    return IconButton(onPressed: onPressed, icon: Icon(icon), iconSize: size, color: Theme.of(context).iconTheme.color);
  }
}


