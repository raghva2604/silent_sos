import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class Api {
  final String baseUrl;
  Api(this.baseUrl);

  Future<Map<String, dynamic>> transcribeAndAnalyzeMultipart({
    required File audioFile,
    String langHint = 'auto',
    File? imageFile,
  }) async {
    final uri = Uri.parse('$baseUrl/transcribe_and_analyze');
    final req = http.MultipartRequest('POST', uri);
    req.fields['lang_hint'] = langHint;
    req.fields['device_offline'] = 'false';
    req.files.add(await http.MultipartFile.fromPath('audio', audioFile.path, filename: 'req_audio.wav'));
    if (imageFile != null) {
      req.files.add(await http.MultipartFile.fromPath('image', imageFile.path, filename: 'injury.jpg'));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) return json.decode(res.body) as Map<String, dynamic>;
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }

  Future<Map<String, dynamic>> transcribeAndAnalyzeBase64({
    required File audioFile,
    String langHint = 'auto',
  }) async {
    final b = base64Encode(await audioFile.readAsBytes());
    final uri = Uri.parse('$baseUrl/transcribe_and_analyze');
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'audio_b64': b, 'lang_hint': langHint, 'device_offline': false}));
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception('API error ${resp.statusCode}: ${resp.body}');
  }
}
