import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistent queue for unsent SOS messages.
/// Stores a JSON list under the key `unsent_sos_queue_v2`.
class OfflineQueue {
  static const String _key = 'unsent_sos_queue_v2';

  static Future<List<Map<String, dynamic>>> _readAll() async {
    final p = await SharedPreferences.getInstance();
    final items = p.getStringList(_key) ?? <String>[];
    return items.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  static Future<void> _writeAll(List<Map<String, dynamic>> items) async {
    final p = await SharedPreferences.getInstance();
    final encoded = items.map((m) => jsonEncode(m)).toList();
    await p.setStringList(_key, encoded);
  }

  static Future<void> enqueue(String to, String body) async {
    final list = await _readAll();
    list.add({'to': to, 'body': body, 'ts': DateTime.now().toIso8601String()});
    await _writeAll(list);
  }

  static Future<List<Map<String, dynamic>>> all() async => await _readAll();

  static Future<void> removeFirstN(int n) async {
    final list = await _readAll();
    if (list.length <= n) {
      await _writeAll([]);
    } else {
      final remaining = list.sublist(n);
      await _writeAll(remaining);
    }
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
