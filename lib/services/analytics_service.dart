import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  static Future<void> init() async {
    try {
      await analytics.logAppOpen();
      await analytics.setAnalyticsCollectionEnabled(true);
      debugPrint('✓ AnalyticsService initialized');
    } catch (e) {
      debugPrint('⚠️ AnalyticsService init failed: $e');
    }
  }

  static Future<void> setUserId(String? userId) async {
    try {
      await analytics.setUserId(id: userId);
      debugPrint('✓ AnalyticsService user id set: $userId');
    } catch (e) {
      debugPrint('⚠️ AnalyticsService setUserId failed: $e');
    }
  }

  static Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await analytics.logEvent(
        name: name,
        parameters: parameters?.cast<String, Object>(),
      );
      debugPrint('✓ AnalyticsService event logged: $name');
    } catch (e) {
      debugPrint('⚠️ AnalyticsService logEvent failed: $e');
    }
  }

  static Future<void> logScreenView({required String screenName, String? screenClass}) async {
    try {
      await analytics.logScreenView(screenName: screenName, screenClass: screenClass);
      debugPrint('✓ AnalyticsService screen view: $screenName');
    } catch (e) {
      debugPrint('⚠️ AnalyticsService logScreenView failed: $e');
    }
  }
}
