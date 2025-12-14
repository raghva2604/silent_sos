import 'package:flutter/services.dart';
import 'dart:developer' as developer;

/// Helper to control image danger detection service via MethodChannel.
class ImageDangerDetectionService {
  static const MethodChannel _channel = MethodChannel('silent_sos/foreground');

  /// Start the image danger detection service.
  /// The service will periodically capture camera frames and analyze them for danger indicators.
  static Future<bool> start() async {
    try {
      final result = await _channel.invokeMethod<bool>('startImageDangerDetection');
      return result ?? false;
    } on PlatformException catch (e) {
      developer.log('Failed to start image danger detection: ${e.message}', name: 'ImageDangerDetectionService');
      return false;
    }
  }

  /// Stop the image danger detection service.
  static Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopImageDangerDetection');
      return result ?? false;
    } on PlatformException catch (e) {
      developer.log('Failed to stop image danger detection: ${e.message}', name: 'ImageDangerDetectionService');
      return false;
    }
  }
}
