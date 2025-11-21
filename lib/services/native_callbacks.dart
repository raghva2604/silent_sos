import 'dart:async';

final StreamController<Map<String, dynamic>> _debugAutoSendController =
    StreamController<Map<String, dynamic>>.broadcast();

Stream<Map<String, dynamic>> get debugAutoSendStream =>
    _debugAutoSendController.stream;

void addDebugAutoSendResult(Map<String, dynamic> m) {
  try {
    _debugAutoSendController.add(m);
  } catch (_) {}
}

// Recording complete stream: emits { 'path': '<file>' }
final StreamController<Map<String, dynamic>> _recordingCompleteController =
    StreamController<Map<String, dynamic>>.broadcast();

Stream<Map<String, dynamic>> get recordingCompleteStream =>
    _recordingCompleteController.stream;

void addRecordingComplete(Map<String, dynamic> m) {
  try {
    _recordingCompleteController.add(m);
  } catch (_) {}
}

// Native diagnostic stream: raw JSON string payloads from native services
final StreamController<String> _nativeDiagnosticController = StreamController<String>.broadcast();

Stream<String> get nativeDiagnosticStream => _nativeDiagnosticController.stream;

void addNativeDiagnostic(String json) {
  try {
    _nativeDiagnosticController.add(json);
  } catch (_) {}
}
