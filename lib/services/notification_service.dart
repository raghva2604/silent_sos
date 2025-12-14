import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static final StreamController<String?> _tapController = StreamController<String?>.broadcast();
  static bool _initialized = false;

  /// Stream of notification payloads tapped by the user.
  static Stream<String?> get onNotificationTap => _tapController.stream;

  static Future<void> init() async {
    if (_initialized) return;
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        try {
          _tapController.add(response.payload);
        } catch (_) {}
      },
    );
    
    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Show standard alert notification
  static Future<void> showAlertNotification(String title, String body) async {
    if (!_initialized) await init();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'silent_sos_alerts',
      'SilentSOS Alerts',
      channelDescription: 'Notifications for detected falls and SOS confirmations',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'SilentSOS Alert',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: 'fall_alert',
    );
  }

  /// Show high-priority SOS emergency notification (displays over other apps)
  static Future<void> showSOSEmergencyNotification({
    required String title,
    required String body,
    required String contactsCount,
  }) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sos_emergency_channel',
      'SOS Emergency Alerts',
      channelDescription: 'High-priority emergency SOS alerts that display over other apps',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableLights: true,
      enableVibration: true,
      color: Color.fromARGB(255, 255, 0, 0),
      fullScreenIntent: true,
      styleInformation: DefaultStyleInformation(true, true),
      ticker: '🚨 SOS EMERGENCY 🚨',
      tag: 'sos_alert',
      groupKey: 'sos_group',
      setAsGroupSummary: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      0,
      title,
      body,
      details,
      payload: 'sos_emergency|$contactsCount',
    );

    debugPrint('🚨 SOS Emergency notification shown - $contactsCount contacts');
  }

  /// Show auto-fall detection alert with high priority
  static Future<void> showAutoFallDetectionNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'autofall_emergency_channel',
      'Auto-Fall Detection Alerts',
      channelDescription: 'High-priority auto-fall detection alerts',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableLights: true,
      enableVibration: true,
      color: Color.fromARGB(255, 255, 165, 0),
      fullScreenIntent: true,
      styleInformation: DefaultStyleInformation(true, true),
      ticker: '⚠️ FALL DETECTED ⚠️',
      tag: 'autofall_alert',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      1,
      title,
      body,
      details,
      payload: 'autofall_detected',
    );

    debugPrint('⚠️ Auto-Fall Detection notification shown');
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  /// Cancel specific notification
  static Future<void> cancel(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id);
  }
}
