import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'email_validator.dart';
import 'aws_ses_service.dart';
import 'emailjs_service.dart';

class EmailService {
  String _backendUrl = '${ApiConfig.baseUrl}/sos-send-sos';

  void setBackendUrl(String url) {
    _backendUrl = url;
  }

  static Future<void> sendLocation({
    required String toEmail,
    required String location,
    required String time,
    required String message,
  }) async {
    try {
      await EmailJSService.sendLocationEmail(
        toEmail: toEmail,
        location: location,
        time: time,
        message: message,
      );
      print('✅ EmailJS Location email sent successfully to $toEmail');
    } catch (e) {
      print('⚠️ EmailJS location failed: $e, trying AWS SES fallback');
      try {
        await AwsSesService.sendLocation(toEmail, location, time, message);
        print('✅ AWS SES Location fallback succeeded for $toEmail');
      } catch (awsE) {
        print('❌ Both EmailJS and AWS SES location failed: $awsE');
        rethrow;
      }
    }
  }

  static Future<void> sendVideoEmail({
    required String toEmail,
    required String frontVideo,
    required String backVideo,
    required String location,
    required String time,
    required String message,
  }) async {
    try {
      await EmailJSService.sendVideoEmail(
        toEmail: toEmail,
        frontVideo: frontVideo,
        backVideo: backVideo,
        location: location,
        time: time,
        message: message,
      );
      print('✅ EmailJS Video email sent successfully to $toEmail');
    } catch (e) {
      print('⚠️ EmailJS video failed: $e, trying AWS SES fallback');
      try {
        final fallbackVideoLinks = <String>[];
        if (frontVideo.isNotEmpty) fallbackVideoLinks.add('Front: $frontVideo');
        if (backVideo.isNotEmpty) fallbackVideoLinks.add('Back: $backVideo');
        await AwsSesService.sendVideo(
          toEmail,
          fallbackVideoLinks.join('\n\n'),
          time,
          '$message\nLocation: $location',
        );
        print('✅ AWS SES Video fallback succeeded for $toEmail');
      } catch (awsE) {
        print('❌ Both EmailJS and AWS SES video failed: $awsE');
        rethrow;
      }
    }
  }

  static Future<void> sendVideo({
    required String toEmail,
    required List<String> videoLinks,
    required String time,
    required String message,
  }) async {
    // Backwards-compatible wrapper that targets sendVideoEmail.
    final frontVideo = videoLinks.isNotEmpty ? videoLinks[0] : '';
    final backVideo = videoLinks.length > 1 ? videoLinks[1] : '';
    await sendVideoEmail(
      toEmail: toEmail,
      frontVideo: frontVideo,
      backVideo: backVideo,
      location: '',
      time: time,
      message: message,
    );
  }

  Future<Map<String, dynamic>> sendEmergencyAlert({
    required List<String> recipients,
    required String userName,
    required String userLocation,
    required double latitude,
    required double longitude,
    String? videoPath,
    String? message,
  }) async {
    final validEmails =
        recipients.where((e) => EmailValidator.isValidEmail(e)).toList();

    if (validEmails.isEmpty) {
      return {
        'success': false,
        'error': 'No valid email addresses provided',
      };
    }

    final payload = {
      'sessionId': DateTime.now().millisecondsSinceEpoch.toString(),
      'latitude': latitude,
      'longitude': longitude,
      'emails': validEmails,
      'contacts': [],
      'message': message ?? '',
      'userName': userName,
      'userLocation': userLocation,
      'videoPath': videoPath ?? '',
    };

    try {
      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-app-secret': ApiConfig.appSecret,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'sentTo': validEmails,
          'count': validEmails.length,
        };
      } else {
        return {
          'success': false,
          'error': 'Backend status ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> sendInitialAlert({
    required List<String> recipients,
    required String sessionId,
    required double latitude,
    required double longitude,
    String? message,
  }) async {
    final validEmails =
        recipients.where((e) => EmailValidator.isValidEmail(e)).toList();
    if (validEmails.isEmpty) {
      return {'success': false, 'error': 'No valid emails'};
    }

    final payload = {
      'type': 'initial_alert',
      'sessionId': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'emails': validEmails,
      'message': message ?? '',
    };

    try {
      final resp = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-app-secret': ApiConfig.appSecret,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      return {
        'success': resp.statusCode == 200 || resp.statusCode == 201,
        'status': resp.statusCode,
        'body': resp.body,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> sendVideoFollowup({
    required List<String> recipients,
    required String sessionId,
    required List<String> videoUrls,
    required double latitude,
    required double longitude,
  }) async {
    final validEmails =
        recipients.where((e) => EmailValidator.isValidEmail(e)).toList();
    if (validEmails.isEmpty) {
      return {'success': false, 'error': 'No valid emails'};
    }

    final payload = {
      'type': 'video_followup',
      'sessionId': sessionId,
      'emails': validEmails,
      'videoUrls': videoUrls,
      'latitude': latitude,
      'longitude': longitude,
    };

    try {
      final resp = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-app-secret': ApiConfig.appSecret,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      return {
        'success': resp.statusCode == 200 || resp.statusCode == 201,
        'status': resp.statusCode,
        'body': resp.body,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<void> queueEmailForLater({
    required List<String> recipients,
    required String subject,
    required String body,
    String? videoPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('queued_emails') ?? [];
    final queueItem = jsonEncode({
      'recipients': recipients,
      'subject': subject,
      'body': body,
      'videoPath': videoPath,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await prefs.setStringList('queued_emails', [...existing, queueItem]);
  }

  Future<List<String>> _loadEmailRecipients() async {
    final prefs = await SharedPreferences.getInstance();
    final recipients = prefs.getStringList('sos_email_recipients');
    if (recipients != null && recipients.isNotEmpty) return recipients;

    final rawJson = prefs.getString('sos_recipients');
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((entry) => entry['email']?.toString() ?? '')
              .where((email) => email.isNotEmpty)
              .toList();
        }
      } catch (_) {
        // ignore
      }
    }

    return prefs.getStringList('emailRecipients') ?? [];
  }

  Future<bool> sendLocationEmail(String locationLink) async {
    final emails = await _loadEmailRecipients();
    if (emails.isEmpty) return false;

    final res = await sendEmergencyAlert(
      recipients: emails,
      userName: 'Emergency Alert',
      userLocation: locationLink,
      latitude: 0.0,
      longitude: 0.0,
      message: 'Live location: $locationLink',
    );
    return res['success'] == true;
  }

  Future<bool> sendVideoFollowupEmail(String videoLink) async {
    final emails = await _loadEmailRecipients();
    if (emails.isEmpty) return false;

    final res = await sendVideoFollowup(
      recipients: emails,
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      videoUrls: [videoLink],
      latitude: 0.0,
      longitude: 0.0,
    );
    return res['success'] == true;
  }

  Future<bool> verifyBackendConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
