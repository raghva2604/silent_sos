import 'dart:async';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:phone_state/phone_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_settings.dart';

/// 🔥 SEQUENTIAL CALL ENGINE
/// Handles:
/// ✔️ Sequential calling to multiple contacts
/// ✔️ Retry logic for failed calls
/// ✔️ TTS voice message on call pickup using phone state
/// ✔️ Fallback to 112 if no contacts
class CallService {
  static final FlutterTts _tts = FlutterTts();
  static StreamSubscription<PhoneState>? _phoneStateSubscription;
  static bool _alreadySpokenInCall = false;
  static Timer? _ttsDelayTimer;

  static Future<void> _initPhoneStateListener() async {
    if (_phoneStateSubscription != null) return;

    try {
      _phoneStateSubscription = PhoneState.stream.listen((state) {
        debugPrint('📡 Phone state update: ${state.status}');

        if (state.status == PhoneStateStatus.CALL_STARTED) {
          // play TTS only after a short delay to avoid reading while dialing
          // (some devices report CALL_STARTED immediately on dialing)
          if (!_alreadySpokenInCall && _ttsDelayTimer == null) {
            debugPrint('⏳ Call started: queuing TTS after pickup-like delay');
            _ttsDelayTimer = Timer(const Duration(seconds: 4), () async {
              _ttsDelayTimer = null;

              // Still in call and not spoken yet
              if (!_alreadySpokenInCall) {
                _alreadySpokenInCall = true;
                await _speak();
              }
            });
          }
        }

        if (state.status == PhoneStateStatus.CALL_ENDED) {
          debugPrint('📴 Call ended, stopping TTS and cancelling timer');
          _ttsDelayTimer?.cancel();
          _ttsDelayTimer = null;
          _stopTts();
          _alreadySpokenInCall = false;
        }
      }, onError: (error) {
        debugPrint('⚠️ Phone state listener error: $error');
      });
    } catch (e) {
      debugPrint('⚠️ Could not init PhoneState listener: $e');
    }
  }

  static Future<void> _disposePhoneStateListener() async {
    await _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
    _ttsDelayTimer?.cancel();
    _ttsDelayTimer = null;
    _alreadySpokenInCall = false;
    _stopTts();
  }

  static Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('⚠️ Error stopping TTS: $e');
    }
  }

  /// 🔊 Speak emergency message via TTS
  static Future<void> _speak() async {
    try {
      // Load custom message from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String msg = prefs.getString('auto_call_message') ??
          "Emergency alert. This person is in danger. Please check location sent via SMS or email immediately.";

      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.5);
      await _tts.speak(msg);

      debugPrint('🔊 Voice message played');
    } catch (e) {
      debugPrint('⚠️ TTS failed: $e');
    }
  }

  /// Load call settings from SharedPreferences
  static Future<CallSettings> _loadCallSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return CallSettings(
        retryCount: prefs.getInt('retry_count') ?? 1,
      );
    } catch (e) {
      debugPrint('⚠️ Error loading call settings: $e');
      return CallSettings();
    }
  }

  ///  Call contacts sequentially with retry logic
  static Future<void> callSequence({
    required List<String> contacts,
    required CallSettings settings,
  }) async {
    try {
      debugPrint('📞 CallService START with ${contacts.length} contacts');
      
      // Load the latest settings from SharedPreferences
      final loadedSettings = await _loadCallSettings();
      debugPrint('📞 Loaded call settings: $loadedSettings');
      
      await _initPhoneStateListener();

      // Fallback: No contacts → call emergency
      if (contacts.isEmpty) {
        debugPrint('⚠️ No contacts configured → calling 112');

        _alreadySpokenInCall = false;
        await FlutterPhoneDirectCaller.callNumber('112');

        // Wait for call to end or timeout
        await Future.delayed(const Duration(seconds: 30));
        await _disposePhoneStateListener();
        return;
      }

      // Sequential calling with retry
      for (String number in contacts) {
        debugPrint('📞 Calling: $number');

        // ensure any previous TTS playback is stopped before new call
        await _stopTts();

        bool success = false;

        // for each new number, reset pickup detection
        _alreadySpokenInCall = false;

        for (int attempt = 0; attempt <= loadedSettings.retryCount; attempt++) {
          debugPrint('  📞 Attempt ${attempt + 1} of ${loadedSettings.retryCount + 1}');

          try {
            bool? result = await FlutterPhoneDirectCaller.callNumber(number);

            if (result == true) {
              success = true;
              debugPrint('✅ Call started: $number');

              // Wait for call to end or timeout
              await Future.delayed(const Duration(seconds: 30));
              break;
            } else {
              debugPrint('❌ Call initiation failed');
              if (attempt < loadedSettings.retryCount) {
                await Future.delayed(const Duration(seconds: 3));
              }
            }
          } catch (e) {
            debugPrint('❌ Call exception: $e');
            if (attempt < loadedSettings.retryCount) {
              await Future.delayed(const Duration(seconds: 3));
            }
          }
        }

        if (success) {
          debugPrint('✅ Call completed for $number');
        } else {
          debugPrint('📴 Call failed for $number, moving to next contact...');
        }
      }

      await _disposePhoneStateListener();
      debugPrint('✅ All contacts processed');
    } catch (e) {
      await _disposePhoneStateListener();
      debugPrint('❌ CallService error: $e');
    }
  }
}
