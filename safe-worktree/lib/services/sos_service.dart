import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'analytics_service.dart';
// beep functionality for countdown; simple stub implemented below
import '../widgets/sos_pulse.dart';
import 'media_recorder.dart';
import 'video_storage_service.dart';
import '../core/risk_notifier.dart';
import '../models/risk_level.dart';
// permission_handler is not used here; permission flow handled elsewhere
// foreground_service not required in this file
import '../config/api_config.dart';

/// Simple beep helper used by countdown dialog. Originally separated into sos_beeper.dart.
/// For build stability, defined here as an empty implementation (no sound).
class SOSBeeper {
  void playBeep(int remaining) {
    // placeholder: real implementation would play audio for countdown ticks
  }

  void stop() {
    // no-op for stub
  }
}

// DISABLED Phase 1: import '../settings/user_settings.dart';

/// Clean SOS service for sending alerts via email/SMS and managing videos
class SOSservice {
  static const String _tag = '🆘 SOSservice';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Build a formatted SMS message with location and Google Maps link
  static String buildSosMessage({
    required double lat,
    required double lng,
    required String address,
  }) {
    return '''🚨 EMERGENCY ALERT 🚨

I may be in danger.

📍 Location:
$address
https://maps.google.com/?q=$lat,$lng

Sent via Silent SOS''';
  }

