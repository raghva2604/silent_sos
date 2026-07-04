import 'package:flutter/foundation.dart';

/// Global recording status service
/// Used to notify UI when video recording starts/stops
class RecordingStatusService extends ChangeNotifier {
  static final RecordingStatusService _instance =
      RecordingStatusService._internal();

  bool _isRecording = false;

  factory RecordingStatusService() {
    return _instance;
  }

  RecordingStatusService._internal();

  bool get isRecording => _isRecording;

  /// Notify when video recording starts
  void startRecording() {
    _isRecording = true;
    debugPrint('📹 Recording started - UI notified');
    notifyListeners();
  }

  /// Notify when video recording stops
  void stopRecording() {
    _isRecording = false;
    debugPrint('📹 Recording stopped - UI notified');
    notifyListeners();
  }
}
