import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static final StreamController<String?> _tapController = StreamController<String?>.broadcast();

  /// Stream of notification payloads tapped by the user.
  static Stream<String?> get onNotificationTap => _tapController.stream;

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings, onDidReceiveNotificationResponse: (response) async {
      // Emit payload so the app can show a dialog or navigate appropriately when a notification is tapped.
      try {
        _tapController.add(response.payload);
      } catch (_) {}
    });
  }

  static Future<void> showAlertNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'silent_sos_alerts',
      'SilentSOS Alerts',
      channelDescription: 'Notifications for detected falls and SOS confirmations',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    // Use a small payload so the app knows this is an alert from fall detection
    await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details, payload: 'fall_alert');
  }
}