  /// Open default SMS app with prefilled message
  /// Uses 'smsto:' scheme which works on all Android devices
  static Future<void> openSmsApp({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    if (phoneNumbers.isEmpty) {
      debugPrint('$_tag: ⚠️ No phone numbers provided for SMS');
      return;
    }

    final recipientsSemicolon = phoneNumbers.join(';');
    final recipientsComma = phoneNumbers.join(',');

    final smsSemicolonUri = Uri(
      scheme: 'sms',
      path: recipientsSemicolon,
      queryParameters: {'body': message},
    );

    final smsCommaUri = Uri(
      scheme: 'sms',
      path: recipientsComma,
      queryParameters: {'body': message},
    );

    final smstoSemicolonUri = Uri(
      scheme: 'smsto',
      path: recipientsSemicolon,
      queryParameters: {'body': message},
    );

    final smstoCommaUri = Uri(
      scheme: 'smsto',
      path: recipientsComma,
      queryParameters: {'body': message},
    );

    debugPrint('$_tag: Trying SMS apps for $recipientsSemicolon / $recipientsComma');
    try {
      if (await canLaunchUrl(smsSemicolonUri)) {
        final launched =
            await launchUrl(smsSemicolonUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }

      if (await canLaunchUrl(smsCommaUri)) {
        final launched =
            await launchUrl(smsCommaUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }

      if (await canLaunchUrl(smstoSemicolonUri)) {
        final launched = await launchUrl(smstoSemicolonUri,
            mode: LaunchMode.externalApplication);
        if (launched) return;
      }

      if (await canLaunchUrl(smstoCommaUri)) {
        final launched = await launchUrl(smstoCommaUri,
            mode: LaunchMode.externalApplication);
        if (launched) return;
      }

      debugPrint('$_tag: ⚠️ Failed to launch SMS app for all variations');

      debugPrint('$_tag: ⚠️ Failed to launch SMS app for both sms and smsto');
    } catch (e) {
      debugPrint('$_tag: ❌ Error opening SMS app: $e');
    }
  }

  /// Call an emergency number using the platform dialer
  static Future<void> callEmergencyNumber(String number) async {
    try {
      final uri = Uri(scheme: 'tel', path: number);
      debugPrint('$_tag: Dialing emergency number $number');
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        debugPrint('$_tag: ⚠️ Failed to launch dialer for $number');
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Error calling emergency number: $e');
    }
  }

  /// Main entry point: send SOS alert with recording and message
  static Future<bool> sendSOSAlert({
    required BuildContext context,
    required List<dynamic> selectedContacts,
    required String? videoPath,
    required bool isSafe,
  }) async {
    try {
      debugPrint('$_tag: sendSOSAlert START - isSafe=$isSafe');

      // Get phone numbers and emails from SharedPreferences (now properly extracted)
      final prefs = await SharedPreferences.getInstance();
      final phoneNumbers = prefs.getStringList('sos_phone_numbers') ?? [];
      final emailRecipients = prefs.getStringList('sos_email_recipients') ?? [];

      if (phoneNumbers.isEmpty && emailRecipients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('⚠️ No phone numbers or emails configured'),
              backgroundColor: Colors.orange),
        );
        return false;
      }

      debugPrint(
          '$_tag: Phone recipients: ${phoneNumbers.length}, Email recipients: ${emailRecipients.length}');

      // If caller didn't pass a videoPath, check persisted last paths
      final List<String> videoPaths = [];
      if (videoPath != null && File(videoPath).existsSync()) {
        videoPaths.add(videoPath);
      } else {
        final stored = prefs.getString('last_sos_video_path');
        final stored2 = prefs.getString('last_sos_video_path_secondary');
        if (stored != null && File(stored).existsSync()) videoPaths.add(stored);
        if (stored2 != null && File(stored2).existsSync()) {
          videoPaths.add(stored2);
        }
      }

      // Save copies locally (ensure persisted archive) and normalize paths
      final List<String> savedPaths = [];
      for (final p in videoPaths) {
        try {
          final savedFile = await VideoStorageService.saveVideo(File(p));
          savedPaths.add(savedFile.path);
          debugPrint('$_tag: Video saved locally: ${savedFile.path}');
        } catch (e) {
          debugPrint('$_tag: ⚠️ Failed to save video locally: $e');
        }
      }

      // Get location
      final location = await _getLocation();

      // Build message
      final medicalInfo = prefs.getString('medical_info') ?? '{}';
      final message = _buildMessage(
        isSafe: isSafe,
        location: location,
        medicalInfo: medicalInfo,
        hasVideo: savedPaths.isNotEmpty,
      );

      // If no backend configured, send via SMS only
      final backendUrl = prefs.getString('sosBackendUrl');
      bool emailOk = false;
      bool smsOk = false;
      if (backendUrl == null || backendUrl.isEmpty) {
        debugPrint('$_tag: No backend configured, sending SMS fallback');
        smsOk = await _sendViaSMS(phoneNumbers: phoneNumbers, message: message);
      } else {
        // Send via backend email (attachments if possible)
        emailOk = await _sendViaBackendEmail(
          emailRecipients: emailRecipients,
          message: message,
          videoPaths: savedPaths,
        );
        // Fall back to SMS if email failed
        if (!emailOk && phoneNumbers.isNotEmpty) {
          smsOk =
              await _sendViaSMS(phoneNumbers: phoneNumbers, message: message);
        }
      }

      // Show success message
      if (emailOk || smsOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(emailOk ? '✅ Email sent' : '✅ SMS sent'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Failed to send alert'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      debugPrint('$_tag: ❌ sendSOSAlert exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  /// Send SOS in background (no UI context)
  static Future<bool> sendSOSAlertBackground({
    required List<dynamic> selectedContacts,
    required String? videoPath,
  }) async {
    try {
      debugPrint('$_tag: sendSOSAlertBackground START');

      // Get phone numbers and emails from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final phoneNumbers = prefs.getStringList('sos_phone_numbers') ?? [];
      final emailRecipients = prefs.getStringList('sos_email_recipients') ?? [];

      if (phoneNumbers.isEmpty && emailRecipients.isEmpty) {
        debugPrint('$_tag: No contacts configured for background send');
        return false;
      }

      debugPrint(
          '$_tag: Background send - ${phoneNumbers.length} phones, ${emailRecipients.length} emails');

      final List<String> videoPaths = [];
      if (videoPath != null && File(videoPath).existsSync()) {
        videoPaths.add(videoPath);
      } else {
        final stored = prefs.getString('last_sos_video_path');
        final stored2 = prefs.getString('last_sos_video_path_secondary');
        if (stored != null && File(stored).existsSync()) videoPaths.add(stored);
        if (stored2 != null && File(stored2).existsSync()) {
          videoPaths.add(stored2);
        }
      }

      final List<String> savedPaths = [];
      for (final p in videoPaths) {
        try {
          final savedFile = await VideoStorageService.saveVideo(File(p));
          savedPaths.add(savedFile.path);
          debugPrint('$_tag: Video saved locally: ${savedFile.path}');
        } catch (e) {
          debugPrint('$_tag: ⚠️ Failed to save video: $e');
        }
      }

      await AnalyticsService.logEvent('sos_alert_background', parameters: {
        'phone_recipients': phoneNumbers.length,
        'email_recipients': emailRecipients.length,
        'video_attached': savedPaths.isNotEmpty,
      });

      // Get location
      final location = await _getLocation();

      // Build message
      final medicalInfo = prefs.getString('medical_info') ?? '{}';
      final message = _buildMessage(
        isSafe: false,
        location: location,
        medicalInfo: medicalInfo,
        hasVideo: savedPaths.isNotEmpty,
        isBackground: true,
      );

      final backendUrl = prefs.getString('sosBackendUrl');
      bool emailOk = false;
      bool smsOk = false;
      if (backendUrl == null || backendUrl.isEmpty) {
        debugPrint(
            '$_tag: No backend configured for background send; using SMS fallback');
        smsOk = await _sendViaSMS(phoneNumbers: phoneNumbers, message: message);
      } else {
        // Try email first
        emailOk = await _sendViaBackendEmail(
          emailRecipients: emailRecipients,
          message: message,
          videoPaths: savedPaths,
        );
        if (!emailOk && phoneNumbers.isNotEmpty) {
          smsOk =
              await _sendViaSMS(phoneNumbers: phoneNumbers, message: message);
        }
      }

      debugPrint(
          '$_tag: Background send complete - email=$emailOk, sms=$smsOk');
      return emailOk || smsOk;
    } catch (e) {
      debugPrint('$_tag: ❌ Background send exception: $e');
      return false;
    }
  }

  /// Show countdown dialog for manual/background triggers
  /// Displays a countdown dialog unless [silent] is true, in which case
  /// the method simply waits the given duration and returns `true`.
  static Future<bool?> showCountdownDialog(
    BuildContext context, {
    int sosCountdown = 10,
    required String triggerType,
    bool silent = false,
  }) async {
    if (silent) {
      // no UI shown in game mode; just delay and return true (auto-send)
      await AnalyticsService.logEvent('sos_countdown_silent', parameters: {
        'trigger_type': triggerType,
        'duration_seconds': sosCountdown,
      });
      await Future.delayed(Duration(seconds: sosCountdown));
      return true;
    }

    await AnalyticsService.logEvent('sos_countdown_shown', parameters: {
      'trigger_type': triggerType,
      'duration_seconds': sosCountdown,
    });

    return showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CountdownDialog(
        sosCountdown: sosCountdown,
        triggerType: triggerType,
      ),
    );
  }

  /// Record and save video locally
  static Future<String?> recordVideo({
    int seconds = 15,
    bool useFront = true,
  }) async {
    try {
      debugPrint('$_tag: Recording video for $seconds seconds...');
      final path = await MediaRecorder.recordVideo(seconds: seconds);

      if (path.isEmpty) {
        debugPrint('$_tag: ⚠️ Recording returned empty path');
        return null;
      }

      final saved = await VideoStorageService.saveVideo(File(path));
      debugPrint('$_tag: Video saved: ${saved.path}');
      return saved.path;
    } catch (e) {
      debugPrint('$_tag: ❌ Recording failed: $e');
      return null;
    }
  }

  /// Get saved video files
  static Future<List<File>> getSavedVideos() async {
    try {
      final dir = await VideoStorageService.getSosVideoDir();
      if (!dir.existsSync()) return [];
      return dir.listSync().whereType<File>().toList();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Failed to get saved videos: $e');
      return [];
    }
  }

  // ============ Private helpers ============

  static Future<String> _getLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    } catch (e) {
      debugPrint('$_tag: ⚠️ Failed to get location: $e');
      return 'Location unavailable';
    }
  }

  static String _buildMessage({
    required bool isSafe,
    required String location,
    required String medicalInfo,
    required bool hasVideo,
    bool isBackground = false,
  }) {
    if (isSafe) {
      return '✅ False Alarm - I am SAFE\n'
          'Time: ${DateTime.now()}\n'
          'Location: $location';
    }

    String trigger = isBackground ? 'Fall detected' : 'SOS activated';
    Map<String, dynamic> medMap = {};
    try {
      medMap = jsonDecode(medicalInfo) as Map<String, dynamic>;
    } catch (_) {}

    return '🆘 URGENT SOS ALERT\n'
        'Trigger: $trigger\n'
        'Time: ${DateTime.now()}\n'
        'Location: $location\n'
        'Video: ${hasVideo ? 'Yes' : 'No'}\n'
        '${medMap.isNotEmpty ? '\nBlood Group: ${medMap['bloodGroup'] ?? 'N/A'}\n' : ''}'
        '${medMap.isNotEmpty ? 'Allergies: ${medMap['allergies'] ?? 'None'}\n' : ''}'
        'Please help immediately!';
  }

  static Future<bool> _sendViaBackendEmail({
    required List<String> emailRecipients,
    required String message,
    required List<String>? videoPaths,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backendUrl = prefs.getString('sosBackendUrl');

      if (backendUrl == null || backendUrl.isEmpty) {
        debugPrint('$_tag: ⚠️ No backend URL configured');
        return false;
      }

      final uri = Uri.parse('$backendUrl/send-email');
      final request = http.MultipartRequest('POST', uri);

      // Add email recipients (now only strings, not contact objects)
      for (final email in emailRecipients) {
        if (email.isNotEmpty) {
          request.fields['contacts[]'] = email;
        }
      }

      request.fields['message'] = message;

      // If there are video paths, decide whether to attach or upload links
      if (videoPaths != null && videoPaths.isNotEmpty) {
        final sizeMb = await _totalSizeMB(videoPaths);
        debugPrint(
            '$_tag: Total attachments size ${sizeMb.toStringAsFixed(2)} MB');
        if (sizeMb <= 20.0) {
          for (final p in videoPaths) {
            if (File(p).existsSync()) {
              request.files.add(await http.MultipartFile.fromPath('files', p));
            }
          }
        } else {
          // Upload files and send links instead
          final links = await _uploadFilesToBackend(videoPaths);
          if (links.isNotEmpty) {
            request.fields['links'] = jsonEncode(links);
          } else {
            debugPrint(
                '$_tag: ⚠️ Upload returned no links; attempting without attachments');
          }
        }
      }

      final streamed =
          await request.send().timeout(const Duration(seconds: 30));
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        debugPrint('$_tag: ✅ Email sent via backend');
        return true;
      } else {
        debugPrint('$_tag: ⚠️ Backend returned ${resp.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Email send failed: $e');
      return false;
    }
  }

  static Future<double> _totalSizeMB(List<String> paths) async {
    double total = 0.0;
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) {
          total += await f.length() / (1024 * 1024);
        }
      } catch (_) {}
    }
    return total;
  }

  static Future<List<String>> _uploadFilesToBackend(List<String> paths) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backendUrl = prefs.getString('sosBackendUrl');
      if (backendUrl == null || backendUrl.isEmpty) return [];
      final uri = Uri.parse('$backendUrl/upload_recording');
      final request = http.MultipartRequest('POST', uri);
      for (final p in paths) {
        if (File(p).existsSync()) {
          request.files.add(await http.MultipartFile.fromPath('files', p));
        }
      }
      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        try {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map && decoded['links'] is List) {
            return List<String>.from(decoded['links']);
          }
          if (decoded is List) return List<String>.from(decoded);
        } catch (e) {
          debugPrint('$_tag: ⚠️ Failed to parse upload response: $e');
        }
      } else {
        debugPrint('$_tag: ⚠️ Upload endpoint returned ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Upload failed: $e');
    }
    return [];
  }

  static Future<bool> _sendViaSMS({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      if (phoneNumbers.isEmpty) {
        debugPrint('$_tag: ⚠️ No phone numbers provided');
        return false;
      }
      // Use platform SMS intent (smsto:) so user explicitly sends the message.
      try {
        final uri = Uri(
          scheme: 'smsto',
          path: phoneNumbers.join(';'),
          queryParameters: {'body': message},
        );
        debugPrint('$_tag: Opening SMS URI: $uri');
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) debugPrint('$_tag: ⚠️ Failed to launch SMS intent');
        return launched;
      } catch (e) {
        debugPrint('$_tag: ❌ Error launching SMS intent: $e');
        return false;
      }
    } catch (e) {
      debugPrint('$_tag: ❌ SMS send exception: $e');
      return false;
    }
  }

  /// Send email with videos via backend (for SOS controller)
  static Future<bool> sendEmailWithVideos({
    required BuildContext context,
    required List<String> emailRecipients,
    required String message,
    required List<String> videoPaths,
  }) async {
    try {
      debugPrint(
          '$_tag: sendEmailWithVideos - ${emailRecipients.length} recipients, ${videoPaths.length} videos');

      final prefs = await SharedPreferences.getInstance();
      final backendUrl = prefs.getString('sosBackendUrl') ?? ApiConfig.baseUrl;

      if (backendUrl.isEmpty) {
        debugPrint('$_tag: ⚠️ No backend URL configured for email');
        return false;
      }

      // Use the existing backend email sending logic
      final success = await _sendViaBackendEmail(
        emailRecipients: emailRecipients,
        message: message,
        videoPaths: videoPaths,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Email sent with videos'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Email failed to send'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return success;
    } catch (e) {
      debugPrint('$_tag: ❌ sendEmailWithVideos exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error sending email: $e'),
            backgroundColor: Colors.red),
      );
      return false;
    }
  }
}

