// lib/services/voice_hotword_service.dart
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

typedef HotwordCallback = Future<void> Function(String recognizedText);

class VoiceHotwordService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _listening = false;
  final List<String> hotwords;
  final HotwordCallback onHotwordDetected;

  VoiceHotwordService({required this.hotwords, required this.onHotwordDetected});

  Future<void> init() async {
    _available = await _speech.initialize(onStatus: _onStatus, onError: (err) => _onError(err));
    if (!_available) debugPrint('Speech not available');
  }

  void startListening() {
    if (!_available) return;
    if (_listening) return;

    _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.toLowerCase();
        debugPrint('STT result: $text');
        for (final hw in hotwords) {
          if (text.contains(hw.toLowerCase())) {
            onHotwordDetected(text);
            break;
          }
        }
      },
    );
    _listening = true;
  }

  void stopListening() {
    if (!_listening) return;
    _speech.stop();
    _listening = false;
  }

  void _onStatus(String status) {
    debugPrint('Speech status: $status');
    if (status == 'done' || status == 'notListening') {
      Future.delayed(Duration(milliseconds: 300), () {
        if (_available) startListening();
      });
    }
  }

  void _onError(dynamic error) {
    debugPrint('Speech error: $error');
    Future.delayed(const Duration(milliseconds: 700), () {
      if (_available) startListening();
    });
  }
}
