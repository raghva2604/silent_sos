import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';

// Top-level background service callback for native entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  try {
  // CRITICAL: Set foreground notification info FIRST before any async operations
  // This must complete within 5 seconds or Android fires ForegroundServiceDidNotStartInTimeException
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'SOS Live Tracking',
      content: 'Location tracking is active',
    );
  }

  BackgroundService._isServiceRunning = true;

  BackgroundService._timer?.cancel();
  
  // Start location tracking loop AFTER foreground notification is set
  BackgroundService._timer =
      Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (!BackgroundService._isServiceRunning) {
      timer.cancel();
      return;
    }

    try {
      // Check if permissions granted before requesting location
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // Skip this cycle if permissions not granted
        return;
      }

      // Check network connectivity before attempting to send
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
        // Skip this cycle if no network connection
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final now = DateTime.now().toUtc().toIso8601String();

      final body = jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'time': now,
        'timestamp': now,
        'userId': 'anonymous',
      });
      final headers = ApiConfig.defaultHeaders();

      Future<http.Response> sendTo(Uri endpoint) async {
        return await http.post(endpoint, headers: headers, body: body);
      }

      final primaryUri = Uri.parse(ApiConfig.updateLiveLocation);
      final fallbackUri = Uri.parse(ApiConfig.updateLiveLocationFallback);

      http.Response? response;
      try {
        response = await sendTo(primaryUri);
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Background live tracking primary host failed: $e');
        if (e.toString().contains('Failed host lookup') ||
            e.toString().contains('No address associated with hostname')) {
          response = null;
        } else {
          rethrow;
        }
      }

      if (response == null ||
          (response.statusCode != 200 && response.statusCode != 201)) {
        try {
          response = await sendTo(fallbackUri);
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Background live tracking fallback host failed: $e');
          response = null;
        }
      }

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201)) {
        // ignore: avoid_print
        print('📍 Background live location sent: ${response.statusCode}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Tracking error: $e');
    }
  });

  service.on('stopService').listen((event) {
    BackgroundService._timer?.cancel();
    BackgroundService._timer = null;
    BackgroundService._isServiceRunning = false;
    service.stopSelf();
  });
  } catch (e) {
    print('Background service onStart error: $e');
  }
}

// Top-level iOS background callback
@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

class BackgroundService {
  static final _service = FlutterBackgroundService();
  static Timer? _timer;
  static bool _isServiceRunning = false;

  static Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Do NOT auto-start; start only when needed
        isForegroundMode: true,
        notificationChannelId: 'sos_tracking',
        initialNotificationTitle: 'SOS Tracking',
        initialNotificationContent: 'Location tracking active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Do NOT call startService() here; let it be called only when needed
    print('✓ BackgroundService configured (not started until SOS triggered)');
  }

  static void start() {
    if (_isServiceRunning) {
      // Already running, avoid duplicates.
      return;
    }
    _isServiceRunning = true;
    _service.startService();
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _isServiceRunning = false;
    _service.invoke('stopService');
  }
}

