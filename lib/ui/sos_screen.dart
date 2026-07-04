import 'package:flutter/material.dart';
import 'package:silent_sos/core/sos_controller.dart';

/// Display the SOS countdown and cancel button.
/// Uses ValueListenableBuilder to reactively display countdown state.
class SosScreen extends StatelessWidget {
  final int initialCountdown;
  final VoidCallback? onCanceled;

  const SosScreen({
    super.key,
    this.initialCountdown = 10,
    this.onCanceled,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 SOS Active'),
        backgroundColor: Colors.red,
        elevation: 0,
      ),
      body: Center(
        child: ValueListenableBuilder<int?>(
          valueListenable: ValueNotifier(SosController.instance.getRemaining()),
          builder: (context, countdownValue, _) {
            final isActive = countdownValue != null && countdownValue > 0;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Countdown number with pulsing animation
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: isActive ? 120 : 80,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.red : Colors.grey,
                  ),
                  child: Text(
                    isActive ? '$countdownValue' : 'Ready',
                    key: ValueKey(countdownValue), // Force rebuild on change
                  ),
                ),

                const SizedBox(height: 40),

                // Status message
                Text(
                  isActive
                      ? 'SOS triggered! Sending emergency alert...'
                      : 'SOS System Ready',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isActive ? Colors.red : Colors.green,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 60),

                // Cancel button (only visible when countdown is active)
                if (isActive)
                  ElevatedButton.icon(
                    onPressed: () {
                      SosController.instance.stop();
                      onCanceled?.call();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('CANCEL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // Inactive Ready button
                if (!isActive)
                  ElevatedButton.icon(
                    onPressed: () {
                      SosController.instance.start(
                        seconds: initialCountdown,
                        onSend: () {
                          // Send SOS logic here
                          debugPrint('📤 Sending SOS...');
                        },
                      );
                    },
                    icon: const Icon(Icons.warning),
                    label: const Text('SEND NOW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
