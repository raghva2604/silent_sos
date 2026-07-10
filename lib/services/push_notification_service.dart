import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';
import 'analytics_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 [Background] FCM message received: ${message.messageId}');
  await AnalyticsService.logEvent('fcm_background_message', parameters: {
    'message_id': message.messageId ?? 'unknown',
  });
}

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _requestPermission();
      }

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _messaging.onTokenRefresh.listen((token) {
        debugPrint('🔁 FCM token refreshed: $token');
      });

      final token = await _messaging.getToken();
      debugPrint('✅ FCM token: $token');

      await _messaging.subscribeToTopic('silent_sos_all');
      debugPrint('✅ Subscribed to FCM topic: silent_sos_all');

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('⚠️ PushNotificationService.init failed: $e');
    }
  }

  static Future<void> registerNotificationHandlers() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('📩 FCM onMessage: ${message.messageId}');
      await NotificationService.showAlertNotification(
        message.notification?.title ?? 'Silent SOS',
        message.notification?.body ?? 'You have a new emergency update.',
      );
      await AnalyticsService.logEvent('fcm_message_received', parameters: {
        'message_id': message.messageId ?? 'unknown',
      });
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      debugPrint('📩 FCM onMessageOpenedApp: ${message.messageId}');
      await AnalyticsService.logEvent('fcm_message_opened', parameters: {
        'message_id': message.messageId ?? 'unknown',
      });
    });
  }

  static Future<void> _requestPermission() async {
    if (Platform.isIOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('🔐 iOS notification permission: $settings');
    }

    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      debugPrint('🔐 Android notification permission: $status');
    }
  }
}
