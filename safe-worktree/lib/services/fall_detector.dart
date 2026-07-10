import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../sos/sos_controller.dart';
import 'sos_service.dart';

typedef FallCallback = void Function();

class FallDetector {
  static const String _prefsThresholdKey = 'fall_threshold';
  static const String _prefsSensitivityKey = 'fall_sensitivity';

  bool isFreeFall = false;
  bool impactDetected = false;

  DateTime? freeFallTime;
  DateTime? impactTime;
  DateTime? _lastFallTrigger;

  double _impactThresholdG = 12.0;
  double _freeFallThresholdG = 0.7;
  double _stillnessThresholdG = 1.3;
  int _freeFallWindowMs = 1500;
  int _impactHoldMs = 1500;
  int _cooldownTimeMs = 30000;

  Function()? onFallDetected;

  StreamSubscription? _accelSub;
  bool _started = false;

  // Singleton manager for app-wide fall detection
  static FallDetector? _instance;

  static Future<void> start() async {
    _instance ??= FallDetector();
    _instance!.onFallDetected = () async {
      final ctx = SOSservice.navigatorKey.currentState?.context;
      if (ctx != null && ctx.mounted) {
        await SosController.triggerSOS(context: ctx, source: 'fall');
      } else {
        debugPrint('⚠️ Fall detected with no UI context - sending background SOS');
        await SOSservice.sendSOSAlertBackground(
          selectedContacts: [],
          videoPath: null,
        );
      }
    };

    if (_instance!._started) {
      debugPrint('⚠️ FallDetector already running; ignoring start request');
      return;
    }
    await _instance!._loadSettings();
    await _instance!._start();
  }

  static Future<void> stop() async {
    _instance?._stop();
  }

  static Future<void> setThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsThresholdKey, value);
    _instance?._updateThreshold(value);
    debugPrint('FallDetector: threshold set to ${value.toStringAsFixed(1)} g');
  }

  static Future<void> setSensitivity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = value.clamp(1.0, 100.0);
    await prefs.setDouble(_prefsSensitivityKey, normalized);
    _instance?._updateSensitivity(normalized);
    debugPrint('FallDetector: sensitivity set to ${normalized.toStringAsFixed(1)}');
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedThreshold = prefs.getDouble(_prefsThresholdKey) ?? 12.0;
    _updateThreshold(storedThreshold);
    final storedSensitivity = prefs.getDouble(_prefsSensitivityKey) ?? 100.0;
    _updateSensitivity(storedSensitivity);
    debugPrint('FallDetector: loaded threshold=${_impactThresholdG.toStringAsFixed(1)} g, sensitivity=${storedSensitivity.toStringAsFixed(1)}');
  }

  void _updateThreshold(double g) {
    _impactThresholdG = g.clamp(6.0, 20.0);
    _freeFallThresholdG = max(0.5, _impactThresholdG * 0.08);
    _stillnessThresholdG = max(1.0, _impactThresholdG * 0.12);
  }

  void _updateSensitivity(double value) {
    final normalized = value.clamp(1.0, 100.0);
    final factor = 1.0 + (100.0 - normalized) * 0.008;
    _freeFallWindowMs = (1500 * factor).round();
    _impactHoldMs = (1500 * factor).round();
    _cooldownTimeMs = (30000 * factor).round();
  }

  double get _impactThresholdMs2 => _impactThresholdG * 9.81;
  double get _freeFallThresholdMs2 => _freeFallThresholdG * 9.81;
  double get _stillnessThresholdMs2 => _stillnessThresholdG * 9.81;

  Future<void> _start() async {
    if (_started) {
      debugPrint('⚠️ FallDetector._start(): already started');
      return;
    }
    _startListening();
    _started = true;
    debugPrint('✅ FallDetector._start(): started successfully');
  }

  void _stop() {
    _accelSub?.cancel();
    _accelSub = null;
    _started = false;
    debugPrint('✅ FallDetector._stop(): stopped');
  }

  void _startListening() {
    _accelSub = accelerometerEventStream().listen((event) {
      detect(event.x, event.y, event.z);
    });
  }

  /// Fall detection logic tuned for accelerometer magnitude in m/s².
  /// Uses free-fall + impact + stillness confirmation to reduce false alarms.
  void detect(double x, double y, double z) {
    final now = DateTime.now();
    final magnitude = sqrt(x * x + y * y + z * z);

    if (_lastFallTrigger != null &&
        now.difference(_lastFallTrigger!).inMilliseconds < _cooldownTimeMs) {
      return;
    }

    if (!isFreeFall && magnitude < _freeFallThresholdMs2) {
      isFreeFall = true;
      freeFallTime = now;
      debugPrint('🔻 FallDetector: free-fall detected (${magnitude.toStringAsFixed(1)} m/s²)');
      return;
    }

    if (isFreeFall && !impactDetected && magnitude > _impactThresholdMs2) {
      impactDetected = true;
      impactTime = now;
      debugPrint('💥 FallDetector: impact detected (${magnitude.toStringAsFixed(1)} m/s²)');
      return;
    }

    if (isFreeFall && freeFallTime != null) {
      final fallAge = now.difference(freeFallTime!).inMilliseconds;
      if (fallAge > _freeFallWindowMs && !impactDetected) {
        debugPrint('⚠️ FallDetector: free-fall timed out after $fallAge ms, resetting');
        _reset();
        return;
      }
    }

    if (impactDetected && impactTime != null) {
      final impactAge = now.difference(impactTime!).inMilliseconds;
      if (impactAge >= _impactHoldMs) {
        if (magnitude < _stillnessThresholdMs2) {
          debugPrint('🚨 FallDetector: confirmed fall after impact ($magnitude m/s²)');
          onFallDetected?.call();
          _lastFallTrigger = now;
          _reset();
          return;
        }

        debugPrint('⚠️ FallDetector: impact did not settle, resetting');
        _reset();
        return;
      }
    }

    if (!isFreeFall && !impactDetected && magnitude > _impactThresholdMs2 * 0.7) {
      _reset();
    }
  }

  void _reset() {
    isFreeFall = false;
    impactDetected = false;
    freeFallTime = null;
    impactTime = null;
  }

  Future<void> dispose() async {
    await _accelSub?.cancel();
  }
}
