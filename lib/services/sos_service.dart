import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'media_recorder.dart';
import 'storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';
import 'foreground_service.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
// media recorder and sharing not enabled in this build

import 'poi_service.dart';
import '../widgets/futuristic_button.dart';
import 'offline_queue.dart';
import 'silent_recorder.dart';
import 'auto_call_loop.dart';
import 'ai_context.dart';
// Some dialog flows intentionally await functions that use the widget's BuildContext
// (e.g. showDialog). These are carefully guarded with `mounted` checks and local
// lifecycle handling; suppress the analyzer rule in this file to avoid false
// positives on use_build_context_synchronously where we've validated safety.
// ignore_for_file: use_build_context_synchronously
class SOSservice {
  static StreamSubscription<AccelerometerEvent>? _accelSub;
  static bool _isSosActive = false; // Prevents multiple triggers
  // Stream to notify UI about active SOS state changes (so widgets can react)
  static final StreamController<bool> _activeController = StreamController<bool>.broadcast();
  static Stream<bool> get onActiveChanged => _activeController.stream;
  static List<String> _emergencyContacts = [];
  // Public accessor to read emergency contacts for UI previews
  static List<String> getEmergencyContacts() => List<String>.from(_emergencyContacts);
  static const _queueKey = 'unsent_sos_queue';
  // Sensitivity threshold in g. Increased to reduce false positives.
  // Default threshold (g). Raised to prefer real impacts over gentle placement.
  static double _fallThresholdG = 6.0;

  // Verification window parameters
  static const int _verificationWindowMs = 1500; // collect 1.5s of samples after spike
  static const double _postSpikeMotionThresholdG = 0.7; // average motion below this implies inactivity
  // Pre-spike buffering to help distinguish drops/impacts vs deliberate placement.
  // Keep ~1200ms of recent samples for pre-spike analysis.
  static const int _preSpikeBufferMs = 1200;
  static final List<Map<String, dynamic>> _preSpikeBuffer = [];
  static const double _freeFallG = 0.6; // values below this imply brief free-fall
  static const double _preMovementVarianceThreshold = 0.18; // variance threshold for pre-movement
  static const int _prefsPollMs = 2000; // refresh threshold from prefs every 2s to allow near-real-time changes
  static Timer? _prefsPollTimer;
  static final List<double> _verificationSamples = [];
  static bool _awaitingVerification = false;

  // Live tracking state
  static Timer? _trackTimer;
  static String? _trackSessionId;
  static String? _trackToken;
  static final int _trackIntervalSeconds = 10; // post every 10s by default

  // Public accessor for UI to know if an SOS flow is active
  static bool get isActive => _isSosActive;

