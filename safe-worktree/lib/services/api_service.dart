import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  // choose base URL according to platform; use Config values so they are easy to change
  String get _baseUrl => ApiConfig.baseUrl;

  /// imageFile / audioFile are normal dart:io File on mobile/desktop.
  /// On web, imageFile should be an XFile or picked file that supports readAsBytes().
  Future<Map<String, dynamic>> analyze({
    dynamic imageFile, // File on io, XFile or platform-specific on web
    dynamic audioFile,
    String? text,
    String langHint = "auto",
    bool deviceOffline = false,
  }) async {
    final uri = Uri.parse("$_baseUrl/analyze");

    // --- Web path: send JSON with base64-encoded files ---
    if (kIsWeb) {
      // read bytes from web XFile or typed data object
      String? imageB64;
      String? audioB64;

      if (imageFile != null) {
        // imageFile is expected to have readAsBytes() on web (XFile or html File)
        final bytes = await imageFile.readAsBytes();
        imageB64 = base64Encode(bytes);
      }

      if (audioFile != null) {
        final bytes = await audioFile.readAsBytes();
        audioB64 = base64Encode(bytes);
      }

      final body = {
        'lang_hint': langHint,
        'device_offline': deviceOffline ? "true" : "false",
        'text': text ?? "",
        if (imageB64 != null) 'image_b64': imageB64,
        if (audioB64 != null) 'audio_b64': audioB64,
      };

      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        throw Exception('API error ${resp.statusCode}: ${resp.body}');
      }
    }

    // --- Non-web path: multipart/form-data upload using dart:io MultipartRequest ---
    final request = http.MultipartRequest('POST', uri);
    request.fields['lang_hint'] = langHint;
    request.fields['device_offline'] = deviceOffline ? "true" : "false";
    if (text != null && text.isNotEmpty) request.fields['text'] = text;

    if (imageFile != null) {
      final imgStream = http.ByteStream(imageFile.openRead());
      final imgLen = await imageFile.length();
      request.files.add(http.MultipartFile('image', imgStream, imgLen,
          filename: imageFile.path.split(Platform.pathSeparator).last));
    }

    if (audioFile != null) {
      final audStream = http.ByteStream(audioFile.openRead());
      final audLen = await audioFile.length();
      request.files.add(http.MultipartFile('audio', audStream, audLen,
          filename: audioFile.path.split(Platform.pathSeparator).last));
    }

    final streamedResp = await request.send();
    final respStr = await streamedResp.stream.bytesToString();
    if (streamedResp.statusCode >= 200 && streamedResp.statusCode < 300) {
      return jsonDecode(respStr) as Map<String, dynamic>;
    } else {
      throw Exception('API error ${streamedResp.statusCode}: $respStr');
    }
  }

  /// Calls the backend `/transcribe_and_analyze` endpoint. Mirrors `analyze` but
  /// targets the transcription+analysis route. Returns decoded JSON map.
  Future<Map<String, dynamic>> transcribeAndAnalyze({
    dynamic imageFile,
    dynamic audioFile,
    String? text,
    String langHint = "auto",
    bool deviceOffline = false,
  }) async {
    final uri = Uri.parse("$_baseUrl/transcribe_and_analyze");

    if (kIsWeb) {
      String? imageB64;
      String? audioB64;

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        imageB64 = base64Encode(bytes);
      }
      if (audioFile != null) {
        final bytes = await audioFile.readAsBytes();
        audioB64 = base64Encode(bytes);
      }

      final body = {
        'lang_hint': langHint,
        'device_offline': deviceOffline ? "true" : "false",
        'text': text ?? "",
        if (imageB64 != null) 'image_b64': imageB64,
        if (audioB64 != null) 'audio_b64': audioB64,
      };

      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        throw Exception('API error ${resp.statusCode}: ${resp.body}');
      }
    }

    // non-web: multipart
    final request = http.MultipartRequest('POST', uri);
    request.fields['lang_hint'] = langHint;
    request.fields['device_offline'] = deviceOffline ? "true" : "false";
    if (text != null && text.isNotEmpty) request.fields['text'] = text;

    if (imageFile != null) {
      final imgStream = http.ByteStream(imageFile.openRead());
      final imgLen = await imageFile.length();
      request.files.add(http.MultipartFile('image', imgStream, imgLen,
          filename: imageFile.path.split(Platform.pathSeparator).last));
    }

    if (audioFile != null) {
      final audStream = http.ByteStream(audioFile.openRead());
      final audLen = await audioFile.length();
      request.files.add(http.MultipartFile('audio', audStream, audLen,
          filename: audioFile.path.split(Platform.pathSeparator).last));
    }

    final streamedResp = await request.send();
    final respStr = await streamedResp.stream.bytesToString();
    if (streamedResp.statusCode >= 200 && streamedResp.statusCode < 300) {
      return jsonDecode(respStr) as Map<String, dynamic>;
    } else {
      throw Exception('API error ${streamedResp.statusCode}: $respStr');
    }
  }
}
