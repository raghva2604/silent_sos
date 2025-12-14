import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silent_sos/services/hotword_integration.dart';

void main() {
  const channelName = 'silent_sos/hotword';
  final codec = StandardMethodCodec();

  TestWidgetsFlutterBinding.ensureInitialized();

  test('HotwordIntegration emits event on platform message', () async {
    HotwordIntegration.init();

    final received = <Map<String, dynamic>>[];
    final sub = HotwordIntegration.onHotwordDetected.listen((m) => received.add(m));

    // Simulate platform-side method call for hotword_detected
    final call = MethodCall('hotword_detected', {'phrase': 'help me'});
    final encoded = codec.encodeMethodCall(call);
    // Send platform message as if it came from native. `encoded` is already ByteData.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channelName,
      encoded,
      (ByteData? data) {},
    );

    // allow stream to process
    await Future.delayed(const Duration(milliseconds: 100));
    expect(received.length, greaterThanOrEqualTo(1));
    expect(received.first['phrase'], 'help me');

    await sub.cancel();
  });
}
