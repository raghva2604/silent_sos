import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Upload Retry Service
/// Handles video upload with retry logic for reliability
class UploadRetryService {
  static const int _maxAttempts = 4;

  /// Upload video with retry on failure
  static Future<String?> uploadWithRetry(File video) async {
    int attempts = 0;
    while (attempts < _maxAttempts) {
      try {
        attempts++;
        print('📤 UploadRetryService: Attempt $attempts of $_maxAttempts');

        // Get upload URL from backend
        final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        final uploadData = await _getUploadUrl(sessionId);
        final uploadUrl = uploadData['uploadUrl'] as String;
        final videoKey = uploadData['videoKey'] as String;

        // Upload video
        await _uploadVideo(uploadUrl, video.path);

        // Generate video link (assuming backend provides it)
        final videoLink =
            '${ApiConfig.baseUrl}/videos/$videoKey'; // Placeholder

        print('✅ UploadRetryService: Upload successful on attempt $attempts');
        return videoLink;
      } catch (e) {
        print('⚠️ UploadRetryService: Attempt $attempts failed: $e');
        if (attempts >= _maxAttempts) {
          print('❌ UploadRetryService: All attempts failed');
          return null;
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return null;
  }

  /// Get upload URL from backend
  static Future<Map<String, dynamic>> _getUploadUrl(String sessionId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/sos-get-upload-url');
    final response = await http.post(
      url,
      headers: ApiConfig.defaultHeaders(),
      body: {'sessionId': sessionId},
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get upload URL: ${response.statusCode}');
    }
  }

  /// Upload video to S3
  static Future<void> _uploadVideo(String uploadUrl, String filePath) async {
    final file = File(filePath);
    final request = http.Request('PUT', Uri.parse(uploadUrl));
    request.bodyBytes = await file.readAsBytes();
    request.headers['Content-Type'] =
        'video/mp4'; // Adjust based on video format

    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  }
}
