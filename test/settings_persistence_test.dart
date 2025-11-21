import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Settings persist and read correctly', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('native_auto_send', true);
    await prefs.setBool('force_fullscreen_on_detection', true);
    await prefs.setString('voice_triggers', 'assist,help me');

    final prefs2 = await SharedPreferences.getInstance();
    expect(prefs2.getBool('native_auto_send'), isTrue);
    expect(prefs2.getBool('force_fullscreen_on_detection'), isTrue);
    expect(prefs2.getString('voice_triggers'), 'assist,help me');
  });
}
