import 'package:flutter/material.dart';

/// Small overlay indicator when recording is active.
class RecordingIndicator extends StatelessWidget {
  const RecordingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      right: 10,
      child: Row(
        children: [
          Icon(
            Icons.fiber_manual_record,
            color: Colors.red,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            "REC",
            style: const TextStyle(
              color: Colors.red,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