/// Countdown dialog widget with pulse + beep
class _CountdownDialog extends StatefulWidget {
  final int sosCountdown;
  final String triggerType;

  const _CountdownDialog({
    required this.sosCountdown,
    required this.triggerType,
  });

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog>
    with TickerProviderStateMixin {
  late int _remaining;
  late Timer _timer;
  late AnimationController _pulseController;
  bool _sendingNow = false;
  late SOSBeeper _beeper;

  @override
  void initState() {
    super.initState();
    _remaining = widget.sosCountdown;
    _beeper = SOSBeeper();
    _setupPulseAnimation();
    _startCountdown();
    NotificationService.showSOSCountdownNotification(_remaining);
  }

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remaining--;
        });

        // 🔊 Play beep
        _beeper.playBeep(_remaining);

        // 🔴 Pulse animation (1.15x scale then back)
        _pulseController.forward(from: 0.0);

        // Update notification with countdown
        NotificationService.showSOSCountdownNotification(_remaining);

        if (_remaining <= 0) {
          timer.cancel();
          NotificationService.clearSOSCountdown();
          if (mounted) {
            Navigator.pop(context, true); // auto-send
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _beeper.stop();
    NotificationService.clearSOSCountdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulseScale = _pulseController.isAnimating
        ? 1.0 + (_pulseController.value * 0.15)
        : 1.0;

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        '🚨 SOS ALERT 🚨',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔴 Pulsing SOS circle
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return SOSPulse(scale: pulseScale);
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Sending in...',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 12),
          // Countdown number
          Text(
            '$_remaining',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Trigger: ${widget.triggerType}',
            style: TextStyle(color: Colors.grey[300], fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            '📹 Recording... (Front + Back cameras)',
            style: TextStyle(color: Colors.yellow[700], fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '🔊 Beeping + 📳 Vibrating',
            style: TextStyle(color: Colors.cyan[300], fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_sendingNow)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sendingNow
              ? null
              : () {
                  _timer.cancel();
                  _pulseController.dispose();
                  NotificationService.clearSOSCountdown();
                  // Reset risk to SAFE when user cancels
                  try {
                    RiskNotifier.instance.value = RiskLevel.safe;
                  } catch (_) {}
                  Navigator.pop(context, false); // cancel
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sendingNow
              ? null
              : () {
                  setState(() => _sendingNow = true);
                  _timer.cancel();
                  Navigator.pop(context, true); // send now
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Send Now', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
