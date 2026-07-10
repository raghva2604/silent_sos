import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import 'analytics_service.dart';

class LiveTrackingService {
  Timer? _timer;
  static const int _maxConsecutiveFailures = 3;
  static int _consecutiveFailures = 0;

  /// Starts live tracking and posts location every 5 seconds
  /// to backend endpoint.
  void startTracking() {
    stopTracking(); // avoid duplicates / overlapping timers
    _consecutiveFailures = 0;
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        // Check network connectivity before attempting to send
        final connectivity = await Connectivity().checkConnectivity();
        final isConnected = connectivity.isNotEmpty && 
            !connectivity.contains(ConnectivityResult.none);

        if (!isConnected) {
          // ignore: avoid_print
          print('⚠️ Live tracking paused: no network connection');
          // keep timer running for auto-recovery when connectivity returns
          return;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        final now = DateTime.now().toUtc().toIso8601String();

        final headers = ApiConfig.defaultHeaders();
        final payload = jsonEncode({
          'userId': 'anonymous',
          'latitude': position.latitude,
          'longitude': position.longitude,
          'battery': 100,
          'riskScore': 0,
          'status': 'SAFE',
          'speed': 0,
          'time': now,
          'timestamp': now,
        });

        Future<http.Response> sendTo(Uri endpoint) async {
          return await http.post(endpoint, headers: headers, body: payload);
        }

        final primaryUri = Uri.parse(ApiConfig.updateLiveLocation);
        final fallbackUri = Uri.parse(ApiConfig.updateLiveLocationFallback);

        // Before attempting network I/O, attempt DNS lookup with retry/backoff
        final host = primaryUri.host;
        final backoffs = [0, 2, 5];
        http.Response? response;

        for (var attempt = 0; attempt < backoffs.length; attempt++) {
          if (attempt > 0) await Future.delayed(Duration(seconds: backoffs[attempt]));
          try {
            try {
              await InternetAddress.lookup(host);
            } catch (e) {
              // DNS failed for this attempt; try next backoff
              // ignore: avoid_print
              print('⚠️ LiveTracking host lookup failed for $host: $e');
              continue;
            }

            response = await sendTo(primaryUri).timeout(const Duration(seconds: 5));
            break;
          } catch (e) {
            // ignore: avoid_print
            print('⚠️ Live tracking primary host failed (attempt ${attempt + 1}): $e');
            response = null;
          }
        }

        if (response == null || (response.statusCode != 200 && response.statusCode != 201)) {
          try {
            // try fallback once
            try {
              await InternetAddress.lookup(fallbackUri.host);
              response = await sendTo(fallbackUri).timeout(const Duration(seconds: 5));
            } catch (e) {
              response = null;
            }
          } catch (e) {
            response = null;
          }

          if (response == null) {
            _consecutiveFailures++;
            if (_consecutiveFailures >= _maxConsecutiveFailures) {
              // ignore: avoid_print
              print('⚠️ Live tracking disabled after $_maxConsecutiveFailures consecutive failures');
              stopTracking();
              return;
            }
          }
        }

        if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
          _consecutiveFailures = 0;
          // ignore: avoid_print
          print('📍 Live location sent successfully (${timer.tick})');
        } else if (response != null) {
          _consecutiveFailures++;
          // ignore: avoid_print
          print('⚠️ Live location failed (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        // ignore: avoid_print
        print('Tracking error: $e');

        if (e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated with hostname')) {
          // If DNS fails, back off and avoid continuous spam in logs.
          print('⚠️ Live tracking host not reachable; using 30s backoff.');
          await Future.delayed(const Duration(seconds: 30));
        }
      }
    });
  }

  /// Stops live tracking timer to save battery and avoid unwanted updates
  void stopTracking() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
      // ignore: avoid_print
      print('⏹ Live tracking stopped');
      AnalyticsService.logEvent('live_tracking_stopped');
    }
    _timer = null;
  }
}