  /// Cancel any in-progress/manual SOS flow. If a dialog is showing, pass a
  /// BuildContext so it can be dismissed. This is best-effort and will not
  /// throw if there is no dialog.
  static void cancelActiveSos(BuildContext? context) {
    if (!_isSosActive) return;
    _isSosActive = false;
    // notify listeners
    try { _activeController.add(_isSosActive); } catch (_) {}
    _awaitingVerification = false;
    _verificationSamples.clear();
    try {
      if (context != null) Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
    // best-effort stop live tracking
    try {
      _stopLiveTracking();
    } catch (_) {}
  }

  static Future<void> _startLiveTracking({int durationSeconds = 3600}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Prefer explicit server_url; removed deprecated WhatsApp backend preference
      final backend = prefs.getString('server_url') ?? 'http://10.0.2.2:3000';
      final uri = Uri.parse('$backend/track/start');
      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'durationSeconds': durationSeconds})).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body) as Map<String, dynamic>;
        _trackSessionId = js['sessionId'] as String?;
        _trackToken = js['token'] as String?;
        final short = js['shortUrl'] as String?;
        if (short != null) {
          try { await prefs.setString('last_tracking_shorturl', short); } catch (_) {}
        }
        // persist for native read if needed
        try { await prefs.setString('current_tracking_session', jsonEncode({'sessionId': _trackSessionId, 'token': _trackToken})); } catch (_) {}
        // start periodic posting
        _trackTimer?.cancel();
        _trackTimer = Timer.periodic(Duration(seconds: _trackIntervalSeconds), (_) async {
          try { await _postLocationUpdate(); } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('startLiveTracking failed: $e');
    }
  }
  
  // Restore advanced fall-detection logic (two-stage) with verification window.
  static Future<void> startFallDetection(BuildContext? context, List<String> contacts) async {
    _emergencyContacts = contacts;
    if (_accelSub != null) return;

    // Load user-configured fall threshold and start prefs poll timer
    try {
      final prefs = await SharedPreferences.getInstance();
      _fallThresholdG = prefs.getDouble('fallThreshold') ?? _fallThresholdG;
      _prefsPollTimer?.cancel();
      _prefsPollTimer = Timer.periodic(const Duration(milliseconds: _prefsPollMs), (_) async {
        try {
          final p = await SharedPreferences.getInstance();
          _fallThresholdG = p.getDouble('fallThreshold') ?? _fallThresholdG;
        } catch (_) {}
      });
    } catch (_) {}

    _accelSub = accelerometerEventStream().listen((event) {
      try {
        final gForce = math.sqrt(math.pow(event.x, 2) + math.pow(event.y, 2) + math.pow(event.z, 2)) / 9.8;
        final now = DateTime.now().millisecondsSinceEpoch;

        // Maintain pre-spike buffer
        _preSpikeBuffer.add({'ts': now, 'g': gForce});
        while (_preSpikeBuffer.isNotEmpty && (now - (_preSpikeBuffer.first['ts'] as int)) > _preSpikeBufferMs) {
          _preSpikeBuffer.removeAt(0);
        }

        if (_awaitingVerification) {
          _verificationSamples.add(gForce);
          return;
        }

        if (gForce > _fallThresholdG && !_isSosActive) {
          _awaitingVerification = true;
          _verificationSamples.clear();

          // Pre-spike analysis
          bool freeFallDetected = false;
          double preMean = 0.0;
          double preVar = 0.0;
          try {
            if (_preSpikeBuffer.isNotEmpty) {
              final preGs = _preSpikeBuffer.map((e) => e['g'] as double).toList();
              double sumpre = 0.0;
              for (final d in preGs) { sumpre += d; }
              preMean = sumpre / preGs.length;
              double ssd = 0.0;
              for (final d in preGs) { ssd += math.pow(d - preMean, 2) as double; }
              preVar = preGs.isNotEmpty ? ssd / preGs.length : 0.0;
              final minPreG = preGs.reduce((a, b) => a < b ? a : b);
              freeFallDetected = minPreG < _freeFallG;
            }
          } catch (_) {}

          Timer(Duration(milliseconds: _verificationWindowMs), () async {
            try {
              if (_verificationSamples.isEmpty) {
                _awaitingVerification = false;
                return;
              }
              double sum = 0;
              for (final s in _verificationSamples) { sum += (s - 1.0).abs(); }
              final avgDev = sum / _verificationSamples.length;
              final bool preMovement = preVar > _preMovementVarianceThreshold;
              final bool quietAfter = avgDev < _postSpikeMotionThresholdG;
              final bool likelyFall = quietAfter && (freeFallDetected || preMovement);

              if (likelyFall) {
                _isSosActive = true;
                try { _activeController.add(_isSosActive); } catch (_) {}
                try { NotificationService.showAlertNotification('Fall detected', 'Are you OK? Tap to open SilentSOS'); } catch (_) {}
                if (context?.mounted ?? false) {
                  _showCountdownDialog(context!, 'Fall Detected');
                }
              }
            } catch (e) {
              debugPrint('Verification error: $e');
            } finally {
              _awaitingVerification = false;
              _verificationSamples.clear();
            }
          });
        }
      } catch (_) {}
    });

    // Start a periodic retry scheduler for the offline queue while detection is active
    _startQueueRetryScheduler();
  }

  static void stopFallDetection() {
    _accelSub?.cancel();
    _accelSub = null;
    _prefsPollTimer?.cancel();
    _prefsPollTimer = null;
    _stopQueueRetryScheduler();
  }

  static Future<void> triggerManualSOS(BuildContext context, List<String> contacts) async {
    if (_isSosActive) return;
    _isSosActive = true;
    try { _activeController.add(_isSosActive); } catch (_) {}
    _emergencyContacts = contacts;
    _showCountdownDialog(context, 'Manual SOS');
  }

  // Queue retry scheduler
  static Timer? _queueRetryTimer;
  static void _startQueueRetryScheduler() {
    _queueRetryTimer?.cancel();
    _queueRetryTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      try {
        await retryQueuedMessages();
      } catch (_) {}
    });
  }

  static void _stopQueueRetryScheduler() {
    _queueRetryTimer?.cancel();
    _queueRetryTimer = null;
  }

  static Future<void> _stopLiveTracking() async {
    try {
      _trackTimer?.cancel();
      _trackTimer = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_tracking_session');
      _trackSessionId = null;
      _trackToken = null;
    } catch (_) {}
  }

  // Public wrappers for starting/stopping live tracking
  static Future<void> startLiveTracking({int durationSeconds = 3600}) async => _startLiveTracking(durationSeconds: durationSeconds);
  static Future<void> stopLiveTracking() async => _stopLiveTracking();

  // Minimal post-location helper (used by the tracking timer)
  static Future<void> _postLocationUpdate() async {
    try {
      if (_trackSessionId == null || _trackToken == null) return;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation));
      final prefs = await SharedPreferences.getInstance();
      final backend = prefs.getString('server_url') ?? 'http://10.0.2.2:3000';
      final url = Uri.parse('$backend/track/$_trackSessionId/update?token=$_trackToken');
  final body = jsonEncode({'lat': pos.latitude, 'lon': pos.longitude, 'speed': pos.speed, 'accuracy': pos.accuracy, 'ts': pos.timestamp.millisecondsSinceEpoch});
      await http.post(url, headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('postLocationUpdate failed: $e');
    }
  }



  static Future<Map<String, dynamic>> _sendSOS({bool? includeMediaOverride}) async {
    // Build core message with current location and optional live short url
    final location = await _getLocation();
    String message = "🆘 SILENTSOS EMERGENCY\nMy location: https://maps.google.com/?q=$location";
    try {
      final prefs = await SharedPreferences.getInstance();
      final short = prefs.getString('last_tracking_shorturl');
      if (short != null && short.isNotEmpty) message = '$message\nLive: $short';
    } catch (_) {}

  // Append POI info when available (best-effort)
    try {
      final locParts = location.split(',');
      final lat = double.tryParse(locParts[0]) ?? 0.0;
      final lon = double.tryParse(locParts[1]) ?? 0.0;
      final civ = await POIService.nearestCivilization(lat, lon);
      final transport = await POIService.nearestTransport(lat, lon);
      final parts = <String>[];
      if (civ.isNotEmpty) parts.add('Nearest place: $civ');
      if (transport.isNotEmpty) parts.add('Nearest transport: $transport');
      if (parts.isNotEmpty) message = '$message\n${parts.join('\n')}';
    } catch (_) {}

    // Run a lightweight on-device triage (conservative) and append label if notable
    try {
      final triageLabel = AIContext.triage(<String, dynamic>{});
      if (triageLabel != 'low') {
        message = '$message\nTriage (on-device): $triageLabel';
      }
    } catch (_) {}

    bool anySent = false;
    final failedRecipients = <String>[];
    final recipientStatus = <String, String>{};

    // Media handling (MVP): prefer video if enabled; otherwise capture short audio
    try {
      final prefs = await SharedPreferences.getInstance();
      final allowVideoPref = prefs.getBool('allow_auto_video') ?? false;
      final allowVideo = includeMediaOverride ?? allowVideoPref;
      final recordSeconds = prefs.getInt('sosRecordingDuration') ?? 30;

      if (allowVideo) {
        try {
          final recPaths = await MediaRecorder.recordSplitVideo(seconds: recordSeconds);
          final uploadedUrls = <String>[];
          for (final p in recPaths) {
            try {
              final file = File(p);
              final remote = 'sos_media/${DateTime.now().millisecondsSinceEpoch}_${p.split('/').last}';
              final url = await StorageService.uploadFile(file, remote);
              uploadedUrls.add(url);
            } catch (e) {
              debugPrint('Media upload failed for $p: $e');
            }
          }
          if (uploadedUrls.isNotEmpty) {
            message = '$message\nMedia: ${uploadedUrls.join('\n')}';
            try { await prefs.setStringList('last_uploaded_media', uploadedUrls); } catch (_) {}
            try {
              const channel = MethodChannel('silent_sos/foreground');
              await channel.invokeMethod('persistLastUploadedMedia', uploadedUrls);
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('Media recording failed or cancelled: $e');
        }
      } else {
        // Capture short audio clip (foreground-only in MVP)
        try {
          final audioPath = await SilentRecorder.recordAudio(seconds: recordSeconds);
          if (audioPath != null) {
            final file = File(audioPath);
            final remote = 'sos_media/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
            try {
              final url = await StorageService.uploadFile(file, remote);
              message = '$message\nAudio: $url';
              try { await prefs.setStringList('last_uploaded_media', [url]); } catch (_) {}
            } catch (e) {
              debugPrint('Audio upload failed: $e');
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    // Send messages (SMS first). On failure, persist via OfflineQueue and mark for possible call fallback.
    for (final number in _emergencyContacts) {
      final smsSent = await _sendSMS(number, message);
      if (smsSent) {
        anySent = true;
        recipientStatus[number] = 'sent';
      } else {
        try {
          await OfflineQueue.enqueue(number, message);
        } catch (_) {
          await _queueUnsent(number, message);
        }
        failedRecipients.add(number);
        recipientStatus[number] = 'queued';
      }
    }

    // If there are failures and user opted for auto-callbacks, schedule dialing attempts (MVP: immediate)
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoCall = prefs.getBool('auto_call_on_failure') ?? false;
      if (autoCall && failedRecipients.isNotEmpty) {
        for (final n in failedRecipients) {
          try {
            await AutoCallLoop.callWithRetries(n, maxRetries: 2);
          } catch (_) {}
        }
      }
    } catch (_) {}

    return {
      'anySent': anySent,
      'failedCount': failedRecipients.length,
      'statuses': recipientStatus,
    };
  }
  // The main countdown dialog
  static void _showCountdownDialog(BuildContext context, String triggerType) {
    // Show the dialog immediately and let the dialog fetch nearby POI
    // information asynchronously. This avoids using the provided BuildContext
    // across async gaps which can lead to analyzer warnings.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CountdownDialog(triggerType: triggerType),
    ).then((_) {
      // Reset the active flag when the dialog is dismissed
      _isSosActive = false;
    });
  }



  /// Attempt to resend an SOS to a single [number]. This constructs a concise
  /// message using the latest known location and persisted last-uploaded media
  /// (if available) and attempts SMS first then WhatsApp fallback.
  /// Returns true if any transport reported success.
  static Future<bool> resendTo(String number) async {
    try {
      final loc = await _getLocation();
      String message = "🆘 SILENTSOS EMERGENCY\nMy location: https://maps.google.com/?q=$loc";
      try {
        final prefs = await SharedPreferences.getInstance();
        final short = prefs.getString('last_tracking_shorturl');
        if (short != null && short.isNotEmpty) {
          message = '$message\nLive: $short';
        }
      } catch (_) {}
      try {
        final prefs = await SharedPreferences.getInstance();
        final last = prefs.getStringList('last_uploaded_media') ?? <String>[];
        if (last.isNotEmpty) {
          message = '$message\nMedia: ${last.join('\n')}';
        }
      } catch (_) {}

      // Try SMS
      final smsOk = await _sendSMS(number, message);
      if (smsOk) return true;

      // If SMS failed, queue for retry and return false
      await _queueUnsent(number, message);
      return false;
    } catch (e) {
      debugPrint('resendTo error: $e');
      return false;
    }
  }

  // --- Helper Methods ---

  static Future<String> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return "12.9716,77.5946"; // Fallback

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
          return "12.9716,77.5946";
        }
      }
      // Use the newer LocationSettings API for accurate location and to avoid
      // deprecated `desiredAccuracy` usage.
      final settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        // Optionally add a timeLimit if you want to avoid blocking too long
      );
      Position position = await Geolocator.getCurrentPosition(locationSettings: settings);
      return "${position.latitude},${position.longitude}";
    } catch (e) {
      return "12.9716,77.5946"; // Fallback
    }
  }

  static Future<bool> _sendSMS(String phoneNumber, String message) async {
    // First try to send silently via native SmsManager using platform channel
    try {
      final sent = await ForegroundService.sendSms(phoneNumber, message);
      if (sent) return true;
      // If silent send reported failure, attempt to request SMS permission and retry once.
      try {
        final status = await Permission.sms.status;
        if (!status.isGranted) {
          final req = await Permission.sms.request();
          if (req.isGranted) {
            // retry once
            final retried = await ForegroundService.sendSms(phoneNumber, message);
            if (retried) return true;
          }
        }
      } catch (_) {}
    } catch (_) {}

    // Fallback: open the SMS app with the message prefilled (user must press send).
    final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber, queryParameters: {'body': message});
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      // Fallthrough to queue
    }
    return false;
  }

  // WhatsApp fallback removed: we now prefer SMS + queueing for retries.

  // --- Offline Queuing Logic ---

  static Future<void> _queueUnsent(String to, String body) async {
    final prefs = await SharedPreferences.getInstance();
    final q = prefs.getStringList(_queueKey) ?? [];
    q.add(jsonEncode({'to': to, 'body': body, 'ts': DateTime.now().toIso8601String()}));
    await prefs.setStringList(_queueKey, q);
  }

  static Future<void> retryQueuedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final q = prefs.getStringList(_queueKey) ?? [];
    if (q.isEmpty) return;

    final remaining = <String>[];
    for (final item in q) {
      final map = jsonDecode(item) as Map<String, dynamic>;
      final to = map['to'] as String;
      final body = map['body'] as String;
      // Try SMS first; if it fails keep item in remaining queue
      final smsSent = await _sendSMS(to, body);
      if (!smsSent) {
        remaining.add(item);
      }
    }
    await prefs.setStringList(_queueKey, remaining);
  }
}

