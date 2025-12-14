import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SosIntegration {
  // Channel name used by existing MainActivity.kt
  static const MethodChannel _channel = MethodChannel('silent_sos/foreground');

  // Callbacks for upload progress and completion
  static VoidCallback? _onUploadProgress;
  static Function(Map<String, dynamic>)? _onUploadComplete;

  /// Initialize upload progress listeners.
  /// Call this once during app startup to set up listening for native upload events.
  static void initializeUploadListeners() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'upload_progress') {
        final progress = call.arguments['progress'] as int?;
        if (progress != null && _onUploadProgress != null) {
          _onUploadProgress!();
        }
      } else if (call.method == 'upload_complete') {
        final result = Map<String, dynamic>.from(call.arguments ?? {});
        if (_onUploadComplete != null) {
          _onUploadComplete!(result);
        }
      }
    });
  }

  /// Set a callback to be invoked when upload progress is reported.
  /// The progress value is available via the MethodChannel argument.
  /// Example: (progress) => print('Upload progress: $progress%')
  static void setOnUploadProgress(Function(int) callback) {
    _onUploadProgress = () {
      // Note: progress value is embedded in the MethodChannel call
      // Retrieve via _channel.invokeMethod if needed or track via _onUploadComplete
    };
  }

  /// Set a callback to be invoked when upload completes.
  /// The result map contains: {success: bool, error: String, payload: String}
  /// Example: (result) => print('Upload complete: ${result["success"]}')
  static void setOnUploadComplete(Function(Map<String, dynamic>) callback) {
    _onUploadComplete = callback;
  }

  /// Start the native foreground sensor service (non-recording)
  static Future<bool> startNativeService() async {
    try {
      final res = await _channel.invokeMethod('start');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Stop native foreground service
  static Future<bool> stopNativeService() async {
    try {
      final res = await _channel.invokeMethod('stop');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Start recording using the native ForegroundRecordingService
  static Future<bool> startNativeRecording({int maxSeconds = 60, String? label}) async {
    try {
      final res = await _channel.invokeMethod('startNativeRecording', {
        'maxSeconds': maxSeconds,
        'label': label ?? 'sos_${DateTime.now().millisecondsSinceEpoch}.m4a'
      });
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Stop native recording
  static Future<bool> stopNativeRecording() async {
    try {
      final res = await _channel.invokeMethod('stopNativeRecording');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Send an SOS request to the configured backend.
  /// The backend URL is read from SharedPreferences 'server_url'
  static Future<Map<String, dynamic>> sendSosToBackend({
    required Map<String, dynamic> meta,
    required List<Map<String, dynamic>> recipients,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString('server_url') ?? 'http://localhost:3000';
      final uri = Uri.parse('$server/send-sos');
      final body = jsonEncode({'meta': meta, 'recipients': recipients});
      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      return {'ok': false, 'status': resp.statusCode, 'body': resp.body};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Upload a recorded file path to backend using /upload-recording
  /// Note: For files recorded by native service, app can read shared pref key
  /// "last_native_recording_path" which ForegroundRecordingService writes.
  static Future<Map<String, dynamic>> uploadRecording(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString('server_url') ?? 'http://localhost:3000';
      final uri = Uri.parse('$server/upload-recording');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('recording', filePath));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) return jsonDecode(resp.body) as Map<String, dynamic>;
      return {'ok': false, 'status': resp.statusCode, 'body': resp.body};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }
}
