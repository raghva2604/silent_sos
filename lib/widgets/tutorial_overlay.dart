import 'package:flutter/material.dart';
import 'package:silent_sos/src/widgets/neon_widgets.dart';

class TutorialStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  TutorialStep({required this.targetKey, required this.title, required this.description});
}

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback? onFinish;
  const TutorialOverlay({super.key, required this.steps, this.onFinish});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  int _index = 0;

  void _next() {
    if (_index < widget.steps.length - 1) {
      setState(() => _index++);
    } else {
      widget.onFinish?.call();
    }
  }

  void _skip() {
    widget.onFinish?.call();
  }

  Rect? _getTargetRect(GlobalKey key) {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;
      final box = ctx.findRenderObject() as RenderBox;
      final pos = box.localToGlobal(Offset.zero);
      return pos & box.size;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    final step = widget.steps[_index];
    final rect = _getTargetRect(step.targetKey);

    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          // Highlight box
          if (rect != null)
            Positioned(
              left: rect.left - 8,
              top: rect.top - 8,
              width: rect.width + 16,
              height: rect.height + 16,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                    color: Colors.transparent,
                    boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withAlpha(40), blurRadius: 24, spreadRadius: 8)],
                  ),
                ),
              ),
            ),
          // Tooltip bubble
          if (rect != null)
            Positioned(
              left: 20,
              top: rect.bottom + 12,
              right: 20,
              child: _Bubble(title: step.title, description: step.description, onNext: _next, onSkip: _skip, isLast: _index == widget.steps.length - 1),
            )
          else
            Center(child: _Bubble(title: step.title, description: step.description, onNext: _next, onSkip: _skip, isLast: _index == widget.steps.length - 1)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;
  const _Bubble({required this.title, required this.description, required this.onNext, required this.onSkip, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0E0E14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
                Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NeonButton(onTap: onSkip, child: const Text('Skip')),
                const SizedBox(width: 8),
                NeonButton(onTap: onNext, child: Text(isLast ? 'Finish' : 'Next')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
