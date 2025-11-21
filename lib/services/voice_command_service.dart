import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple push-to-talk voice command service (MVP)
/// - Provides startListening/stopListening for UI wiring
/// - Emits recognized text via [onResult] stream
/// - Does not run a continuous wake-word listener (requires foreground service on Android)
class VoiceCommandService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _initialized = false;
  static final StreamController<String> _resultController = StreamController<String>.broadcast();
  static Stream<String> get onResult => _resultController.stream;

  /// Check whether the recognized text matches any configured voice triggers.
  /// Reads comma-separated 'voice_triggers' from SharedPreferences.
  static Future<bool> isTrigger(String text) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('voice_triggers') ?? '';
      final defaults = listOfDefaultTriggers();

      final List<String> rawList = [];
      if (raw.isNotEmpty) {
        final parts = raw.split(',');
        for (var p in parts) {
          final s = p.trim();
          if (s.isNotEmpty) rawList.add(s.toLowerCase());
        }
      }

      final defLower = defaults.map((s) => s.toLowerCase()).toList();
      final Set<String> triggers = {...rawList, ...defLower};

      final t = text.toLowerCase();
      for (final trg in triggers) {
        if (t.contains(trg)) return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('isTrigger failed: $e');
      return false;
    }
  }

  static List<String> listOfDefaultTriggers() => ['help', 'sos', 'emergency', 'help me'];

  /// Initialize the underlying speech plugin. Call from app start or when
  /// user enables voice features. Returns true if the engine is available.
  static Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      final available = await _speech.initialize(onError: (e) {
        if (kDebugMode) debugPrint('Speech init error: $e');
      }, onStatus: (s) {
        if (kDebugMode) debugPrint('Speech status: $s');
      });
      _initialized = available;
      return available;
    } catch (e) {
      if (kDebugMode) debugPrint('Speech initialize failed: $e');
      return false;
    }
  }

  /// Start a short (configurable) listening session. Results are emitted
  /// on [onResult]. Caller should await or listen for the next event.
  static Future<void> startListening({int timeoutSeconds = 8}) async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return;
    }
    try {
      // Ensure microphone permission is granted before starting listening
      try {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (kDebugMode) debugPrint('Microphone permission denied, aborting listen');
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Microphone permission request failed: $e');
      }
      // Respect user opt-in before starting background voice features
      final prefs = await SharedPreferences.getInstance();
      final optIn = prefs.getBool('push_to_talk_opt_in') ?? false;
      if (!optIn) {
        if (kDebugMode) debugPrint('Voice features not enabled by user (push_to_talk_opt_in=false)');
        return;
      }

      final threshold = prefs.getDouble('voice_confidence_threshold') ?? 0.7;

      await _speech.listen(onResult: (res) async {
        try {
          final conf = res.confidence;
          if (res.finalResult && conf >= threshold) {
            _resultController.add(res.recognizedWords);
          } else {
            if (kDebugMode) debugPrint('Speech result ignored due to low confidence: $conf (threshold=$threshold)');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('onResult handling failed: $e');
        }
      }, listenFor: Duration(seconds: timeoutSeconds));
    } catch (e) {
      if (kDebugMode) debugPrint('startListening error: $e');
    }
  }

  static Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  static void dispose() {
    try {
      _resultController.close();
    } catch (_) {}
  }
}
