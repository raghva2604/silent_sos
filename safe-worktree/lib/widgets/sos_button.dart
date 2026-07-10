// lib/widgets/sos_button.dart
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_sos/core/sos_controller.dart';
import 'package:silent_sos/ui/sos_screen.dart';

class SosButtonWidget extends StatefulWidget {
  const SosButtonWidget({super.key});

  @override
  State<SosButtonWidget> createState() => _SosButtonWidgetState();
}

class _SosButtonWidgetState extends State<SosButtonWidget> {
  @override
  void initState() {
    super.initState();
    // Voice trigger is now handled by VoiceService in background
    // No need to manually manage hotword detection here
  }

  Future<void> _sendSos() async {
    try {
      debugPrint('📱 Manual SOS button pressed');

      // Get countdown from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final countdownSeconds = prefs.getInt('sos_timer') ?? 10;

      // Start the countdown via SosController
      SosController.instance.start(
        seconds: countdownSeconds,
        onSend: () async {
          // Trigger the actual SOS alert
          try {
            final sessionId = const String.fromEnvironment('SESSION_ID',
                defaultValue: 'unknown');
            debugPrint('✓ SOS alert sent: $sessionId');
            Fluttertoast.showToast(
              msg: 'Alert sent',
            );
          } catch (e) {
            debugPrint('✗ Failed to send SOS: $e');
            Fluttertoast.showToast(msg: 'Failed to send alert: $e');
          }
        },
      );

      // Show SOS countdown screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SosScreen(
              initialCountdown: countdownSeconds,
              onCanceled: () {
                Fluttertoast.showToast(msg: 'SOS canceled');
                debugPrint('✓ Manual SOS canceled by user');
              },
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('✗ SOS button error: $e\n$st');
      Fluttertoast.showToast(msg: 'SOS failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.warning),
      label: const Text('Send SOS Now'),
      onPressed: _sendSos,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    );
  }
}
