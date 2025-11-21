import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:silent_sos/services/native_callbacks.dart' as native_callbacks;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('silent_sos/foreground');

  tearDown(() async {
    // clear mocks
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('nativeRecordingComplete method forwards to recordingCompleteStream', () async {
    final completer = Completer<Map<String, dynamic>>();

      // Ensure MethodChannel messages from the platform are forwarded into
      // the `recordingCompleteStream` for this test (main.dart normally
      // registers this handler during app startup).
      channel.setMethodCallHandler((call) async {
        if (call.method == 'nativeRecordingComplete') {
          try {
            final args = call.arguments;
            if (args is Map) {
              native_callbacks.addRecordingComplete(Map<String, dynamic>.from(args.cast<String, dynamic>()));
            }
          } catch (_) {}
        }
      });

      final sub = native_callbacks.recordingCompleteStream.listen((m) {
      try {
        completer.complete(m);
      } catch (_) {}
    });

    // Simulate native side invoking the MethodChannel to Dart
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('nativeRecordingComplete', {'path': '/tmp/test.m4a'})),
      (data) {},
    );

    final result = await completer.future.timeout(const Duration(seconds: 2));
    expect(result['path'], '/tmp/test.m4a');
    await sub.cancel();
  });
}
