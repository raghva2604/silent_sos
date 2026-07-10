import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

class StorageService {
  /// Upload [file] to Firebase Storage under [remotePath] and return the
  /// public download URL. Throws on failure.
  static Future<String> uploadFile(File file, String remotePath) async {
    final ref = FirebaseStorage.instance.ref(remotePath);

    // Use putFile with default metadata. Exponential retry/policy can be added.
    final uploadTask = ref.putFile(file);

    // Wait for completion
    final snapshot = await uploadTask.whenComplete(() {});

    if (snapshot.state == TaskState.success) {
      final url = await ref.getDownloadURL();
      return url;
    }

    throw Exception('Upload failed with state: ${snapshot.state}');
  }

  /// Request a signed upload URL from backend for [sessionId] and [filename].
  /// Backend should return JSON { uploadUrl, videoKey, publicUrl }
  static Future<Map<String, dynamic>> getSignedUploadUrl(
      String sessionId, String filename) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/generate-upload-url');

    // Get Firebase ID token for authentication
    String? idToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        idToken = await user.getIdToken();
      }
    } catch (e) {
      // Ignore auth errors, proceed without token
    }

    final headers = ApiConfig.defaultHeaders();
    if (idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    final resp = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'sessionId': sessionId,
            'filename': filename,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception(
        'Signed URL request failed: ${resp.statusCode} ${resp.body}');
  }

  /// Upload file bytes to a pre-signed URL (S3/Cloudfront) using HTTP PUT.
  /// Returns the public URL (if provided) or the upload target URL.
  static Future<String> uploadFileWithSignedUrl(File file, String uploadUrl,
      {Map<String, String>? headers}) async {
    final bytes = await file.readAsBytes();
    final uri = Uri.parse(uploadUrl);

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final resp = await http
            .put(uri,
                headers: headers ?? {'Content-Type': 'video/mp4'}, body: bytes)
            .timeout(Duration(seconds: 60 + attempt * 15));

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          return uploadUrl;
        }

        if (attempt == 3) {
          throw Exception(
              'Signed upload failed: ${resp.statusCode} ${resp.body}');
        }
      } catch (e) {
        if (attempt == 3) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    throw Exception('Signed upload failed after retries');
  }

  /// Request a signed download URL from backend for an existing [videoKey].
  /// Returns JSON { downloadUrl, expiresIn, expiresAt }
  /// expiresIn: duration in seconds (default 24 hours = 86400 seconds)
  /// expiresAt: ISO 8601 timestamp when URL expires
  static Future<Map<String, dynamic>> getSignedDownloadUrl(
      String videoKey) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/generate-download-url');

    // Get Firebase ID token for authentication
    String? idToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        idToken = await user.getIdToken();
      }
    } catch (e) {
      // Ignore auth errors, proceed without token
    }

    final headers = ApiConfig.defaultHeaders();
    if (idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    final resp = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({'videoKey': videoKey}),
        )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception(
        'Download URL request failed: ${resp.statusCode} ${resp.body}');
  }
}
