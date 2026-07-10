import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

/// Email sender using explicit mailto: URI scheme
/// Does NOT use generic share intents - avoids Android app hijacking
/// 
/// Usage:
/// ```dart
/// await EmailSender.openEmailWithMessage(
///   toEmails: ['recipient@example.com'],
///   subject: 'Emergency Alert',
///   body: 'This is an SOS alert message',
/// );
/// ```
class EmailSender {
  static const String tag = '📧 EmailSender';

  /// Open email app with message using explicit mailto: scheme
  /// Note: Video attachments NOT supported by mailto: (Android platform limitation)
  /// Video should be shared separately via explicit user action
  static Future<void> openEmailWithMessage({
    required List<String> toEmails,
    required String subject,
    required String body,
  }) async {
    try {
      if (toEmails.isEmpty) {
        throw ArgumentError('No email recipients provided');
      }

      // Validate all emails before attempting to open
      if (!isValidEmailList(toEmails)) {
        throw ArgumentError('One or more email addresses are invalid');
      }

      // Build mailto: URI with recipients, subject, and body
      // Platform limitation: mailto: does not support attachments
      final uri = Uri(
        scheme: 'mailto',
        path: toEmails.join(','),
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      debugPrint('$tag: Opening email client with mailto: scheme');
      debugPrint('$tag: Recipients: ${toEmails.join(', ')}');

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        debugPrint('$tag: ✅ Email intent opened successfully');
      } else {
        throw Exception('Failed to launch email client');
      }
    } catch (e) {
      debugPrint('$tag: ❌ Error opening email: $e');
      rethrow;
    }
  }

  /// Validate email list
  static bool isValidEmailList(List<String> emails) {
    if (emails.isEmpty) return false;
    return emails.every((email) => _isValidEmail(email));
  }

  /// Simple email validation (RFC 5322 simplified)
  static bool _isValidEmail(String email) {
    // Basic RFC 5322 simplified validation
    // Allows: alphanumeric, dots, hyphens, underscores, plus signs, and special chars
    final regex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );
    return regex.hasMatch(email.trim());
  }

  /// Share video as separate intentional step
  /// User explicitly chooses WhatsApp/Drive/Gmail/etc.
  static Future<bool> shareVideoFile(File videoFile) async {
    try {
      if (!videoFile.existsSync()) {
        throw Exception('Video file not found: ${videoFile.path}');
      }

      debugPrint('$tag: Initiating video share with user choice');

      // User explicitly chooses app - not hijacked by Android cache
      final result = await Share.shareXFiles(
        [XFile(videoFile.path)],
        subject: 'SOS Alert Video',
      );

      final success = result.status == ShareResultStatus.success;
      if (success) {
        debugPrint('$tag: ✅ Video shared successfully');
      } else if (result.status == ShareResultStatus.unavailable) {
        debugPrint('$tag: ⚠️ Share unavailable on this device');
      } else {
        debugPrint('$tag: ℹ️ Share cancelled by user');
      }

      return success;
    } catch (e) {
      debugPrint('$tag: ❌ Error sharing video: $e');
      rethrow;
    }
  }
}
