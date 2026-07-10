import 'package:geolocator/geolocator.dart';

/// Clean SOS message builder with location integration
class SosMessageBuilder {
  /// Build complete SOS message with location (ACCURATE GPS)
  static Future<String> buildWithLocation({
    Position? position,
    String source = 'manual', // 'manual' | 'voice' | 'fall'
  }) async {
    String locationText = 'Unknown location';

    if (position != null) {
      locationText =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    } else {
      // Try to get ACCURATE location (best for navigation = GPS fix)
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 10),
          ),
        );
        locationText =
            'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
      } catch (e) {
        // If GPS times out, try high accuracy (network-based)
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
          locationText =
              'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
        } catch (_) {
          // Use default if all location attempts fail
        }
      }
    }

    return build(locationText: locationText, source: source);
  }

  /// Build SOS message with provided location (lat,lng format)
  static String build({
    String locationText =
        'https://www.google.com/maps/search/?api=1&query=emergency',
    String source = 'manual', // 'manual' | 'voice' | 'fall'
  }) {
    return '''🚨 EMERGENCY ALERT 🚨

I need immediate help.
Trigger source: $source

📍 Location:
$locationText

🎥 Safety videos have been recorded.
Please check immediately.

Sent via Silent SOS''';
  }
}
