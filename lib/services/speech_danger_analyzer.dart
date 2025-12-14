import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Analyzes audio chunk for danger speech using the FastAPI /danger_speech endpoint.
/// Returns danger score (0.0 to 1.0) and detected danger words.
Future<Map<String, dynamic>> analyzeSpeechDanger({
  required Uint8List audioData,
  required String serverUrl,
}) async {
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$serverUrl/danger_speech'),
    );
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioData,
        filename: 'audio_chunk.wav',
      ),
    );
    
    var response = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Danger speech analysis timeout');
      },
    );
    
    if (response.statusCode == 200) {
      final body = jsonDecode(await response.stream.bytesToString());
      return {
        'text': body['text'] ?? '',
        'danger_score': (body['danger_score'] ?? 0.0).toDouble(),
        'danger_words': List<String>.from(body['danger_words'] ?? []),
      };
    } else {
      return {
        'text': '',
        'danger_score': 0.0,
        'danger_words': [],
        'error': 'Server returned ${response.statusCode}',
      };
    }
  } catch (e) {
    return {
      'text': '',
      'danger_score': 0.0,
      'danger_words': [],
      'error': e.toString(),
    };
  }
}

/// Check if danger score is high enough to trigger SOS.
/// Default threshold is 0.5 (2+ danger words detected).
bool shouldTriggerSOSFromSpeech(double dangerScore, {double threshold = 0.5}) {
  return dangerScore >= threshold;
}
