import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSettings extends ChangeNotifier {
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Default values
  static const double defaultFallThreshold = 12.0;
  static const int defaultFallSensitivity = 100;
  static const int defaultSosTimer = 10;
  static const int defaultVibrationStrength = 140;
  static const bool defaultVoiceEnabled = true;
  static const bool defaultAutoSosEnabled = true;
  static const int defaultRecordDurationSeconds = 20;
  static const String defaultUploadSpeed = 'medium';

  // Settings
  late double _fallThreshold;
  late int _fallSensitivity;
  late int _sosCountdownSeconds;
  late int _vibrationStrength;
  late bool _voiceEnabled;
  late bool _autoSOSEnabled;
  late int _recordDurationSeconds;
  late String _uploadSpeed;

  // Getters
  bool get isInitialized => _isInitialized;
  double get fallThreshold => _fallThreshold;
  int get fallSensitivity => _fallSensitivity;
  int get sosCountdownSeconds => _sosCountdownSeconds;
  int get vibrationStrength => _vibrationStrength;
  bool get voiceEnabled => _voiceEnabled;
  bool get autoSOSEnabled => _autoSOSEnabled;
  int get recordDurationSeconds => _recordDurationSeconds;
  String get uploadSpeed => _uploadSpeed;

  // Initialize from SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _fallThreshold = _prefs.getDouble('fall_threshold') ?? defaultFallThreshold;
    _fallSensitivity =
        _prefs.getInt('fall_sensitivity') ?? defaultFallSensitivity;
    _sosCountdownSeconds = _prefs.getInt('sos_timer') ?? defaultSosTimer;
    _vibrationStrength =
        _prefs.getInt('vibration_strength') ?? defaultVibrationStrength;
    _voiceEnabled = _prefs.getBool('voice_enabled') ?? defaultVoiceEnabled;
    _autoSOSEnabled =
        _prefs.getBool('auto_sos_enabled') ?? defaultAutoSosEnabled;
    _recordDurationSeconds = _prefs.getInt('record_duration_seconds') ??
        defaultRecordDurationSeconds;
    _uploadSpeed = _prefs.getString('upload_speed') ?? defaultUploadSpeed;

    _isInitialized = true;
    notifyListeners();
  }

  // Setters - persist to SharedPreferences
  Future<void> setFallThreshold(double value) async {
    if (_fallThreshold != value) {
      _fallThreshold = value;
      await _prefs.setDouble('fall_threshold', value);
      notifyListeners();
    }
  }

  Future<void> setFallSensitivity(int value) async {
    if (_fallSensitivity != value) {
      _fallSensitivity = value;
      await _prefs.setInt('fall_sensitivity', value);
      notifyListeners();
    }
  }

  Future<void> setSOSCountdownSeconds(int value) async {
    if (_sosCountdownSeconds != value) {
      _sosCountdownSeconds = value;
      await _prefs.setInt('sos_timer', value);
      notifyListeners();
    }
  }

  Future<void> setVibrationStrength(int value) async {
    if (_vibrationStrength != value) {
      _vibrationStrength = value;
      await _prefs.setInt('vibration_strength', value);
      notifyListeners();
    }
  }

  Future<void> setVoiceEnabled(bool value) async {
    if (_voiceEnabled != value) {
      _voiceEnabled = value;
      await _prefs.setBool('voice_enabled', value);
      notifyListeners();
    }
  }

  Future<void> setAutoSOSEnabled(bool value) async {
    if (_autoSOSEnabled != value) {
      _autoSOSEnabled = value;
      await _prefs.setBool('auto_sos_enabled', value);
      notifyListeners();
    }
  }

  Future<void> setRecordDurationSeconds(int value) async {
    if (_recordDurationSeconds != value) {
      _recordDurationSeconds = value;
      await _prefs.setInt('record_duration_seconds', value);
      notifyListeners();
    }
  }

  Future<void> setUploadSpeed(String value) async {
    if (_uploadSpeed != value) {
      _uploadSpeed = value;
      await _prefs.setString('upload_speed', value);
      notifyListeners();
    }
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    _fallThreshold = defaultFallThreshold;
    _fallSensitivity = defaultFallSensitivity;
    _sosCountdownSeconds = defaultSosTimer;
    _vibrationStrength = defaultVibrationStrength;
    _voiceEnabled = defaultVoiceEnabled;
    _autoSOSEnabled = defaultAutoSosEnabled;
    _recordDurationSeconds = defaultRecordDurationSeconds;
    _uploadSpeed = defaultUploadSpeed;

    await _prefs.setDouble('fall_threshold', defaultFallThreshold);
    await _prefs.setInt('fall_sensitivity', defaultFallSensitivity);
    await _prefs.setInt('sos_timer', defaultSosTimer);
    await _prefs.setInt('vibration_strength', defaultVibrationStrength);
    await _prefs.setBool('voice_enabled', defaultVoiceEnabled);
    await _prefs.setBool('auto_sos_enabled', defaultAutoSosEnabled);
    await _prefs.setInt(
        'record_duration_seconds', defaultRecordDurationSeconds);
    await _prefs.setString('upload_speed', defaultUploadSpeed);

    notifyListeners();
  }
}
