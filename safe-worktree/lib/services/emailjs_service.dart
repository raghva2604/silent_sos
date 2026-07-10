import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailJSService {
  // ✅ YOUR REAL VALUES
  static const String serviceId = 'service_w9jvwty';
  static const String templateLocationId = 'template_utx3upt';
  static const String templateVideoId = 'template_j0ntp7p';
  static const String publicKey = 'rHcY8ZDEEmF0uuMu3'; // 👈 replace this

  // 📍 LOCATION EMAIL
  static Future<void> sendLocationEmail({
    required String toEmail,
    required String location,
    required String time,
    required String message,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateLocationId,
        'user_id': publicKey,
        'template_params': {
          'to_email': toEmail,
          'location': location,
          'time': time,
          'message': message,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          "EmailJS Location failed: status ${response.statusCode}, body: ${response.body}");
    }
    print("✅ EmailJS Location API response: ${response.statusCode}");
  }

  // 🎥 VIDEO EMAIL (front/back+location)
  static Future<void> sendVideoEmail({
    required String toEmail,
    required String frontVideo,
    required String backVideo,
    required String location,
    required String time,
    required String message,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateVideoId,
        'user_id': publicKey,
        'template_params': {
          'to_email': toEmail,
          'front_video': frontVideo,
          'back_video': backVideo,
          'location': location,
          'time': time,
          'message': message,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          "EmailJS Video failed: status ${response.statusCode}, body: ${response.body}");
    }
    print("✅ EmailJS Video API response: ${response.statusCode}");
  }
}
