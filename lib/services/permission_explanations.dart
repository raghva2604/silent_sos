import 'package:flutter/material.dart';

class PermissionExplanations {
  static Future<bool> showMicrophoneExplanation(BuildContext context) async {
    return await _showExplanationDialog(
      context,
      'Microphone Permission',
      'We need access to your microphone to detect emergency voice commands like "help", "accident", "emergency" and other keywords. This allows the app to respond to your voice during emergencies.',
    );
  }

  static Future<bool> showLocationExplanation(BuildContext context) async {
    return await _showExplanationDialog(
      context,
      'Location Permission',
      'We need your precise location to send it along with your emergency SOS alert. This helps emergency responders reach you quickly.',
    );
  }

  static Future<bool> showCameraExplanation(BuildContext context) async {
    return await _showExplanationDialog(
      context,
      'Camera Permission',
      'We need camera access to optionally record video during emergencies. This evidence can help emergency responders understand the situation better.',
    );
  }

  static Future<bool> showContactsExplanation(BuildContext context) async {
    return await _showExplanationDialog(
      context,
      'Contacts Permission',
      'We need access to your contacts so you can easily select emergency recipients for your SOS alerts.',
    );
  }

  static Future<bool> showNotificationExplanation(BuildContext context) async {
    return await _showExplanationDialog(
      context,
      'Notification Permission',
      'We need to send you notifications for emergency confirmations, safe walk updates, and system status alerts.',
    );
  }

  static Future<bool> showActivityExplanation(BuildContext context) async {
    return await _showExplanationDialog(
      context,
      'Physical Activity Permission',
      'We need to access motion sensors to detect falls using accelerometer and gyroscope data. This triggers automatic emergency alerts if you fall.',
    );
  }

  static Future<bool> _showExplanationDialog(
    BuildContext context,
    String title,
    String explanation,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                explanation,
                style: const TextStyle(height: 1.5, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.withAlpha(100)),
                ),
                child: const Text(
                  'This is required for the emergency detection system to function properly.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Proceed', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
