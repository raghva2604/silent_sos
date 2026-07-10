import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Vibration level enum
enum VibrationLevel {
  low,
  medium,
  strong,
}

/// Vibration customization service
class VibrationService extends ChangeNotifier {
  static final VibrationService _instance = VibrationService._();

  factory VibrationService() => _instance;

  VibrationService._();

  int _intensity = 50; // 0-100 scale
  bool _enabled = true;
  VibrationLevel _level = VibrationLevel.medium;

  static const int _minDurationMs = 10;
  static const int _maxDurationMs = 500;

  /// Initialize vibration service and load saved settings
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _intensity = prefs.getInt('vibration_intensity') ?? 50;
    _enabled = prefs.getBool('vibration_enabled') ?? true;

    // Check if device supports vibration
    final canVibrate = await Vibration.hasVibrator();
    if (canVibrate == false) {
      debugPrint('Device does not support vibration');
      _enabled = false;
    }
  }

  /// Get current vibration intensity (0-100)
  int get intensity => _intensity;

  /// Get vibration enabled status
  bool get enabled => _enabled;

  /// Set vibration intensity (0-100) and save
  Future<void> setIntensity(int value) async {
    if (value < 0 || value > 100) return;
    _intensity = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vibration_intensity', _intensity);
    notifyListeners();
  }

  /// Toggle vibration on/off
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', _enabled);
    notifyListeners();
  }

  /// Get vibration level
  VibrationLevel get level => _level;

  /// Set vibration level (low/medium/strong)
  Future<void> setLevel(VibrationLevel level) async {
    _level = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vibration_level', level.name);
    notifyListeners();
  }

  /// Load vibration level from preferences
  Future<void> loadLevel() async {
    final prefs = await SharedPreferences.getInstance();
    final levelName = prefs.getString('vibration_level') ?? 'medium';
    _level = VibrationLevel.values.firstWhere(
      (e) => e.name == levelName,
      orElse: () => VibrationLevel.medium,
    );
  }

  /// Get vibration pattern based on level (for notifications)
  static Int64List getNotificationPattern(VibrationLevel level) {
    switch (level) {
      case VibrationLevel.low:
        return Int64List.fromList([0, 300, 700, 300]);
      case VibrationLevel.medium:
        return Int64List.fromList([0, 500, 400, 500]);
      case VibrationLevel.strong:
        return Int64List.fromList([0, 800, 300, 800, 300, 800]);
    }
  }

  /// Calculate vibration duration based on intensity
  int _getDurationMs(int intensityLevel) {
    // Map intensity (0-100) to duration (10-500ms)
    return ((intensityLevel / 100) * (_maxDurationMs - _minDurationMs))
            .toInt() +
        _minDurationMs;
  }

  /// Simple vibration feedback
  Future<void> vibrate({int duration = 100}) async {
    if (!_enabled) return;
    try {
      final scaledDuration = (duration * (_intensity / 100)).toInt();
      await Vibration.vibrate(duration: scaledDuration);
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }

  /// SOS vibration pattern: 3 short bursts
  Future<void> vibrateSOSPattern() async {
    if (!_enabled) return;
    try {
      final duration = _getDurationMs(_intensity);
      // SOS pattern: dot-dot-dot (short) dash-dash-dash (long) dot-dot-dot (short)
      await Vibration.vibrate(duration: duration ~/ 2); // dot
      await Future.delayed(Duration(milliseconds: duration ~/ 4));
      await Vibration.vibrate(duration: duration ~/ 2); // dot
      await Future.delayed(Duration(milliseconds: duration ~/ 4));
      await Vibration.vibrate(duration: duration ~/ 2); // dot
      await Future.delayed(Duration(milliseconds: duration ~/ 2));

      await Vibration.vibrate(duration: duration); // dash
      await Future.delayed(Duration(milliseconds: duration ~/ 4));
      await Vibration.vibrate(duration: duration); // dash
      await Future.delayed(Duration(milliseconds: duration ~/ 4));
      await Vibration.vibrate(duration: duration); // dash
    } catch (e) {
      debugPrint('SOS vibration pattern error: $e');
    }
  }

  /// Fall detection vibration pattern: rapid pulses
  Future<void> vibrateFallAlertPattern() async {
    if (!_enabled) return;
    try {
      final duration = _getDurationMs(_intensity);
      for (int i = 0; i < 5; i++) {
        await Vibration.vibrate(duration: duration ~/ 3);
        await Future.delayed(Duration(milliseconds: duration ~/ 6));
      }
    } catch (e) {
      debugPrint('Fall alert vibration pattern error: $e');
    }
  }

  /// Preview vibration (for settings)
  Future<void> previewVibration() async {
    if (!_enabled) return;
    try {
      final duration = _getDurationMs(_intensity);
      await Vibration.vibrate(duration: duration);
    } catch (e) {
      debugPrint('Preview vibration error: $e');
    }
  }

  /// Cancel any ongoing vibration
  Future<void> cancel() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('Cancel vibration error: $e');
    }
  }
}
