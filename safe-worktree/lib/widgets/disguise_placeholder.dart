import 'package:flutter/material.dart';
import 'disguise_wrapper.dart';

class DisguisePlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;

  const DisguisePlaceholder({
    required this.title,
    required this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DisguiseWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                const Icon(Icons.lock, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'Hidden SOS is active. Long press anywhere to trigger.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
