import 'package:flutter/services.dart';

/// 🚨 BULLETPROOF EMAIL SENDER
/// Uses native Android Intent.ACTION_SENDTO for guaranteed email opening
/// Never silently fails unlike url_launcher mailto: which is unreliable on many OEM devices
class NativeEmailSender {
  static const MethodChannel _channel = MethodChannel('silent_sos/email');

  /// Open email app with recipients, subject, and body
  /// Guaranteed to either open email or throw exception
  /// Will show system chooser if multiple email apps installed
  static Future<void> openEmail({
    required List<String> recipients,
    required String subject,
    required String body,
  }) async {
    try {
      final result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('openEmail', {
        'recipients': recipients.join(','),
        'subject': subject,
        'body': body,
      });

      if (result?['success'] != true) {
        throw Exception('Failed to open email app');
      }
    } catch (e) {
      print('🚨 Email error: $e');
      rethrow;
    }
  }
}
