import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import '../config/api_config.dart';

class SilentSOSApi {
  // 🔐 Your Lambda Function URL
  static const String lambdaUrl =
      "https://yc5qjfslrvzcyxjo4rbtfxuun40vdivu.lambda-url.ap-south-1.on.aws/";

  // Use centralized secret from ApiConfig

  static Future<String?> getSecureVideoLink(String videoKey) async {
    try {
      final response = await http.post(
        Uri.parse(lambdaUrl),
        headers: ApiConfig.defaultHeaders(),
        body: jsonEncode({
          "videoKey": videoKey,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["downloadUrl"];
      } else {
        debugPrint("Error ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Exception: $e");
      return null;
    }
  }
}
