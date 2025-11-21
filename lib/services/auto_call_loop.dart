import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

/// Minimal auto-call loop skeleton (MVP)
/// - Responsible for dialing numbers with retries and backoff
/// - Requires caller to check CALL_PHONE permission before use
class AutoCallLoop {
  /// Try calling [number] up to [maxRetries] times with exponential backoff.
  /// Returns true if the dial intent was launched at least once.
  static Future<bool> callWithRetries(String number, {int maxRetries = 3}) async {
    int attempt = 0;
    bool launched = false;
    while (attempt < maxRetries) {
      try {
        final Uri uri = Uri.parse('tel:$number');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          launched = true;
          break;
        }
      } catch (_) {}
      attempt++;
      // exponential backoff
      await Future.delayed(Duration(seconds: (2 << attempt)));
    }
    return launched;
  }
}
