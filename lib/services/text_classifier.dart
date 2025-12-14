// Lightweight backend-backed text classifier wrapper.
// Replaces on-device TFLite call with a safe backend HTTP call.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

/// Simple wrapper that sends text to the inference backend.
/// Backend should expose /classify_text which returns JSON: { "label": "...", "score": 0.93 }
class TextClassifier {
  final String backendBase;
  final Client httpClient;

  /// Provide an optional `http.Client` for testing/injection. If none
  /// provided, a default `http.Client()` will be used.
  TextClassifier({required this.backendBase, Client? client}) : httpClient = client ?? http.Client();

  /// classify text (returns map or throws)
  Future<Map<String, dynamic>> classify(String text) async {
    final url = Uri.parse('$backendBase/classify_text');
    final r = await httpClient.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}));
    if (r.statusCode != 200) {
      throw Exception('classify_text failed ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
