import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level background service callback for native entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  try {
  // Ensure Flutter bindings are initialized in the background isolate so
  // plugins can register correctly. This is safe and idempotent.
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (_) {}

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

      // Attempt DNS/host resolution with short exponential backoff before
      // making the HTTP request. This reduces "Failed host lookup" noise
      // on flaky OEM networks or isolated background isolates.
      final host = primaryUri.host;
      final retries = [0, 2, 5]; // seconds delays for retries (0 = immediate)
      http.Response? response;

      for (var attempt = 0; attempt < retries.length; attempt++) {
        if (attempt > 0) await Future.delayed(Duration(seconds: retries[attempt]));
        try {
          // Try a quick DNS resolve; InternetAddress.lookup will throw on failure
          try {
            await InternetAddress.lookup(host);
          } catch (e) {
            // DNS failed for this attempt; try next backoff
            // ignore: avoid_print
            print('⚠️ Background host lookup failed for $host: $e');
            continue;
          }

          // If lookup succeeded, attempt HTTP POST
          try {
            // Debug: announce live location target
            // ignore: avoid_print
            print('📍 Sending live location to $primaryUri (attempt ${attempt + 1})');
          } catch (_) {}

          response = await sendTo(primaryUri).timeout(const Duration(seconds: 12));
          break;
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Background live tracking primary host failed (attempt ${attempt + 1}): $e');
          response = null;
        }
      }

      // Try fallback once if primary not successful
      if (response == null || (response.statusCode != 200 && response.statusCode != 201)) {
        try {
          // Try resolve and post to fallback
          try {
            await InternetAddress.lookup(fallbackUri.host);
            response = await sendTo(fallbackUri).timeout(const Duration(seconds: 12));
          } catch (e) {
            // ignore: avoid_print
            print('⚠️ Background live tracking fallback host failed: $e');
            response = null;
          }
        } catch (e) {
          // ignore: avoid_print
          print('⚠️ Background live tracking fallback host final failure: $e');
          response = null;
        }
      }

      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        // ignore: avoid_print
        print('📍 Background live location sent: ${response.statusCode}');
      }

      // Attempt to flush any queued SOS payloads saved while offline
      try {
        await _flushPendingSos();
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Pending SOS flush error: $e');
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

/// Flush any pending SOS payloads stored in SharedPreferences under
/// `pending_sos_queue`. Each entry is a JSON payload with an `attempts` field.
Future<void> _flushPendingSos() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList('pending_sos_queue') ?? <String>[];
    if (queue.isEmpty) return;

    // Work on a copy to avoid mutation while iterating
    final remaining = <String>[];

    for (final item in queue) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        final attempts = (map['attempts'] as int?) ?? 0;
        if (attempts >= 5) {
          // drop after 5 attempts
          // ignore: avoid_print
          print('⚠️ Dropping pending SOS after $attempts attempts: ${map['sessionId']}');
          continue;
        }

        // Attempt to POST to backend
        final uri = Uri.parse(ApiConfig.sendSos);
        final headers = {'Content-Type': 'application/json', 'x-app-secret': ApiConfig.appSecret};
        final response = await http.post(uri, headers: headers, body: jsonEncode(map)).timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) {
          // ignore: avoid_print
          print('✅ Flushed pending SOS: ${map['sessionId']}');
          continue;
        } else {
          // increment attempts and requeue
          map['attempts'] = attempts + 1;
          remaining.add(jsonEncode(map));
        }
      } catch (e) {
        try {
          final m = jsonDecode(item) as Map<String, dynamic>;
          m['attempts'] = ((m['attempts'] as int?) ?? 0) + 1;
          remaining.add(jsonEncode(m));
        } catch (_) {
          // malformed item — skip
        }
      }
    }

    await prefs.setStringList('pending_sos_queue', remaining);
  } catch (e) {
    // ignore: avoid_print
    print('⚠️ _flushPendingSos error: $e');
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

