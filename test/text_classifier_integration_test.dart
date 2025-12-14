import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silent_sos/services/text_classifier.dart';

void main() {
  test('TextClassifier posts text and parses response', () async {
    final mock = MockClient((request) async {
      expect(request.method, equals('POST'));
      expect(request.url.path, contains('/classify_text'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.containsKey('text'), isTrue);
      // return a deterministic fake response
      return http.Response(jsonEncode({'label': 'injury', 'score': 0.88}), 200, headers: {
        'content-type': 'application/json'
      });
    });

    final classifier = TextClassifier(backendBase: 'http://mockserver:8000', client: mock);
    final out = await classifier.classify('Person is bleeding heavily from arm');
    expect(out['label'], equals('injury'));
    expect((out['score'] as num).toDouble(), closeTo(0.88, 1e-6));
  });
}
