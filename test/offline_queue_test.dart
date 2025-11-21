import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_sos/services/offline_queue.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enqueue and read all', () async {
    await OfflineQueue.clear();
    await OfflineQueue.enqueue('+111111111', 'test message');
    final all = await OfflineQueue.all();
    expect(all.length, 1);
    expect(all.first['to'], '+111111111');
    expect(all.first['body'], 'test message');

    await OfflineQueue.removeFirstN(1);
    final after = await OfflineQueue.all();
    expect(after.length, 0);
  });
}
