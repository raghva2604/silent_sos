import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'vibration_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final StreamController<String?> _tapController =
      StreamController<String?>.broadcast();
  static bool _initialized = false;
  static const String _sosChannelId = 'sos_countdown_channel';
  static const String _sosAlarmChannelId =
      'sos_alarm_channel'; // NEW: Alarm channel for beep
  static const int _sosNotificationId = 999;

  /// Stream of notification payloads tapped by the user.
  static Stream<String?> get onNotificationTap => _tapController.stream;

  static Future<void> init() async {
    if (_initialized) return;

    // Android 13+ requires POST_NOTIFICATIONS permission at runtime
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Dummy call to ensure plugin loaded
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.getActiveNotifications();
      }
    } catch (_) {}

    // Check if notification permission is granted (already requested in PermissionScreen)
    if (await _needsAndroidNotificationPermission()) {
      final granted = await Permission.notification.status;
      debugPrint('Notification permission status: $granted');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) async {
        try {
          _tapController.add(response.payload);
        } catch (_) {}
      },
    );

    _initialized = true;
    debugPrint('NotificationService initialized');

    // Create SOS countdown notification channel with vibration
    await _createSOSChannel();

    // NEW: Create alarm channel for beep sound
    await _createSOSAlarmChannel();
  }

  static Future<bool> _needsAndroidNotificationPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ is the only version that requires runtime notification opt‑in but
      // asking on earlier versions is harmless.
      return !(await Permission.notification.isGranted);
    }
    return false;
  }

  /// Create SOS countdown channel with vibration pattern
  static Future<void> _createSOSChannel(
      {VibrationLevel level = VibrationLevel.medium}) async {
    try {
      final pattern = VibrationService.getNotificationPattern(level);

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Delete old channel if exists
      await androidPlugin?.deleteNotificationChannel(channelId: _sosChannelId);

      // Create new channel with vibration pattern
      final channel = AndroidNotificationChannel(
        _sosChannelId,
        'SOS Countdown Alerts',
        description: 'Emergency SOS countdown notifications',
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern: pattern,
        enableLights: true,
        ledColor: const Color.fromARGB(255, 255, 0, 0),
      );

      await androidPlugin?.createNotificationChannel(channel);
      debugPrint('✓ SOS notification channel created with vibration pattern');
    } catch (e) {
      debugPrint('⚠️ Failed to create SOS channel: $e');
    }
  }

  /// NEW: Create alarm channel with sound for loud SOS beep
  static Future<void> _createSOSAlarmChannel() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Delete old channel if exists
      await androidPlugin?.deleteNotificationChannel(channelId: _sosAlarmChannelId);

      // Create alarm channel with system alarm sound
      final channel = AndroidNotificationChannel(
        _sosAlarmChannelId,
        'SOS Emergency Alarms',
        description: 'Critical emergency SOS countdown alerts with alarm sound',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List(4)..setAll(0, [0, 500, 200, 500]),
        enableLights: true,
        ledColor: const Color.fromARGB(255, 255, 0, 0),
      );

      await androidPlugin?.createNotificationChannel(channel);
      debugPrint(
          '✓ SOS Alarm notification channel created with system alarm sound');
    } catch (e) {
      debugPrint('⚠️ Failed to create alarm channel: $e');
    }
  }

  /// Update SOS channel vibration pattern based on user setting
  static Future<void> updateSOSVibrationPattern() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final levelName = prefs.getString('vibration_level') ?? 'medium';
      final level = VibrationLevel.values.firstWhere(
        (e) => e.name == levelName,
        orElse: () => VibrationLevel.medium,
      );
      await _createSOSChannel(level: level);
      debugPrint('✓ SOS channel vibration pattern updated');
    } catch (e) {
      debugPrint('⚠️ Failed to update SOS channel: $e');
    }
  }

  /// Show SOS countdown notification with vibration every second
  static Future<void> showSOSCountdownNotification(int secondsRemaining) async {
    if (!_initialized) await init();

    try {
      final NotificationDetails details = NotificationDetails(
          android: AndroidNotificationDetails(
        _sosChannelId,
        'SOS Countdown Alerts',
        importance: Importance.max,
        priority: Priority.max,
        onlyAlertOnce: false,
        ongoing: true,
        autoCancel: false,
        ticker: '🚨 SOS Alert - $secondsRemaining seconds',
        enableVibration: true,
      ));

      await _plugin.show(
        id: _sosNotificationId,
        title: '🚨 SOS Countdown',
        body: 'Sending alert in $secondsRemaining seconds...',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to show countdown notification: $e');
    }
  }

  /// NEW: Show SOS alarm beep notification every second (this forces audio through alarm channel)
  static Future<void> showSOSAlarmBeepNotification(int secondsRemaining) async {
    if (!_initialized) await init();

    try {
      final NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          _sosAlarmChannelId,
          'SOS Emergency Alarms',
          channelDescription:
              'Critical emergency SOS countdown alerts with alarm sound',
          importance: Importance.max,
          priority: Priority.max,
          onlyAlertOnce: false,
          ongoing: true,
          autoCancel: false,
          ticker: '🚨 SOS ALERT - $secondsRemaining seconds remaining',
          enableVibration: true,
          playSound: true,
        ),
      );

      await _plugin.show(
        id: _sosNotificationId,
        title: '🚨 SOS EMERGENCY 🚨',
        body: 'Sending help in $secondsRemaining seconds - STAY ALERT',
        notificationDetails: details,
      );
      debugPrint(
          '📢 SOS Alarm beep notification shown - $secondsRemaining sec remaining');
    } catch (e) {
      debugPrint('⚠️ Failed to show alarm beep notification: $e');
    }
  }

  /// Clear SOS countdown notification
  static Future<void> clearSOSCountdown() async {
    try {
      await _plugin.cancel(id: _sosNotificationId);
    } catch (e) {
      debugPrint('⚠️ Failed to clear countdown notification: $e');
    }
  }

  /// Show standard alert notification
  static Future<void> showAlertNotification(String title, String body) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'silent_sos_alerts',
      'SilentSOS Alerts',
      channelDescription:
          'Notifications for detected falls and SOS confirmations',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'SilentSOS Alert',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'sos_emergency_channel',
      'SOS Emergency Alerts',
      channelDescription:
          'High-priority emergency SOS alerts that display over other apps',
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
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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
      id: 1,
      title: title,
      body: body,
      notificationDetails: details,
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
    await _plugin.cancel(id: id);
  }
}
