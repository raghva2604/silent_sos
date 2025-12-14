import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'sos_service.dart';

/// VoiceCommandService: single-file, consistent implementation.
class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _listening = false;
  final StreamController<String> _commandController = StreamController<String>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  Stream<String> get onCommand => _commandController.stream;
  Stream<String> get onStatus => _statusController.stream;

  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      final avail = await _speech.initialize(onStatus: (s) {
        if (kDebugMode) debugPrint('Speech status: $s');
      }, onError: (e) {
        if (kDebugMode) debugPrint('Speech error: $e');
      });
      _initialized = avail;
      return avail;
    } catch (e) {
      if (kDebugMode) debugPrint('Speech initialize failed: $e');
      return false;
    }
  }

  Future<void> startListening({required List<String> recipients}) async {
    final mic = await Permission.microphone.request();
    if (mic != PermissionStatus.granted) {
      if (kDebugMode) debugPrint('Microphone permission denied');
      return;
    }

    final ok = await initialize();
    if (!ok) return;
    if (_listening) return;
    _listening = true;

    final triggers = await _loadTriggers();

    _speech.listen(
      onResult: (res) async {
        final text = res.recognizedWords.toLowerCase();
        if (text.isEmpty) return;
        for (final t in triggers) {
          if (text.contains(t)) {
            _commandController.add(text);
            // Trigger SOS send
            try {
              _statusController.add('sending');
              final resp = await SosService().triggerSos(
                senderUid: 'voice_command',
                recipients: recipients,
                captureVideo: false,
                audioDurationSeconds: 8,
              );
              if (resp['ok'] == true) {
                _statusController.add('sent');
              } else {
                _statusController.add('failed:${resp['error'] ?? 'unknown'}');
              }
            } catch (e) {
              if (kDebugMode) debugPrint('sendSos failed: $e');
              _statusController.add('failed:$e');
            }

            // Try to call first recipient
            if (recipients.isNotEmpty) {
              final first = recipients.first;
              final uri = Uri.parse('tel:$first');
              try {
                await launchUrl(uri);
              } catch (e) {
                if (kDebugMode) debugPrint('Call launch failed: $e');
              }
            }

            break;
          }
        }
      },
      listenFor: const Duration(seconds: 40),
      pauseFor: const Duration(seconds: 2),
      listenOptions: stt.SpeechListenOptions(partialResults: true),
    );
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    _listening = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<List<String>> _loadTriggers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('voice_triggers') ?? '';
      final defaults = ['help me', 'call help', 'i need help', 'sos', 'help'];
      final set = <String>{};
      if (raw.isNotEmpty) {
        for (var s in raw.split(',')) {
          final t = s.trim().toLowerCase();
          if (t.isNotEmpty) set.add(t);
        }
      }
      set.addAll(defaults.map((e) => e.toLowerCase()));
      return set.toList();
    } catch (e) {
      if (kDebugMode) debugPrint('loadTriggers failed: $e');
      return ['help me', 'call help', 'i need help', 'sos', 'help'];
    }
  }

  // --- Backwards-compatible static API used elsewhere in the app/tests ---
  static Stream<String> get onResult => VoiceCommandService().onCommand;

  /// Check whether given text matches any configured triggers (used by tests)
  static Future<bool> isTrigger(String text) async {
    final triggers = await VoiceCommandService()._loadTriggers();
    final t = text.toLowerCase();
    for (final trg in triggers) {
      if (t.contains(trg)) return true;
    }
    return false;
  }
}
 

