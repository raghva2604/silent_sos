import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../sos/sos_controller.dart';
import '../services/sos_service.dart';

/// Lightweight voice activation service.
///
/// Listens for emergency keywords and triggers SOS.
/// It supports an initial auto-listen period and a manual trigger button.
class VoiceActivationService {
  VoiceActivationService._();
  static final VoiceActivationService instance = VoiceActivationService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _isListening = false;
  Timer? _autoStopTimer;
  BuildContext? _context;

  bool get isListening => _isListening;

  /// Initialize speech recognizer.
  Future<void> init() async {
    if (_initialized) return;
    try {
      _initialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (error) {
          debugPrint('VoiceActivationService: Speech error: $error');
          _isListening = false;
        },
      );
    } catch (e) {
      debugPrint('VoiceActivationService: init failed: $e');
      _initialized = false;
    }
  }

  /// Starts listening for emergency keywords.
  ///
  /// The [context] is required for triggering SOS dialogs.
  /// [durationSeconds] controls how long the listener stays active (default 20s).
  Future<void> startListening({
    required BuildContext context,
    int durationSeconds = 120,
  }) async {
    _context = context;

    if (!_initialized) {
      await init();
    }

    if (!_initialized) return;

    if (_isListening) return;

    _isListening = true;

    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(Duration(seconds: durationSeconds), () {
      stopListening();
    });

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: Duration(seconds: durationSeconds),
        pauseFor: const Duration(seconds: 10),
        localeId: 'en_US',
      );
    } catch (e) {
      debugPrint('VoiceActivationService: listen failed: $e');
      _isListening = false;
    }
  }

  void _onSpeechResult(dynamic result) {
    if (!result.finalResult) return;
    final recognized = (result.recognizedWords ?? '').toString().toLowerCase();
    if (recognized.isEmpty) return;

    double confidence = 0.0;
    try {
      confidence = (result.confidence != null)
          ? double.tryParse(result.confidence.toString()) ?? 0.0
          : 0.0;
    } catch (_) {
      confidence = 0.0;
    }

    // Confidence threshold avoids noise triggers.
    if (confidence < 0.8) {
      debugPrint('VoiceActivationService: ignored low confidence ($confidence)');
      return;
    }

    const keywords = [
      'help me',
      'emergency',
      'save me',
      'i need help',
      'sos',
      'call help',
    ];

    for (final keyword in keywords) {
      if (recognized.contains(keyword)) {
        debugPrint('VoiceActivationService: keyword detected - $keyword @ ${confidence.toStringAsFixed(2)}');
        stopListening();
        _triggerSOS();
        break;
      }
    }
  }

  Future<void> _triggerSOS() async {
    final ctx = _context ?? SOSservice.navigatorKey.currentState?.context;
    if (ctx == null) return;

    SosController.triggerSOS(context: ctx, source: 'voice');
  }

  /// Stops listening immediately.
  Future<void> stopListening() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    if (!_isListening) return;
    _isListening = false;
    try {
      await _speech.stop();
    } catch (e) {
      // ignore
    }
  }

  /// Pauses listening until resumed.
  Future<void> pause() async {
    await stopListening();
  }

  /// Resumes listening if initialized.
  Future<void> resume(
      {required BuildContext context, int durationSeconds = 40}) async {
    if (!_initialized) await init();
    if (!_initialized) return;
    await startListening(context: context, durationSeconds: durationSeconds);
  }
}
