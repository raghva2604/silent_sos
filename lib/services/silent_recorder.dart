import 'package:flutter/services.dart';
// path_provider import removed (unused)
// Removed dependency on `record` plugin to avoid AGP namespace issues in
// some plugin releases during release builds. Recording is done via the
// native foreground service when enabled by the user's preferences.
import 'package:shared_preferences/shared_preferences.dart';

/// Simple silent audio recorder (MVP)
/// - Records short audio to app temporary directory and returns path
class SilentRecorder {
  // No Dart plugin recorder available in this build; rely on native service.
  static const MethodChannel _nativeChannel = MethodChannel('silent_sos/foreground');

  /// Record for [seconds] seconds and return the recorded file path.
  /// This MVP implementation records in the foreground only and returns the
  /// saved file path or null on failure.
  /// Record audio. If the user has enabled background/native recording this will
  /// attempt to use the native foreground service; otherwise it falls back to
  /// the Dart `record` plugin which requires the app to remain in the foreground.
  static Future<String?> recordAudio({int seconds = 20}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final useNative = prefs.getBool('allow_auto_audio') ?? false;
      if (useNative) {
        try {
          // Ask native to start recording; it runs as a foreground service.
          await _nativeChannel.invokeMethod('startNativeRecording', {
            'maxDurationSeconds': seconds,
            'label': 'sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a'
          });
          // We can't directly await native completion here; the service persists
          // the recorded path into FlutterSharedPreferences and also broadcasts
          // a completion intent. Best-effort: wait up to (seconds + 3s) and read the key.
          final wait = Duration(seconds: seconds + 3);
          final end = DateTime.now().add(wait);
          String? last;
          while (DateTime.now().isBefore(end)) {
            final p = await SharedPreferences.getInstance();
            last = p.getString('last_native_recording_path');
            if (last != null) break;
            await Future.delayed(const Duration(milliseconds: 300));
          }
          return last;
        } catch (e) {
          // Native recording failed; no Dart recorder available in this
          // build variant. Return null to indicate failure. In future we
          // can re-introduce a Dart fallback if a patched `record` plugin
          // is available.
          return null;
        }
      } else {
        // Background/native recording is disabled by user preference and no
        // Dart foreground recorder is included in this build variant. Return
        // null to indicate no recording was performed.
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
