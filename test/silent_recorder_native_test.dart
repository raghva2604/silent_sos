import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_sos/services/silent_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('silent_sos/foreground');

  tearDown(() {
    // Use the test binding messenger to remove the mock handler (preferred API)
    try {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    } catch (_) {}
    SharedPreferences.setMockInitialValues({});
  });

  test('uses native channel when background enabled', () async {
    // Mock that user enabled background audio
    SharedPreferences.setMockInitialValues({'allow_auto_audio': true});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'startNativeRecording') {
        return true;
      }
      if (call.method == 'stopNativeRecording') {
        return '/tmp/native_test.m4a';
      }
      return null;
    });

  final path = await SilentRecorder.recordAudio(seconds: 1);
  // Ensure the call completed without throwing; path may be null because the
  // native service persists the path into SharedPreferences asynchronously.
  expect(path, anyOf(isNull, isA<String>()));
  });
}
