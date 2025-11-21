import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_sos/services/voice_command_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('isTrigger matches default triggers', () async {
    final text = 'Help me please';
    final matched = await VoiceCommandService.isTrigger(text);
    expect(matched, isTrue);
  });

  test('isTrigger matches custom triggers from prefs', () async {
    SharedPreferences.setMockInitialValues({'voice_triggers': 'assist, mayday'});
    final matched1 = await VoiceCommandService.isTrigger('Can you assist me?');
    final matched2 = await VoiceCommandService.isTrigger('This is a mayday situation');
    expect(matched1, isTrue);
    expect(matched2, isTrue);
  });
}
