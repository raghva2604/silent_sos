import 'dart:async';
import 'package:flutter/services.dart';

typedef UploadProgressCb = void Function(int);
typedef UploadCompleteCb = void Function(Map<String, dynamic>);
typedef HotwordCb = void Function(String phrase);
typedef RequirePinCb = void Function(bool fromNotification);
typedef FallCb = void Function(String trigger);
typedef VideoSavedCb = void Function(String videoPath);
typedef VoiceCommandCb = void Function(String command);

class SosIntegration {
  static const MethodChannel _channel = MethodChannel('silent_sos/foreground');

  static UploadProgressCb? _onUploadProgress;
  static UploadCompleteCb? _onUploadComplete;
  static HotwordCb? _onHotwordDetected;
  static RequirePinCb? _onRequirePin;
  static FallCb? _onFallDetected;
  static VideoSavedCb? _onVideoSaved;
  static VoiceCommandCb? _onVoiceCommand;

  /// Initialize the method channel handlers for native -> Dart events.
  static void initializeUploadListeners() {
    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'videoUploadProgress':
            final v = call.arguments as int? ?? 0;
            _onUploadProgress?.call(v);
            break;
          case 'videoUploadSuccess':
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            _onUploadComplete?.call(args);
            break;
          case 'videoUploadFailed':
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            _onUploadComplete?.call({'success': false, 'error': args['error']});
            break;
          case 'hotword_detected':
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            final phrase = args['phrase']?.toString() ?? '';
            _onHotwordDetected?.call(phrase);
            break;
          case 'fall_detected':
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            final trigger = args['trigger']?.toString() ?? 'fall';
            _onFallDetected?.call(trigger);
            break;
          case 'requirePin':
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            final fromNotification = args['fromNotification'] as bool? ?? false;
            _onRequirePin?.call(fromNotification);
            break;
          case 'nativeDiagnostic':
            // Handle native fall detection forwarded from MainActivity
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            final payload = args['payload']?.toString() ?? '';
            if (payload.contains('Fall detected')) {
              print('🔴 Native Fall Detected via nativeDiagnostic!');
              _onFallDetected?.call('fall');
            } else {
              _onUploadComplete?.call({'diagnostic': payload});
            }
            break;
          case 'video_saved':
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            final path = args['path']?.toString() ?? '';
            if (path.isNotEmpty) {
              _onVideoSaved?.call(path);
            }
            break;
          case 'countdown_started':
            // Log countdown start from native; Dart can optionally show UI
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            final seconds = args['seconds'] as int? ?? 10;
            final source = args['source']?.toString() ?? 'unknown';
            print('🔔 Native countdown_started: $seconds sec from $source');
            break;
          case 'recording_started':
            // Log recording start from native
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            final duration = args['duration'] as int? ?? 15;
            print('🎥 Native recording_started: $duration sec');
            break;
          case 'voice_command_triggered':
            // Google Assistant voice command detected
            final args = Map<String, dynamic>.from(call.arguments ?? {});
            final command = args['command']?.toString() ?? '';
            print('🎤 Google Assistant voice command: $command');
            _onVoiceCommand?.call(command);
            break;
          default:
            break;
        }
      } catch (e) {
        // swallow errors to avoid crashing native handler
      }
    });
  }

  static void setOnUploadProgress(UploadProgressCb cb) =>
      _onUploadProgress = cb;
  static void setOnUploadComplete(UploadCompleteCb cb) =>
      _onUploadComplete = cb;
  static void setOnHotwordDetected(HotwordCb cb) => _onHotwordDetected = cb;
  static void setOnRequirePin(RequirePinCb cb) => _onRequirePin = cb;
  static void setOnFallDetected(FallCb cb) => _onFallDetected = cb;
  static void setOnVideoSaved(VideoSavedCb cb) => _onVideoSaved = cb;
  static void setOnVoiceCommand(VoiceCommandCb cb) => _onVoiceCommand = cb;

  // ------------ Native control wrappers ------------
  static Future<bool> startNativeService() async {
    try {
      final res = await _channel.invokeMethod('start');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopNativeService() async {
    try {
      final res = await _channel.invokeMethod('stop');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> startNativeRecording(
      {int maxSeconds = 60, String? label}) async {
    try {
      final args = {'maxSeconds': maxSeconds, 'label': label};
      final res = await _channel.invokeMethod('startNativeRecording', args);
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopNativeRecording() async {
    try {
      final res = await _channel.invokeMethod('stopNativeRecording');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> startHotwordService() async {
    try {
      final res = await _channel.invokeMethod('startHotwordService');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopHotwordService() async {
    try {
      final res = await _channel.invokeMethod('stopHotwordService');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> bringToForeground(Map<String, dynamic> extras) async {
    try {
      final res = await _channel.invokeMethod('bringToForeground', extras);
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> requestOverlayPermission() async {
    try {
      final res = await _channel.invokeMethod('requestOverlayPermission');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> cancelNativePending() async {
    try {
      final res = await _channel.invokeMethod('cancelNativePending');
      return res == true;
    } catch (e) {
      return false;
    }
  }
}