// A stateful widget for the countdown dialog to manage its own timer and state.
class CountdownDialog extends StatefulWidget {
  final String triggerType;
  final String? nearestCivilization;
  final String? nearestTransport;
  const CountdownDialog({super.key, required this.triggerType, this.nearestCivilization, this.nearestTransport});

  @override
  State<CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog> {
  Timer? _timer;
  int _countdown = 10; // Default value
  bool _sending = false;
  bool? _sendSuccess;
  int _failedCount = 0;
  bool _includeMedia = false;
  Map<String, String> _perRecipientStatus = {};
  String? _civ;
  String? _trans;
  String? _trackingUrl;

  @override
  void initState() {
    super.initState();
    _loadTimerValueAndStart();
    // Initialize local POI state from the widget (may be null), and fetch
    // POI info asynchronously if missing.
    _civ = widget.nearestCivilization;
    _trans = widget.nearestTransport;
    if (_civ == null && _trans == null) {
      (() async {
        try {
          final loc = await SOSservice._getLocation();
          final parts = loc.split(',');
          final lat = double.tryParse(parts[0]) ?? 0.0;
          final lon = double.tryParse(parts[1]) ?? 0.0;
          final civ = await POIService.nearestCivilization(lat, lon);
          final trans = await POIService.nearestTransport(lat, lon);
          if (!mounted) return;
          setState(() {
            _civ = civ.isNotEmpty ? civ : null;
            _trans = trans.isNotEmpty ? trans : null;
          });
        } catch (_) {}
      })();
      // load any tracking short URL persisted by startLiveTracking
      (() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final s = prefs.getString('last_tracking_shorturl');
          if (!mounted) return;
          setState(() { _trackingUrl = s; });
        } catch (_) {}
      })();
    }
  }

  Future<void> _loadTimerValueAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDuration = prefs.getInt('sosTimerDuration') ?? 10;
    setState(() => _countdown = savedDuration);
    // Default include-media toggle follows saved preference but can be changed per-alert
    _includeMedia = prefs.getBool('allow_auto_video') ?? false;
    _startVibrationAndTimer();
  }

  void _startVibrationAndTimer() async {
    // Start short vibration pulses to alert the user and reduce false cancellations.
    final prefs = await SharedPreferences.getInstance();
    int amp = prefs.getInt('vibrationAmplitude') ?? 160;
    // Clamp amplitude to [1,255] (Android amplitude range)
    if (amp < 1) amp = 1;
    if (amp > 255) amp = 255;
    bool hasVibrator = await Vibration.hasVibrator();
    Timer? vibrationTimer;
    if (hasVibrator) {
      vibrationTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        // short pulse using saved amplitude when supported
        try {
          // Some devices / plugin versions may not support amplitude parameter; fall back gracefully
          await Vibration.vibrate(duration: 180, amplitude: amp);
        } catch (e) {
          try {
            await Vibration.vibrate(duration: 180);
          } catch (_) {}
        }
      });
    }

    // Start live tracking so recipients can follow the user's movement during the SOS
      try {
        await SOSservice.startLiveTracking();
      } catch (e) {
      debugPrint('Could not start live tracking: $e');
    }

    // Start the countdown timer
  _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (_countdown <= 1) {
          timer.cancel();
          vibrationTimer?.cancel();
          Vibration.cancel();
          // Don't pop the dialog yet — show sending state inline.
          setState(() {
            _sending = true;
          });

          // If configured to ask the user about including media, confirm now
          final proceedWithMedia = await _confirmIncludeMediaIfNeeded();
          if (!mounted) {
            // If UI no longer mounted, abort safely and reset sending state
            setState(() {
              _sending = false;
            });
            return;
          }

          // Await the send result and show success/failure
          SOSservice._sendSOS(includeMediaOverride: proceedWithMedia).then((res) {
            final anySent = res['anySent'] as bool? ?? false;
            final failed = res['failedCount'] as int? ?? 0;
            setState(() {
                _sending = false;
                // The backend returns a per-recipient map under 'statuses'
                final Map<String, dynamic>? statuses = (res['statuses'] as Map?)?.cast<String, dynamic>();
                if (statuses != null) {
                  // Replace failedCount/anySent with per-recipient view
                  _failedCount = statuses.values.where((v) => v != 'sent').length;
                  _sendSuccess = statuses.values.every((v) => v == 'sent');
                  // store statuses locally to display detailed results
                  _perRecipientStatus = statuses.map((k, v) => MapEntry(k, v.toString()));
                } else {
                  _sendSuccess = anySent && failed == 0;
                  _failedCount = failed;
                }
              });
            // Stop live tracking once send attempt completed
            try { SOSservice.stopLiveTracking(); } catch (_) {}
          }).catchError((e) {
            setState(() {
              _sending = false;
              _sendSuccess = false;
              _failedCount = 0;
            });
          });
        } else {
          setState(() => _countdown--);
        }
    });
  }

  Future<bool?> _confirmIncludeMediaIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return _includeMedia;
      final defaultMode = prefs.getString('include_media_default') ?? 'ask';
      if (defaultMode == 'always') return true;
      if (defaultMode == 'never') return false;

      // 'ask' -> show a confirmation dialog offering 'Include this time', 'Don't include', 'Always include in future'
      // Show dialog but don't block forever — timeout and default to 'no' after 8s
      final dialogFuture = showDialog<String?>(context: context, barrierDismissible: false, builder: (ctx) {
        return AlertDialog(
          title: const Text('Include media in this SOS?'),
          content: const Text('Would you like to attach recorded audio/video to this SOS message?'),
          actions: [
                FuturisticButton(
                  onPressed: () => Navigator.of(ctx).pop('no'),
                  style: FuturisticButtonStyle.secondary,
                  child: const Text('No'),
                ),
                FuturisticButton(
                  onPressed: () => Navigator.of(ctx).pop('always'),
                  style: FuturisticButtonStyle.secondary,
                  child: const Text('Always'),
                ),
                FuturisticButton(
                  onPressed: () => Navigator.of(ctx).pop('yes'),
                  style: FuturisticButtonStyle.primary,
                  child: const Text('Yes'),
                ),
              ],
        );
      });
      String? choice;
      try {
        choice = await dialogFuture.timeout(const Duration(seconds: 8));
      } catch (_) {
        // Timeout -> dismiss dialog if still mounted
        try {
          if (mounted) Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        choice = 'no';
      }
      if (choice == 'always') {
        await SharedPreferences.getInstance().then((p) => p.setString('include_media_default', 'always'));
        return true;
      }
      if (choice == 'yes') return true;
      return false;
    } catch (_) {
      return _includeMedia;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("🚨 ${widget.triggerType}: Are you safe?"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show which contacts will receive the SOS so user can confirm
          Builder(builder: (context) {
            final contacts = SOSservice.getEmergencyContacts();
            if (contacts.isEmpty) return const SizedBox.shrink();
            // Show up to 3 compact chips and a summary count
            final chips = contacts.take(3).map((c) {
              // Mask middle digits for privacy
              String masked = c;
              try {
                final only = c.replaceAll(RegExp(r'[^0-9+]'), '');
                if (only.length > 6) masked = '${only.substring(0, 3)}•••${only.substring(only.length - 3)}';
              } catch (_) {}
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Chip(label: Text(masked, style: const TextStyle(fontSize: 12))),
              );
            }).toList();
            return Column(
              children: [
                Align(alignment: Alignment.centerLeft, child: Text('Will notify ${contacts.length} contact(s):', style: Theme.of(context).textTheme.bodyLarge)),
                const SizedBox(height: 6),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: chips)),
                const SizedBox(height: 8),
              ],
            );
          }),
          // If currently sending, show progress and final state; otherwise show countdown
            if (_sending) ...[
            const Text("Sending SOS…"),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Please wait — sending to contacts'),
            const SizedBox(height: 8),
              if (_trackingUrl != null) Row(children: [
              Expanded(child: Text('Live link:', style: TextStyle(color: Colors.white70))),
              FuturisticIconButton(
                icon: Icons.open_in_new,
                size: 40,
                onPressed: () async {
                  try {
                    final uri = Uri.parse(_trackingUrl!);
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
              ),
              const SizedBox(width: 8),
              FuturisticIconButton(
                icon: Icons.copy,
                size: 40,
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: _trackingUrl!));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
                  } catch (_) {}
                },
              ),
              const SizedBox(width: 8),
              FuturisticIconButton(
                icon: Icons.share,
                size: 40,
                onPressed: () async {
                  try {
                    if (_trackingUrl != null) await SharePlus.instance.share(ShareParams(text: _trackingUrl!));
                  } catch (_) {}
                },
              ),
            ]),
            ] else if (_sendSuccess != null) ...[
            // Completed: show success/failure
            if (_sendSuccess == true) ...[
              const Icon(Icons.check_circle, size: 48, color: Colors.green),
              const SizedBox(height: 12),
              const Text('All messages sent successfully.'),
            ] else ...[
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_failedCount > 0 ? 'Failed to send to $_failedCount contact(s). Messages queued.' : 'Failed to send messages.'),
            ],
            const SizedBox(height: 12),
              // Show per-recipient status list if available
              if (_perRecipientStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView(
                    children: _perRecipientStatus.entries.map((e) {
                      final status = e.value;
                      IconData icon = Icons.hourglass_top;
                      Color color = Colors.amber;
                      String label = 'Queued';
                      if (status == 'sent') { icon = Icons.check_circle; color = Colors.green; label = 'Sent'; }
                      else if (status == 'failed') { icon = Icons.error; color = Colors.red; label = 'Failed'; }
                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(e.key),
                        subtitle: Text(label),
                        trailing: status != 'sent'
                            ? IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Retry',
                                onPressed: () async {
                                  // optimistic UI
                                  setState(() => _perRecipientStatus[e.key] = 'retrying');
                                  final ok = await SOSservice.resendTo(e.key);
                                  setState(() {
                                    _perRecipientStatus[e.key] = ok ? 'sent' : 'failed';
                                    _failedCount = _perRecipientStatus.values.where((v) => v != 'sent').length;
                                    _sendSuccess = _perRecipientStatus.values.every((v) => v == 'sent');
                                  });
                                },
                              )
                            : null,
                      );
                    }).toList(),
                  ),
                ),
              ],
            FuturisticButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: FuturisticButtonStyle.secondary,
              child: const Text('Close'),
            ),
          ] else ...[
            const Text("Sending SOS in..."),
            const SizedBox(height: 20),
            // Lottie countdown animation for a more modern look
            SizedBox(height: 100, child: Lottie.network('https://assets6.lottiefiles.com/packages/lf20_j1adxtyb.json', fit: BoxFit.contain)),
            const SizedBox(height: 8),
            Text(
              '$_countdown',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Show nearest POI info (if available) so the user can confirm context
            if (_civ != null || _trans != null) ...[
              const SizedBox(height: 8),
              Card(
                color: const Color(0xFF0E0E14),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_civ != null) Text('Nearest place: $_civ', style: const TextStyle(color: Colors.white)),
                      if (_trans != null) Text('Nearest transport: $_trans', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
            // Per-alert override: ask whether to include media for this send. Defaults to saved preference.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Attach audio/video'),
                const SizedBox(width: 12),
                Switch(
                  value: _includeMedia,
                  onChanged: (v) => setState(() => _includeMedia = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Require press-and-hold to cancel to avoid mis-touches.
            GestureDetector(
              onLongPress: () {
                _timer?.cancel();
                Vibration.cancel();
                Navigator.pop(context);
              },
              child: FuturisticButton(
                onPressed: null,
                style: FuturisticButtonStyle.secondary,
                child: const Text("PRESS & HOLD TO CANCEL"),
              ),
            ),
            const SizedBox(height: 12),
            // Quick action buttons: let user explicitly say they are NOT safe (send now)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: FuturisticButton(
                    onPressed: _sending
                        ? null
                        : () async {
                            // User indicates they are not safe -> trigger immediate send
                            try {
                              _timer?.cancel();
                              Vibration.cancel();
                              setState(() => _sending = true);
                              final proceedWithMedia = await _confirmIncludeMediaIfNeeded();
                              if (!mounted) {
                                setState(() => _sending = false);
                                return;
                              }
                              final res = await SOSservice._sendSOS(includeMediaOverride: proceedWithMedia);
                              final Map<String, dynamic>? statuses = (res['statuses'] as Map?)?.cast<String, dynamic>();
                              setState(() {
                                _sending = false;
                                if (statuses != null) {
                                  _perRecipientStatus = statuses.map((k, v) => MapEntry(k, v.toString()));
                                  _failedCount = _perRecipientStatus.values.where((v) => v != 'sent').length;
                                  _sendSuccess = _perRecipientStatus.values.every((v) => v == 'sent');
                                } else {
                                  final any = res['anySent'] as bool? ?? false;
                                  final failed = res['failedCount'] as int? ?? 0;
                                  _sendSuccess = any && failed == 0;
                                  _failedCount = failed;
                                }
                              });
                              // stop live tracking
                              try { await SOSservice.stopLiveTracking(); } catch (_) {}
                            } catch (e) {
                              setState(() {
                                _sending = false;
                                _sendSuccess = false;
                              });
                            }
                          },
                    style: FuturisticButtonStyle.danger,
                    child: const Text("No — I'm not safe"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FuturisticButton(
                    onPressed: () {
                      // User confirms they are safe — stop the SOS flow
                      try {
                        _timer?.cancel();
                        Vibration.cancel();
                        SOSservice.cancelActiveSos(context);
                      } catch (_) {}
                      Navigator.pop(context);
                    },
                    style: FuturisticButtonStyle.secondary,
                    child: const Text('Yes — Stop the SOS'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
