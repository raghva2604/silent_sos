import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'doctor_ai.dart';

/// Offline AI service: uses local TFLite models + rule engine (doctor_ai.dart)
/// Falls back to backend API when online
class OfflineAIService {
  static final OfflineAIService _instance = OfflineAIService._();

  factory OfflineAIService() => _instance;

  OfflineAIService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = true;

  /// Initialize connectivity monitoring
  Future<void> init() async {
    _checkConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      debugPrint('Network status: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');
    });
  }

  /// Check current network status
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      _isOnline = false;
    }
  }

  /// Offline AI analysis using local rule engine
  /// Input: symptoms, vitals (spo2, pulse, respRate, bp)
  /// Output: triage level (critical/warning/normal), actions, brief advice
  Map<String, dynamic> analyzeOffline(Map<String, dynamic> input) {
    try {
      final result = checkRedFlags(input);
      return {
        'success': true,
        'mode': 'offline',
        'triage': result['severity'],
        'brief': result['brief'],
        'reasons': result['reasons'],
        'actions': result['actions'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Offline AI error: $e');
      return {
        'success': false,
        'mode': 'offline',
        'error': e.toString(),
      };
    }
  }

  /// Hybrid analysis: try online first, fallback to offline
  Future<Map<String, dynamic>> analyzeHybrid(
    Map<String, dynamic> input, {
    Future<Map<String, dynamic>> Function()? onlineAnalyzer,
  }) async {
    if (_isOnline && onlineAnalyzer != null) {
      try {
        debugPrint('Using ONLINE AI analysis');
        final result = await onlineAnalyzer();
        return {
          ...result,
          'mode': 'online',
          'fallbackUsed': false,
        };
      } catch (e) {
        debugPrint('Online analysis failed, falling back to offline: $e');
      }
    }

    debugPrint('Using OFFLINE AI analysis');
    final offlineResult = analyzeOffline(input);
    return {
      ...offlineResult,
      'fallbackUsed': !_isOnline,
    };
  }

  /// Get current network status
  bool get isOnline => _isOnline;

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
