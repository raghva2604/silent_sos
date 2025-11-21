import 'package:flutter/services.dart';

class ForegroundService {
  static const MethodChannel _channel = MethodChannel('silent_sos/foreground');

  /// No-op init: native service doesn't require Dart-side init beyond this.
  static Future<void> init() async {}

  /// Start the native foreground sensor service implemented in Android.
  static Future<bool> startService() async {
    try {
      final res = await _channel.invokeMethod('start');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Stop the native foreground sensor service.
  static Future<bool> stopService() async {
    try {
      final res = await _channel.invokeMethod('stop');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Send SMS via native SmsManager for reliable, silent sending (requires SEND_SMS permission).
  static Future<bool> sendSms(String to, String body) async {
    final m = await sendSmsDetailed(to, body);
    try {
      if (m == null) return false;
      if (m.containsKey('success')) return m['success'] == true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Send SMS via native and return a detailed map of results for diagnostics.
  /// Returns null if the platform call failed.
  static Future<Map<String, dynamic>?> sendSmsDetailed(String to, String body) async {
    try {
      final res = await _channel.invokeMethod('sendSms', {'to': to, 'body': body});
      if (res is Map) return Map<String, dynamic>.from(res.cast<String, dynamic>());
      // If the platform returned a simple boolean, normalize it.
      if (res is bool) return {'success': res};
      return {'success': false, 'error': 'unknown_response'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update native service fall-detection threshold (g)
  static Future<bool> setThreshold(double g) async {
    try {
      final res = await _channel.invokeMethod('setThreshold', {'value': g});
      return res == true;
    } catch (e) {
      return false;
    }
  }
}
