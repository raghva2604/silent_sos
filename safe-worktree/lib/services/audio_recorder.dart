import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Audio recorder for SOS events
/// Records ambient audio in parallel with video for additional evidence
class AudioRecorderService {
  static const String _tag = '🎙️ AudioRecorderService';
  static final _audioRecorder = AudioRecorder();

  /// Record audio for specified duration
  /// Returns file path if successful, null if failed
  static Future<String?> recordAudio({
    required Duration duration,
  }) async {
    try {
      debugPrint('$_tag: Requesting microphone permission...');
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('$_tag: ❌ Microphone permission denied');
        return null;
      }

      debugPrint(
          '$_tag: Starting audio recording for ${duration.inSeconds}s...');

      // Get documents directory
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/sos_audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final fileName = 'sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = '${audioDir.path}/$fileName';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(),
        path: filePath,
      );

      debugPrint('$_tag: Recording started at $filePath');

      // Wait for duration
      await Future.delayed(duration);

      // Stop recording
      final path = await _audioRecorder.stop();
      debugPrint('$_tag: ✅ Audio recorded: $path');

      return path;
    } catch (e) {
      debugPrint('$_tag: ❌ Recording error: $e');
      return null;
    }
  }

  /// Record audio in background (non-blocking)
  /// Returns Future that completes when recording stops
  static Future<String?> recordAudioAsync({
    required Duration duration,
  }) {
    return recordAudio(duration: duration);
  }
}
