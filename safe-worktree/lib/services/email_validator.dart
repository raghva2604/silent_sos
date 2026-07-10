import 'package:flutter/foundation.dart';

/// Email validation service: regex check + format validation
class EmailValidator {
  /// Simple email regex pattern
  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  /// Validate email format using regex
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    email = email.trim().toLowerCase();

    // Check basic format
    if (!email.contains('@')) return false;
    if (email.startsWith('@') || email.endsWith('@')) return false;
    if (email.contains(' ')) return false;

    // Check length constraints
    if (email.length > 254) return false; // RFC 5321
    final parts = email.split('@');
    if (parts[0].length > 64) return false; // Local part max 64 chars

    // Regex validation
    try {
      return _emailRegex.hasMatch(email);
    } catch (e) {
      debugPrint('Regex error: $e');
      return false;
    }
  }

  /// Check for common disposable email domains (optional for production)
  static bool isDisposableEmail(String email) {
    final disposableDomains = [
      'tempmail.com',
      'throwaway.email',
      '10minutemail.com',
      'guerrillamail.com',
      'mailinator.com',
    ];

    final domain = email.split('@').last.toLowerCase();
    return disposableDomains.contains(domain);
  }

  /// Validate phone number (E.164 format: +country code + digits)
  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    phone = phone.replaceAll(RegExp(r'\D'), ''); // Remove non-digits

    // Check if it's 10-15 digits (E.164 standard)
    return phone.length >= 10 && phone.length <= 15;
  }

  /// Validate contact name (non-empty, reasonable length)
  static bool isValidContactName(String name) {
    if (name.isEmpty || name.length > 100) return false;
    return RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(name);
  }
}

/// Batch validate multiple emails and contacts
class BatchValidator {
  /// Validate list of emails
  static Map<String, bool> validateEmails(List<String> emails) {
    final results = <String, bool>{};
    for (final email in emails) {
      results[email] = EmailValidator.isValidEmail(email);
    }
    return results;
  }

  /// Validate list of phones
  static Map<String, bool> validatePhones(List<String> phones) {
    final results = <String, bool>{};
    for (final phone in phones) {
      results[phone] = EmailValidator.isValidPhone(phone);
    }
    return results;
  }

  /// Count valid emails in list
  static int countValidEmails(List<String> emails) {
    return emails.where((e) => EmailValidator.isValidEmail(e)).length;
  }

  /// Count valid phones in list
  static int countValidPhones(List<String> phones) {
    return phones.where((p) => EmailValidator.isValidPhone(p)).length;
  }
}
