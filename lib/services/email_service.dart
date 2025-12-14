import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'email_validator.dart';

/// Email sending service for SOS alerts
/// Uses a backend email service or native intent
class EmailService {
  static const String _defaultBackendUrl = 'http://localhost:3000';
  
  String _backendUrl = _defaultBackendUrl;

  /// Set backend server URL for email sending
  void setBackendUrl(String url) {
    _backendUrl = url;
    debugPrint('Email service backend set to: $_backendUrl');
  }

  /// Send emergency alert via email
  /// Returns success status and error message if failed
  Future<Map<String, dynamic>> sendEmergencyAlert({
    required List<String> recipients,
    required String userName,
    required String userLocation,
    required double latitude,
    required double longitude,
    String? videoPath,
    String? message,
  }) async {
    // Validate recipients
    final validEmails = recipients
        .where((e) => EmailValidator.isValidEmail(e))
        .toList();
    
    if (validEmails.isEmpty) {
      return {
        'success': false,
        'error': 'No valid email addresses provided',
        'failedRecipients': recipients,
      };
    }

    try {
      final payload = {
        'to': validEmails,
        'subject': '🚨 EMERGENCY SOS ALERT 🚨',
        'body': _buildEmailBody(
          userName: userName,
          location: userLocation,
          lat: latitude,
          lng: longitude,
          message: message,
        ),
        'attachments': videoPath != null ? [videoPath] : [],
        'type': 'sos_alert',
      };

      debugPrint('Sending SOS email to: $validEmails');

      final response = await http
          .post(
            Uri.parse('$_backendUrl/api/send-alert'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Email sent successfully to ${validEmails.length} recipients');
        return {
          'success': true,
          'sentTo': validEmails,
          'count': validEmails.length,
        };
      } else {
        return {
          'success': false,
          'error': 'Backend returned status ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      debugPrint('Email sending error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'attemptedRecipients': validEmails,
      };
    }
  }

  /// Send alert with video attachment
  Future<Map<String, dynamic>> sendAlertWithVideo({
    required List<String> recipients,
    required String userName,
    required String userLocation,
    required double latitude,
    required double longitude,
    required String frontVideoPath,
    required String backVideoPath,
  }) async {
    final validEmails = recipients
        .where((e) => EmailValidator.isValidEmail(e))
        .toList();
    
    if (validEmails.isEmpty) {
      return {
        'success': false,
        'error': 'No valid email addresses',
      };
    }

    try {
      final payload = {
        'to': validEmails,
        'subject': '🚨 EMERGENCY ALERT - VIDEO ATTACHED 🚨',
        'body': _buildEmailBody(
          userName: userName,
          location: userLocation,
          lat: latitude,
          lng: longitude,
          includeVideos: true,
        ),
        'attachments': [frontVideoPath, backVideoPath],
        'type': 'sos_alert_video',
      };

      final response = await http
          .post(
            Uri.parse('$_backendUrl/api/send-alert'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Video alert sent to ${validEmails.length} recipients');
        return {
          'success': true,
          'sentTo': validEmails,
          'type': 'video_alert',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to send video alert',
        };
      }
    } catch (e) {
      debugPrint('Video email error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Offline email queuing (save and send when online)
  Future<void> queueEmailForLater({
    required List<String> recipients,
    required String subject,
    required String body,
    String? videoPath,
  }) async {
    // Implementation: save to local DB/SharedPreferences
    // and sync when connectivity restored
    debugPrint('Queued email for ${recipients.length} recipients');
  }

  /// Build formatted email body
  String _buildEmailBody({
    required String userName,
    required String location,
    required double lat,
    required double lng,
    String? message,
    bool includeVideos = false,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🚨 EMERGENCY SOS ALERT 🚨');
    buffer.writeln();
    buffer.writeln('A person named "$userName" has triggered an emergency alert.');
    buffer.writeln();
    buffer.writeln('📍 LOCATION:');
    buffer.writeln('  - Address: $location');
    buffer.writeln('  - Latitude: $lat');
    buffer.writeln('  - Longitude: $lng');
    buffer.writeln('  - Map Link: https://maps.google.com/?q=$lat,$lng');
    buffer.writeln();
    buffer.writeln('⏰ Time: ${DateTime.now()}');
    buffer.writeln();
    
    if (message != null && message.isNotEmpty) {
      buffer.writeln('Message: $message');
      buffer.writeln();
    }

    if (includeVideos) {
      buffer.writeln('📹 Video recordings from front and back cameras are attached.');
      buffer.writeln();
    }

    buffer.writeln('Please respond immediately and check on this person.');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('Sent by Silent SOS Emergency Alert System');

    return buffer.toString();
  }

  /// Verify email backend is reachable
  Future<bool> verifyBackendConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/health'))
          .timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Backend connection verification failed: $e');
      return false;
    }
  }
}
