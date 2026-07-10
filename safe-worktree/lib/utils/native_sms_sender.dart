import 'package:flutter/services.dart';

/// Native Android SMS sending to bypass any app interceptors
class NativeSMSSender {
  static const MethodChannel _channel = MethodChannel('silent_sos/sms');

  /// Send SMS via native Android intent
  /// This completely bypasses any third-party app interception like WhatsApp
  static Future<void> sendSMS({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('sendSMS', {
        'phoneNumbers': phoneNumbers,
        'message': message,
      });

      print('🔴 NativeSMSSender: SMS sent via native intent (result=$result)');
    } catch (e) {
      print('🔴 NativeSMSSender: Error sending SMS: $e');
      rethrow;
    }
  }
}
