import 'dart:async';
import 'package:flutter/services.dart';

class HotwordIntegration {
  static const MethodChannel _channel = MethodChannel('silent_sos/hotword');
  static final StreamController<Map<String, dynamic>> _hotwordController = StreamController.broadcast();

  static Stream<Map<String, dynamic>> get onHotwordDetected => _hotwordController.stream;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'hotword_detected') {
        final Map args = (call.arguments ?? {}) as Map;
        _hotwordController.add(Map<String, dynamic>.from(args));
      }
    });
  }

  static Future<void> startService() async {
    try {
      await _channel.invokeMethod('startHotwordService');
    } catch (e) {
      // Ignored; native may not implement this helper
    }
  }

  static Future<void> dispose() async {
    await _hotwordController.close();
  }
}
