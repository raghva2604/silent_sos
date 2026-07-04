import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendService {
  static const String baseUrl = "http://13.203.67.82:3000";

  static Future<void> sendSOS({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/sos"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "latitude": latitude,
          "longitude": longitude,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ SOS sent to backend");
        print(response.body);
      } else {
        print("❌ Backend error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Failed to connect backend: $e");
    }
  }
}