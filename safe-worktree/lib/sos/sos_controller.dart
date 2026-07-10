// ignore_for_file: unused_element
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../core/ui_modes.dart';
import '../services/ui_mode_service.dart';
import 'package:silent_sos/services/media_recorder.dart';
import 'package:silent_sos/services/message_templates.dart';
import 'package:silent_sos/services/sos_message_builder.dart';
import 'package:silent_sos/services/sos_service.dart';
import 'package:silent_sos/services/analytics_service.dart';
import 'package:silent_sos/services/backend_service.dart';
import 'package:silent_sos/services/storage_service.dart';
import 'package:silent_sos/services/background_service.dart';
import 'package:silent_sos/services/email_service.dart';
import 'package:silent_sos/services/video_compression_service.dart';
import 'package:silent_sos/services/call_service.dart';
import 'package:silent_sos/services/live_tracking_service.dart';
import '../utils/native_email_sender.dart';
import '../utils/native_sms_sender.dart';
import '../core/risk_notifier.dart';
import '../models/risk_level.dart';
import '../models/call_settings.dart';
import '../config/api_config.dart';
import '../screens/fake_call_screen.dart';

/// GOLDEN RULE: Every SOS — manual / voice / fall — calls ONE function
/// This controller enforces a single pipeline and prevents duplicate entry points
class SosController {
  static bool _sosInProgress = false;
  static bool _cancelledByUser = false;
  static const String _tag = '🆘 SosController';

  // ========== PRODUCTION-SAFE LIFECYCLE SEQUENCING ==========
  // Use app lifecycle to guarantee SMS → Email → Video without intent overlap
  // NOTE: Removed resume-dependent flags. Flow now uses an awaited chain.
  static List<String> _recordedVideos = [];
  static String? _builtMessage;
  // ignore: unused_field
  static List<String> _phoneNumbers = [];
  static List<String> _emailRecipients = [];
  static Timer? _locationUpdateTimer;

  // Manual mode pending sequence helpers (SMS -> Email) to ensure both apps open.
  static bool _pendingEmailAfterSms = false;
  static final List<String> _pendingEmailRecipients = [];
  static final String _pendingEmailBody = '';

  // --- automatic mode preference helpers ------------------------------------------------
  static const String _autoModeKey = "auto_mode_enabled";
  // Notifier so UI can react to changes immediately
  static final ValueNotifier<bool> autoModeNotifier =
      ValueNotifier<bool>(false);

  /// Notifies UI when a silent countdown is active (disguised mode countdown).
  static final ValueNotifier<bool> silentCountdownActive =
      ValueNotifier<bool>(false);
  static Completer<bool>? _silentCountdownCompleter;
  static Timer? _silentCountdownTimer;

  // Live tracking helper to post updates to backend
  static final LiveTrackingService liveTracking = LiveTrackingService();

  static void cancelSilentCountdown() {
    if (_silentCountdownCompleter != null &&
        !_silentCountdownCompleter!.isCompleted) {
      _cancelledByUser = true;
      _silentCountdownCompleter!.complete(false);
      silentCountdownActive.value = false;
    }
    _silentCountdownTimer?.cancel();
    _silentCountdownTimer = null;
  }

  static Future<bool> isAutoModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool(_autoModeKey) ?? false;
    // keep notifier in sync
    try {
      autoModeNotifier.value = val;
    } catch (_) {}
    return val;
  }

  /// Determine whether the current UI mode should suppress visible countdown UI.
  static bool _isSilentMode(BuildContext context) {
    try {
      final uiService = Provider.of<UIModeService>(context, listen: false);
      return uiService.mode != AppUIMode.safety;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setAutoMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoModeKey, value);
    try {
      autoModeNotifier.value = value;
    } catch (_) {}
  }

  // simple helpers to read stored contacts/emails for backend payload
  static Future<List<String>> _fetchSmsContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('sos_contacts') ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> _fetchEmailRecipients() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('sos_email_recipients');
      if (list != null && list.isNotEmpty) return list;
      final jsonStr = prefs.getString('sos_email_recipients');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        return decoded
            .map((e) {
              if (e is String) {
                return e;
              }
              if (e is Map && e.containsKey('email')) {
                return e['email'] as String;
              }
              return '';
            })
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------------
  // HTTP helpers for AWS backend
  // ------------------------------------------------------------------
  static Future<Map<String, dynamic>> _getUploadUrl(String sessionId) async {
    final payload = jsonEncode({
      "sessionId": sessionId,
      "fileName": "live-video.mp4",
    });

    Future<http.Response> postTo(Uri endpoint) {
      return http.post(endpoint,
          headers: {"Content-Type": "application/json"}, body: payload);
    }

    // Try primary endpoint first, then fallback to local emulated endpoint.
    final primaryUri = Uri.parse(ApiConfig.generateUploadUrl);
    final fallbackUri = Uri.parse(ApiConfig.generateUploadUrlFallback);

    http.Response response;
    try {
      response = await postTo(primaryUri);
    } catch (e) {
      debugPrint('$_tag: ⚠️ _getUploadUrl primary host failed: $e');
      response = await postTo(fallbackUri);
    }

    if (response.statusCode != 200) {
      debugPrint('$_tag: ⚠️ _getUploadUrl failed status=${response.statusCode}');
      throw Exception("Failed to get upload URL");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> _uploadVideo(String uploadUrl, String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {"Content-Type": "video/mp4"},
      body: bytes,
    );
    if (response.statusCode != 200) {
      throw Exception("Video upload failed");
    }
  }

  static Future<void> _uploadVideoWithRetry(
      String uploadUrl, String filePath) async {
    Future<http.Response> attemptUpload() async {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return http.put(
        Uri.parse(uploadUrl),
        headers: {"Content-Type": "video/mp4"},
        body: bytes,
      );
    }

    try {
      // First attempt
      var response = await attemptUpload();
      if (response.statusCode == 200) {
        debugPrint('$_tag: ✅ Upload succeeded (first attempt)');
        return;
      }

      debugPrint('$_tag: ⚠️ Upload failed (first attempt). Retrying...');
      await Future.delayed(const Duration(seconds: 2));

      // Second attempt
      response = await attemptUpload();
      if (response.statusCode == 200) {
        debugPrint('$_tag: ✅ Upload succeeded (second attempt)');
        return;
      }

      debugPrint(
          '$_tag: ❌ Upload failed after retry: status=${response.statusCode}');
      throw Exception('Video upload failed after retry');
    } catch (e) {
      debugPrint('$_tag: ❌ Upload error: $e');
      rethrow;
    }
  }

  static Future<void> _sendSOS(
      String sessionId, List<String> videoKeys, BuildContext? context,
      {List<String>? directVideoLinks}) async {
    Future<http.Response> sendRequest() async {
      final position = await Geolocator.getCurrentPosition();
      return http.post(
        Uri.parse(ApiConfig.sendSos),
        headers: {
          "Content-Type": "application/json",
          "x-app-secret": ApiConfig.appSecret,
        },
        body: jsonEncode({
          "sessionId": sessionId,
          "latitude": position.latitude,
          "longitude": position.longitude,
          "emails": await _fetchEmailRecipients(),
          "contacts": await _fetchSmsContacts(),
          "videoKeys": videoKeys,
        }),
      );
    }

    try {
      // First attempt
      var response = await sendRequest();
      if (response.statusCode == 200) {
        debugPrint(
            '$_tag: ✅ Backend SOS succeeded (first attempt) with ${videoKeys.length} video(s)');
        return;
      }

      debugPrint('$_tag: ⚠️ Backend failed (first attempt). Retrying...');
      await Future.delayed(const Duration(seconds: 2));

      // Second attempt
      response = await sendRequest();
      if (response.statusCode == 200) {
        debugPrint(
            '$_tag: ✅ Backend SOS succeeded (second attempt) with ${videoKeys.length} video(s)');
        return;
      }

      debugPrint(
          '$_tag: ❌ Backend failed after retry: status=${response.statusCode} body=${response.body}');
      throw Exception('SOS backend failed after retry');
    } catch (e) {
      debugPrint('$_tag: ❌ _sendSOS error: $e');
      await _attemptFallbackEmail(videoKeys, directVideoLinks);

      // Show failure snackbar only after both attempts fail
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('❌ Failed to send emergency alert. Please check network.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      rethrow;
    }
  }

  static Future<String> _resolveVideoUrl(String videoKey) async {
    if (videoKey.startsWith('http')) {
      // If it's already a URL, try to recover a clean key path and request a trusted download URL.
      try {
        final uri = Uri.parse(videoKey);
        final segments = uri.pathSegments;
        final index = segments.indexWhere((s) => s.toLowerCase() == 'videos');
        if (index != -1 && index + 1 < segments.length) {
          final keyPath = ['videos', ...segments.sublist(index + 1)].join('/');
          final signedFallback =
              await StorageService.getSignedDownloadUrl(keyPath);
          final downloadUrlFallback =
              signedFallback['downloadUrl'] as String? ?? '';
          if (downloadUrlFallback.isNotEmpty) {
            debugPrint(
                '$_tag: normalized signed URL from $videoKey to $downloadUrlFallback via key $keyPath');
            return downloadUrlFallback;
          }
        }
      } catch (e) {
        debugPrint(
            '$_tag: ⚠️ resolveVideoUrl HTTP input normalization failed for $videoKey: $e');
      }
      return videoKey;
    }

    try {
      final signed = await StorageService.getSignedDownloadUrl(videoKey);
      final downloadUrl = signed['downloadUrl'] as String? ?? '';
      final expiresIn = signed['expiresIn'] as int? ?? 86400;
      final expiresAt = signed['expiresAt'] as String? ?? '';
      if (downloadUrl.isNotEmpty) {
        debugPrint(
            '$_tag: resolved video key $videoKey to URL $downloadUrl (expiresIn=$expiresIn, expiresAt=$expiresAt)');
        return downloadUrl;
      }
    } catch (e) {
      debugPrint('$_tag: ⚠️ resolveVideoUrl failed for $videoKey: $e');
    }

    // Fallback: compose URL from known bucket location if backend signed endpoint is unavailable
    if (videoKey.startsWith('videos/')) {
      // Ensure no double slash, and use configured bucket host region.
      String base = ApiConfig.videoDownloadBaseUrl;
      if (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      final key = videoKey.replaceAll(RegExp(r'^/+'), '');
      final fallback = '$base/$key';
      debugPrint(
          '$_tag: resolveVideoUrl fallback from key ($videoKey) to $fallback');
      return fallback;
    }

    // Last-resort: if nothing resolved, return asset key as-is (likely fails).
    debugPrint(
        '$_tag: resolveVideoUrl no mapping for key ($videoKey), returning as-is');
    return videoKey;
  }

  static Future<void> _attemptFallbackEmail(List<String> videoKeys,
      [List<String>? directVideoLinks]) async {
    final emails = await _fetchEmailRecipients();
    if (emails.isEmpty) {
      debugPrint('$_tag: ⚠️ Fallback: no email recipients');
      return;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('$_tag: ⚠️ Fallback location fetch failed: $e');
      position = null;
    }

    final locationUrl = position != null
        ? 'https://maps.google.com/?q=${position.latitude},${position.longitude}'
        : 'Location unavailable';
    final time = DateTime.now().toString();

    for (final email in emails) {
      try {
        await EmailService.sendLocation(
          toEmail: email,
          location: locationUrl,
          time: time,
          message: 'Fallback emergency alert - backend unreachable',
        );
        debugPrint('$_tag: ✅ Fallback location email sent to $email');
      } catch (e) {
        debugPrint('$_tag: ❌ Fallback location email failed for $email: $e');
      }

      // Collect all resolved video URLs (prefer precomputed/direct links)
      final resolvedUrls = <String>[];
      if (directVideoLinks != null && directVideoLinks.isNotEmpty) {
        for (final link in directVideoLinks) {
          if (link.startsWith('http')) {
            resolvedUrls.add(link);
          } else {
            resolvedUrls.add(await _resolveVideoUrl(link));
          }
        }
      } else {
        for (final videoKey in videoKeys) {
          final videoUrl = await _resolveVideoUrl(videoKey);
          resolvedUrls.add(videoUrl);
        }
      }

      if (resolvedUrls.isNotEmpty) {
        final frontVideo = resolvedUrls[0];
        final backVideo = resolvedUrls.length > 1 ? resolvedUrls[1] : '';
        try {
          await EmailService.sendVideoEmail(
            toEmail: email,
            frontVideo: frontVideo,
            backVideo: backVideo,
            location: locationUrl,
            time: time,
            message:
                'Fallback video evidence from auto SOS - links valid for 24 hours',
          );
          debugPrint(
              '$_tag: ✅ Fallback video email sent to $email for $resolvedUrls');
        } catch (e) {
          debugPrint('$_tag: ❌ Fallback video email failed for $email: $e');
        }
      }
    }
  }

  /// Trigger vibration pattern for SOS alerts
  /// Pattern: 200ms vibrate + 100ms pause + 200ms vibrate (urgent alert pattern)
  static Future<void> _triggerVibrationPattern() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // SOS vibration pattern: urgent alert
        await Vibration.vibrate(
          duration: 200,
          amplitude: 255, // Max amplitude
        );
        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(
          duration: 200,
          amplitude: 255,
        );
        debugPrint('$_tag: ✅ Vibration triggered');
      }
    } catch (e) {
      debugPrint('$_tag: ⚠️ Vibration error: $e');
    }
  }

  /// Automatically trigger fake call with configured delay
  static Future<void> _triggerFakeCallAuto(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fakeCallDelay = prefs.getInt('fake_call_delay') ?? 3;
      
      debugPrint('$_tag: ⏱️ Scheduling fake call in ${fakeCallDelay}s...');
      
      // Wait for configured delay before showing fake call
      await Future.delayed(Duration(seconds: fakeCallDelay));
      
      if (context.mounted) {
        debugPrint('$_tag: 📞 Triggering fake call screen');
        await AnalyticsService.logEvent('fake_call_auto_triggered', parameters: {
          'delay_seconds': fakeCallDelay,
        });
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const FakeCallScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('$_tag: ⚠️ Fake call auto-trigger error: $e');
    }
  }

  /// AUTO FLOW — Backend Only (No App Opens)
  /// Record → Upload → Call Backend → Silent Send
  static Future<void> executeAutoFlow(
      BuildContext context, String source) async {
    debugPrint('$_tag: 🤖 AUTO flow (backend + upload)');

    try {
      // Determine recording duration (keep shorter for faster delivery)
      final prefs = await SharedPreferences.getInstance();
      final countdown = prefs.getInt('sosTimerDuration') ?? 10;
      final recordSeconds = countdown.clamp(8, 15).toInt();

      // 1️⃣ Record videos (best effort; continue even if recording fails)
      final videoPaths = <String>[];
      try {
        final recordedPaths =
            await MediaRecorder.recordSequentialVideos(seconds: recordSeconds);
        if (recordedPaths.isNotEmpty) {
          videoPaths.addAll(recordedPaths);
        }
      } catch (e) {
        debugPrint('$_tag: ⚠️ Video recording unavailable, continuing without video: $e');
      }

      if (videoPaths.isEmpty) {
        debugPrint('$_tag: ⚠️ No videos recorded; continuing with alert without video attachments');
      } else {
        debugPrint('$_tag: ✅ Videos recorded: $videoPaths');
      }

      // 2️⃣ Upload videos and gather keys for backend
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final videoKeys = <String>[];
      final videoLinks = <String>[];

      for (var i = 0; i < videoPaths.length; i++) {
        final videoPath = videoPaths[i];
        try {
          // Compress video (best effort)
          File? compressed = await VideoCompressionService.compress(videoPath);
          if (compressed == null) {
            debugPrint(
                '$_tag: ⚠️ Compression failed for $videoPath, using original');
            compressed = File(videoPath);
          }

          // Request signed upload URL from backend (best effort only)
          final filename =
              '${sessionId}_$i${path.extension(compressed.path).isEmpty ? '.mp4' : ''}';
          String? uploadUrl;
          String? videoKey;
          String? publicUrl;

          try {
            final signed =
                await StorageService.getSignedUploadUrl(sessionId, filename);
            uploadUrl = signed['uploadUrl'] as String? ?? '';
            videoKey = signed['videoKey'] as String? ?? '';
            publicUrl = signed['publicUrl'] as String?;
          } catch (e) {
            debugPrint('$_tag: ⚠️ Signed URL request failed for $videoPath: $e');
          }

          if ((uploadUrl?.isNotEmpty ?? false) && (videoKey?.isNotEmpty ?? false)) {
            try {
              await StorageService.uploadFileWithSignedUrl(compressed, uploadUrl!);
              final resolvedDownloadUrl = (publicUrl?.isNotEmpty ?? false)
                  ? publicUrl!
                  : await _resolveVideoUrl(videoKey!);

              debugPrint(
                  '$_tag: ✅ Uploaded video $i (key=$videoKey, uploadUrl=$uploadUrl, resolvedDownloadUrl=$resolvedDownloadUrl)');

              videoKeys.add(videoKey!);
              videoLinks.add(resolvedDownloadUrl);
            } catch (e) {
              debugPrint('$_tag: ❌ Upload failed for $videoPath: $e');
            }
          } else {
            debugPrint('$_tag: ⚠️ Skipping upload for $videoPath because no signed URL was available');
          }
        } catch (e) {
          debugPrint('$_tag: ❌ Upload failed for $videoPath: $e');
        }
      }

      // 3️⃣ Notify backend (sends SMS/email based on stored recipients)
      await _sendSOS(sessionId, videoKeys, context,
          directVideoLinks: videoLinks);

      // 4️⃣ Send direct emails as confirmation (backup if backend doesn't send)
      try {
        final emailRecipients = await _fetchEmailRecipients();
        final position = await Geolocator.getCurrentPosition();
        final locationUrl =
            'https://maps.google.com/?q=${position.latitude},${position.longitude}';
        final time = DateTime.now().toString();

        if (emailRecipients.isNotEmpty) {
          debugPrint(
              '$_tag: 📧 Sending direct emails to ${emailRecipients.length} recipients (auto-flow)');

          for (final email in emailRecipients) {
            try {
              await EmailService.sendLocation(
                toEmail: email,
                location: locationUrl,
                time: time,
                message: 'Emergency SOS Alert - Location attached',
              );
              debugPrint('$_tag: ✅ Direct location email sent to $email');
            } catch (e) {
              debugPrint(
                  '$_tag: ❌ Direct location email failed for $email: $e');
            }

            // Use direct upload URLs from the upload stage (publicUrl or signed uploadUrl)
            final resolvedUrls = <String>[];
            for (final videoLink in videoLinks) {
              if (videoLink.startsWith('http')) {
                resolvedUrls.add(videoLink);
              } else {
                final resolvedUrl = await _resolveVideoUrl(videoLink);
                resolvedUrls.add(resolvedUrl);
              }
            }

            if (resolvedUrls.isNotEmpty) {
              final frontVideo = resolvedUrls[0];
              final backVideo = resolvedUrls.length > 1 ? resolvedUrls[1] : '';
              try {
                await EmailService.sendVideoEmail(
                  toEmail: email,
                  frontVideo: frontVideo,
                  backVideo: backVideo,
                  location: locationUrl,
                  time: time,
                  message:
                      'Emergency SOS Alert - Video evidence attached\n\n⏱️ Links expire in 24 hours',
                );
                debugPrint(
                    '$_tag: ✅ Direct video email sent to $email (videos=$resolvedUrls)');
              } catch (e) {
                debugPrint('$_tag: ❌ Direct video email failed for $email: $e');
              }
            }
          }
        } else {
          debugPrint('$_tag: ⚠️ No email recipients for direct send');
        }
      } catch (e) {
        debugPrint('$_tag: ⚠️ Direct email sending error (auto-flow): $e');
      }

      // 5️⃣ Sequential calling engine (after SMS/Email/Backend)
      try {
        // Load phone contacts from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final phoneContacts = prefs.getStringList('sos_contacts') ?? [];

        if (phoneContacts.isNotEmpty) {
          debugPrint('$_tag: 📞 Starting sequential call engine with ${phoneContacts.length} contacts...');

          CallSettings callSettings = CallSettings(
            retryCount: 1,      // retry once if failed
          );

          await CallService.callSequence(
            contacts: phoneContacts,
            settings: callSettings,
          );

          debugPrint('$_tag: ✅ Call sequence completed');
        } else {
          debugPrint('$_tag: ℹ️ No phone contacts configured for calling, showing fake call escape screen');
          // Show fake call only when no contacts configured
          await _triggerFakeCallAuto(context);
        }
      } catch (e) {
        debugPrint('$_tag: ⚠️ Call engine error (non-blocking): $e');
      }

      // Show success snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Emergency alert sent automatically'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Auto flow error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Auto-send failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Background upload handler. Non-blocking; must not throw.
  static Future<void> _handleVideoUpload({
    required String sessionId,
    required List<String> videoPaths,
    required List<String> emailRecipients,
    BuildContext? context,
  }) async {
    if (videoPaths.isEmpty) {
      debugPrint('$_tag: ℹ️ No videos to upload');
      return;
    }

    try {
      final uploadedUrls = <String>[];

      for (int i = 0; i < videoPaths.length; i++) {
        try {
          final file = File(videoPaths[i]);
          final filename = '${sessionId}_$i.mp4';
          String? uploadUrl;
          String? publicUrl;

          try {
            final signed =
                await StorageService.getSignedUploadUrl(sessionId, filename);
            uploadUrl = signed['uploadUrl'] as String? ?? '';
            publicUrl = signed['publicUrl'] as String?;
          } catch (e) {
            debugPrint('$_tag: ⚠️ Background signed URL request failed: $e');
          }

          if ((uploadUrl?.isNotEmpty ?? false)) {
            try {
              await StorageService.uploadFileWithSignedUrl(file, uploadUrl!);
              uploadedUrls.add(publicUrl ?? uploadUrl!);
              debugPrint(
                  '$_tag: ✅ Background uploaded video: ${publicUrl ?? uploadUrl!}');
            } catch (e) {
              debugPrint('$_tag: ⚠️ Background upload failed for ${videoPaths[i]}: $e');
            }
          } else {
            debugPrint('$_tag: ⚠️ Background upload skipped for ${videoPaths[i]} because no signed URL was available');
          }
        } catch (e) {
          debugPrint(
              '$_tag: ⚠️ Background upload failed for ${videoPaths[i]}: $e');
        }
      }

      if (uploadedUrls.isEmpty) {
        debugPrint(
            '$_tag: ⚠️ Video upload failed (background). Alert already delivered.');
        if (context != null && context.mounted) {
          _showAutoFlowSnackbar(
              context,
              '⚠ Video upload failed. Alert was still delivered.',
              Colors.orange);
        }
        return;
      }

      // Send follow-up email with video URLs
      try {
        final time = DateTime.now().toString();
        for (final email in emailRecipients) {
          try {
            final frontVideo = uploadedUrls.isNotEmpty ? uploadedUrls[0] : '';
            final backVideo = uploadedUrls.length > 1 ? uploadedUrls[1] : '';
            await EmailService.sendVideoEmail(
              toEmail: email,
              frontVideo: frontVideo,
              backVideo: backVideo,
              location: '',
              time: time,
              message: 'Video evidence attached',
            );
            debugPrint('$_tag: ✅ Video email sent to $email for $uploadedUrls');
          } catch (e) {
            debugPrint('$_tag: ❌ Video email failed for $email: $e');
          }
        }
        if (context != null && context.mounted) {
          _showAutoFlowSnackbar(
              context, '🎥 Video evidence sent successfully', Colors.blue);
        }
      } catch (e) {
        debugPrint('$_tag: ⚠️ Video email failed: $e');
        if (context != null && context.mounted) {
          _showAutoFlowSnackbar(
              context,
              '⚠ Video upload failed. Alert was still delivered.',
              Colors.orange);
        }
      }
    } catch (e) {
      debugPrint('$_tag: ⚠️ _handleVideoUpload exception: $e');
    }
  }

  /// Show snackbar for auto flow notifications
  static void _showAutoFlowSnackbar(
      BuildContext? context, String message, Color bgColor) {
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// UNIFIED SOS TRIGGER — Router Only
  /// All entry points (manual SOS tap, voice "SOS", fall detection) call this
  static Future<void> triggerSOS({
    required BuildContext context,
    required String source, // 'manual' | 'voice' | 'fall'
    bool? silent,
  }) async {
    // Auto-determine if countdown should be hidden based on current UI mode.
    final resolvedSilent = silent ?? _isSilentMode(context);
    if (_sosInProgress) {
      debugPrint(
          '$_tag: SOS already in progress, ignoring duplicate trigger from $source');
      return;
    }

    _sosInProgress = true;
    _cancelledByUser = false;

    try {
      // Stop any ongoing voice/greeting audio
      try {
        await FlutterTts().stop();
      } catch (_) {}

      // Immediately trigger vibration pattern on SOS start
      _triggerVibrationPattern();

      // Notify UI globally about emergency risk (best-effort)
      try {
        RiskNotifier.set(RiskLevel.emergency);
      } catch (_) {}

      debugPrint('$_tag: ✅ SOS TRIGGERED by $source');

      // Show countdown UI — if cancelled, abort.
      final countdownCompleted = await _showCountdown(
        context: context,
        source: source,
        silent: resolvedSilent,
        onCancel: () {
          _cancelledByUser = true;
          _sosInProgress = false;
        },
      );

      if (!countdownCompleted || _cancelledByUser) {
        debugPrint('$_tag: 🔕 SOS cancelled during countdown');
        _sosInProgress = false;
        return;
      }

      // Start live background tracking right after countdown completes
      try {
        liveTracking.startTracking();
        // BackgroundService.start(); // Temporarily disabled to test if it causes crash
        debugPrint('$_tag: 🚀 Live tracking started (foreground+background)');
      } catch (e) {
        debugPrint('$_tag: ⚠️ Failed to start live tracking: $e');
      }

      // Route to manual or auto based on user preference
      final autoMode = await isAutoModeEnabled();
      if (autoMode) {
        await executeAutoFlow(context, source);
      } else {
        await executeManualFlow(context, source);
      }
    } catch (e) {
      debugPrint('$_tag: ❌ triggerSOS error: $e');
    } finally {
      liveTracking.stopTracking();
      _sosInProgress = false;
      _resetSosFlow();
    }
  }

  /// MANUAL FLOW — Pure Old Behavior (No Backend Calls)
  /// Open SMS + Email apps. User manually sends.
  static Future<void> executeManualFlow(
      BuildContext context, String source) async {
    debugPrint('$_tag: 📱 MANUAL flow (no backend)');

    // 1️⃣ Record videos
    List<String> videoPaths = [];
    try {
      videoPaths = await MediaRecorder.recordSequentialVideos(seconds: 20);
      debugPrint('$_tag: ✅ Videos recorded: $videoPaths');
      _recordedVideos = videoPaths;
    } catch (e) {
      debugPrint('$_tag: ⚠️ Recording failed: $e');
    }

    // 2️⃣ Build message and load contacts
    try {
      _builtMessage = await _loadTemplateFromPrefs();
      _builtMessage = await SosMessageBuilder.buildWithLocation(source: source);
    } catch (e) {
      debugPrint('$_tag: ⚠️ Failed to build message: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _phoneNumbers = prefs.getStringList('sos_contacts') ?? [];
      // load emails (handle JSON or list)
      final emailList = prefs.getStringList('sos_email_recipients');
      if (emailList != null && emailList.isNotEmpty) {
        _emailRecipients = emailList;
      } else {
        final emailsJson = prefs.getString('sos_email_recipients');
        if (emailsJson != null && emailsJson.isNotEmpty) {
          try {
            final decoded = jsonDecode(emailsJson) as List<dynamic>;
            _emailRecipients = decoded
                .map((e) => e is String
                    ? e
                    : (e is Map && e.containsKey('email')
                        ? e['email'] as String
                        : ''))
                .where((e) => e.isNotEmpty)
                .toList();
          } catch (_) {
            _emailRecipients = [];
          }
        }
      }
    } catch (e) {
      debugPrint('$_tag: ⚠️ Failed to load contacts: $e');
    }

    // open SMS and email apps simultaneously for manual flow
    try {
      if (_phoneNumbers.isNotEmpty) {
        await SOSservice.openSmsApp(
          phoneNumbers: _phoneNumbers,
          message: _builtMessage ?? 'Emergency! Need help now.',
        );
        debugPrint('$_tag: ✅ SMS app opened for manual flow');
      }
    } catch (e) {
      debugPrint('$_tag: ⚠️ Error opening SMS app: $e');
    }

    // open the email app simultaneously (don't wait for SMS)
    if (videoPaths.isNotEmpty && _emailRecipients.isNotEmpty) {
      try {
        await _openEmailWithMessage(
          context: context,
          emailRecipients: _emailRecipients,
          message: _builtMessage ?? '',
          videoPaths: videoPaths,
        );
        debugPrint('$_tag: ✅ Email app opened simultaneously for manual flow');
      } catch (e) {
        debugPrint('$_tag: ⚠️ Error opening email app: $e');
      }
    }

    // 🔥 restore manual share banner after the user has had both apps opened
    try {
      await _showPostSosBottomSheet(context, videoPaths);
    } catch (e) {
      debugPrint('$_tag: ⚠️ Failed to show manual share banner: $e');
    }

    // 🌐 Send SOS to backend
    try {
      final position = await Geolocator.getCurrentPosition();
      await BackendService.sendSOS(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      debugPrint('$_tag: ✅ SOS sent to backend');
    } catch (e) {
      debugPrint('$_tag: ⚠️ Failed to send SOS to backend: $e');
    }

    // No backend calls in manual flow — user manually sends via opened apps
    debugPrint('$_tag: ✅ Manual flow complete (apps opened for user to send)');
  }

  /// ========= PRODUCTION-SAFE LIFECYCLE HANDLER ==========
  /// Called from main.dart didChangeAppLifecycleState(resumed)
  /// Ensures: SMS → (user returns) → Email → (user returns) → Video share
  /// No overlapping intents, no focus stealing
  static Future<void> handleAppResume() async {
    debugPrint('$_tag: 📱 App resumed - checking pending manual flow actions');

    if (_pendingEmailAfterSms && _pendingEmailRecipients.isNotEmpty) {
      _pendingEmailAfterSms = false;
      final ctx = _getNavigatorContext();
      debugPrint('$_tag: 🔁 Resuming manual flow, opening email app');
      try {
        await _openEmailWithMessage(
          context: ctx,
          emailRecipients: _pendingEmailRecipients,
          message: _pendingEmailBody,
          videoPaths: _recordedVideos,
        );
      } catch (e) {
        debugPrint('$_tag: ⚠️ Error opening pending email app: $e');
      }
    }
  }

  /// Reset all SOS flow state
  static void _resetSosFlow() {
    _recordedVideos = [];
    _builtMessage = null;
    _phoneNumbers = [];
    _emailRecipients = [];
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    liveTracking.stopTracking();
    BackgroundService.stop();
    debugPrint('$_tag: 🔄 SOS flow state reset');
  }

  /// Get navigator context safely
  static BuildContext? _getNavigatorContext() {
    try {
      // Try to get from navigatorKey first
      return GlobalKey<NavigatorState>().currentContext;
    } catch (_) {
      return null;
    }
  }

  /// Start live location updates via SMS
  static void _startLiveLocationUpdates(List<String> phoneNumbers) {
    debugPrint(
        '$_tag: 🚀 Starting live location updates every 5 minutes for 30 minutes');
    _locationUpdateTimer =
        Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (timer.tick > 6) {
        // 30 minutes (6 * 5min)
        timer.cancel();
        debugPrint('$_tag: ⏹️ Live location updates stopped');
        return;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        final updateMessage = "🚨 LIVE LOCATION UPDATE 🚨\n"
            "I'm still in emergency. Current location:\n"
            "https://maps.google.com/maps?q=${position.latitude},${position.longitude}\n"
            "Lat: ${position.latitude}, Lng: ${position.longitude}";

        // Use native SMS sender to actually send without user interaction
        if (await Permission.sms.isGranted) {
          await NativeSMSSender.sendSMS(
              phoneNumbers: phoneNumbers, message: updateMessage);
          debugPrint('$_tag: 📍 Sent location update ${timer.tick}/6');
        }
      } catch (e) {
        debugPrint('$_tag: ❌ Live location update error: $e');
      }
    });
  }

  /// Execute post-recording flow in strict sequence: SMS -> Email -> Video
  /// This does not depend on app lifecycle or resume events.
  static Future<void> _executePostRecordingFlow(
      {required BuildContext? context}) async {
    try {
      final phones = List<String>.from(_phoneNumbers);
      final emails = List<String>.from(_emailRecipients);
      final message = _builtMessage ?? '';

      // 1) SMS send
      if (phones.isNotEmpty) {
        try {
          await NativeSMSSender.sendSMS(phoneNumbers: phones, message: message);
          debugPrint('$_tag: ✅ Silent SMS sent to ${phones.length} contacts');
          _startLiveLocationUpdates(phones);
        } catch (e) {
          debugPrint('$_tag: ⚠️ Silent SMS send failed: $e');
        }
      }

      // 2) Email send (EmailJS primary, AWS fallback). Send location immediately.
      if (emails.isNotEmpty) {
        try {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
                locationSettings:
                    const LocationSettings(accuracy: LocationAccuracy.high));
          } catch (_) {
            pos = null;
          }

          final locationUrl = pos != null
              ? 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}'
              : 'Location unavailable';
          final time = DateTime.now().toString();

          for (final email in emails) {
            try {
              await EmailService.sendLocation(
                toEmail: email,
                location: locationUrl,
                time: time,
                message: message,
              );
              debugPrint('$_tag: ✅ Location email sent to $email');
            } catch (e) {
              debugPrint('$_tag: ❌ Location email failed for $email: $e');
            }
          }

          // Start background upload and follow-up (do not await)
          Future.microtask(() async {
            await _handleVideoUpload(
                sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
                videoPaths: _recordedVideos,
                emailRecipients: emails,
                context: context);
          });
        } catch (e) {
          debugPrint('$_tag: ⚠️ Email send failed: $e');
        }
      }

      // Final success dialog — show only after SMS, Email complete (video upload happens in background)
      try {
        await _showFinalSuccessDialog(context);
      } catch (e) {
        debugPrint('$_tag: ❌ Final success dialog failed: $e');
      }
    } catch (e) {
      debugPrint('$_tag: ❌ Sequential post-recording flow error: $e');
    } finally {
      _resetSosFlow();
    }
  }

  /// Modern bottom sheet for optional post-SOS sharing (WhatsApp + Videos)
  /// Shown AFTER SMS and Email complete - no blocking, premium UX
  static Future<void> _showPostSosBottomSheet(
      BuildContext? context, List<String> videoPaths) async {
    if (context == null || !context.mounted || videoPaths.isEmpty) {
      debugPrint(
          '$_tag: ⚠️ Cannot show bottom sheet - context unavailable or no videos');
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 12),
              const Text(
                '🚨 Emergency Alert Sent Successfully',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your trusted contacts have been notified. Would you like to share the recorded video via other apps?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        debugPrint('$_tag: User skipped video share');
                      },
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _shareBothVideosExplicitly(videoPaths);
                      },
                      child: const Text('Share Videos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  /// Load SOS message template from SharedPreferences (user selects in Settings)

  static Future<String> _loadTemplateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('sos_message_template') ??
          SosTemplates.getDefault();
    } catch (_) {
      return SosTemplates.getDefault();
    }
  }

  /// Show countdown dialog
  /// Returns true if countdown completed, false if cancelled
  static Future<bool> _showCountdown({
    required BuildContext context,
    required String source,
    bool silent = false,
    required VoidCallback onCancel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final countdownSeconds = prefs.getInt('sosTimerDuration') ?? 10;

    if (silent) {
      debugPrint(
          '$_tag: Silent countdown for $countdownSeconds seconds (source: $source)');
      _cancelledByUser = false;
      silentCountdownActive.value = true;

      _silentCountdownCompleter = Completer<bool>();
      _silentCountdownTimer?.cancel();
      _silentCountdownTimer = Timer(Duration(seconds: countdownSeconds), () {
        if (!(_silentCountdownCompleter?.isCompleted ?? true)) {
          _silentCountdownCompleter?.complete(true);
        }
      });

      final result =
          await (_silentCountdownCompleter?.future ?? Future.value(false));
      silentCountdownActive.value = false;
      _silentCountdownTimer?.cancel();
      _silentCountdownTimer = null;
      _silentCountdownCompleter = null;
      return result;
    }

    debugPrint(
        '$_tag: Showing countdown for $countdownSeconds seconds (source: $source)');

    // Start vibration pattern on SOS trigger
    _triggerVibrationPattern();

    // Show countdown dialog
    int secondsLeft = countdownSeconds;
    bool cancelledDuringCountdown = false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setState) {
                // Start countdown timer
                if (secondsLeft > 0) {
                  Future.delayed(const Duration(seconds: 1), () {
                    if (secondsLeft > 0 && !cancelledDuringCountdown) {
                      setState(() {
                        secondsLeft--;
                      });
                      // Vibrate on each second countdown
                      _triggerVibrationPattern();
                    }
                    // If countdown reaches 0, close dialog automatically
                    if (secondsLeft == 0 &&
                        !cancelledDuringCountdown &&
                        Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(true);
                    }
                  });
                }

                return AlertDialog(
                  backgroundColor: Colors.red.shade900,
                  title: Text(
                    'SOS ALERT - $secondsLeft',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Triggered by: $source',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '🎥 Recording front + back cameras...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation(Colors.red),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      onPressed: () {
                        cancelledDuringCountdown = true;
                        onCancel();
                        Navigator.of(context).pop(false);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  /// Normalize phone number to E.164 format (essential for WhatsApp)
  static String _normalizePhone(String phone) {
    // Remove all non-digits
    phone = phone.replaceAll(RegExp(r'\D'), '');
    // If doesn't start with country code, assume India (91)
    if (!phone.startsWith('91')) {
      phone = '91$phone';
    }
    return phone;
  }

  /// Open SMS or WhatsApp based on availability and contact count
  /// WhatsApp only for 1 contact; SMS for 2+ or if WhatsApp unavailable
  static Future<void> _openSmsApp({
    required BuildContext context,
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      if (phoneNumbers.isEmpty) return;

      // Always open SMS using the native `smsto:` scheme. This avoids WhatsApp deep-link popups
      // and lets the platform choose the user's preferred messaging app.
      debugPrint(
          '$_tag: Opening SMS via smsto (${phoneNumbers.length} contacts)');
      await _openSmsUri(phoneNumbers, message);
    } catch (e) {
      debugPrint('$_tag: ❌ Error opening send app: $e');
      rethrow;
    }
  }

  // WhatsApp deep-link checks removed to avoid forcing WhatsApp and popups.

  /// Open SMS app with native Android intent - completely bypasses WhatsApp
  static Future<void> _openSmsUri(
    List<String> phoneNumbers,
    String message,
  ) async {
    try {
      // Use native Android SMS intent to completely avoid WhatsApp interception
      debugPrint(
          '$_tag: Opening SMS via native Android intent (${phoneNumbers.length} contacts)');
      await NativeSMSSender.sendSMS(
        phoneNumbers: phoneNumbers,
        message: message,
      );
    } catch (e) {
      debugPrint('$_tag: ❌ Error opening SMS: $e');

      // Fallback to url_launcher SMS scheme if native fails
      try {
        final uri = Uri(
          scheme: 'sms',
          path: phoneNumbers.join(';'),
          queryParameters: {
            'body': message,
          },
        );
        debugPrint('$_tag: Falling back to SMS URI: $uri');
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e2) {
        debugPrint('$_tag: ❌ Fallback SMS also failed: $e2');
        rethrow;
      }
    }
  }

  /// Open email app with message mentioning BOTH videos are saved locally
  /// Uses native Android Intent.ACTION_SENDTO for bulletproof reliability
  static Future<void> _openEmailWithMessage({
    required BuildContext? context,
    required List<String> emailRecipients,
    required String message,
    required List<String> videoPaths,
  }) async {
    if (context == null || !context.mounted) {
      debugPrint('$_tag: ⚠️ Cannot open email - context not available');
      return;
    }
    if (emailRecipients.isEmpty) {
      debugPrint('$_tag: ⚠️ Cannot open email - no recipients');
      return;
    }
    try {
      // Build email body mentioning BOTH videos are saved locally
      final emailBody = '''
$message

🎥 Safety Videos:
• Front camera video saved on device
• Back camera video saved on device

Please ask me to share the videos if needed.
''';

      debugPrint('$_tag: Opening email app with native Android Intent...');
      debugPrint('$_tag: Recipients: ${emailRecipients.join(", ")}');

      // ✅ CRITICAL: Use native Android Intent.ACTION_SENDTO
      // This is bulletproof and never silently fails
      // Unlike url_launcher mailto: which fails on many OEM devices
      await NativeEmailSender.openEmail(
        recipients: emailRecipients,
        subject: '🚨 EMERGENCY SOS ALERT',
        body: emailBody,
      );

      debugPrint(
          '$_tag: ✅ Email app opened successfully - waiting for user return for video share');

      // DO NOT call _offerBothVideosSharing here!
      // It will be called from handleAppResume() after user returns from email
    } catch (e) {
      debugPrint('$_tag: ❌ Email flow error: $e');
      rethrow; // Let caller handle the error
    }
  }

  /// Offer sharing BOTH videos as intentional user action
  /// Called from handleAppResume ONLY, after both SMS and Email have been completed
  static void _offerBothVideosSharing(
      BuildContext? context, List<String> videoPaths) {
    if (context == null || !context.mounted || videoPaths.isEmpty) {
      debugPrint(
          '$_tag: ⚠️ Cannot offer video sharing - context not mounted or no videos');
      return;
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (!context.mounted) return;

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🎥 Share Safety Videos?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Would you like to share the recorded safety videos?\n\n'
                'Both front and back camera videos are available:\n',
              ),
              ...videoPaths.asMap().entries.map((e) {
                final index = e.key;
                final path = e.value;
                final cameraLabel =
                    index == 0 ? '📱 Front Camera' : '🔙 Back Camera';
                return Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child:
                      Text('$cameraLabel: ${File(path).uri.pathSegments.last}'),
                );
              }),
              const SizedBox(height: 12),
              const Text(
                'You can send via WhatsApp, Drive, Gmail, or other apps.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                _shareBothVideosExplicitly(videoPaths);
              },
              child: const Text('Share All Videos'),
            ),
          ],
        ),
      );
    });
  }

  /// Final dialog confirming the emergency alert has been sent.
  /// This dialog is shown only after SMS, Email and optional video sharing steps complete.
  static Future<void> _showFinalSuccessDialog(BuildContext? context) async {
    if (context == null || !context.mounted) {
      debugPrint(
          '$_tag: ⚠️ Cannot show final success dialog - context unavailable');
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('✅ Emergency Alert Sent'),
          content: const Text(
              'Your emergency alert has been sent to your trusted contacts.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Share both videos with explicit user choice (not hijacked)
  /// Share both videos with explicit user choice (not hijacked)
  /// CRITICAL: Share ALL videos in ONE intent call → prevents Android from overriding previous share
  static Future<void> _shareBothVideosExplicitly(
      List<String> videoPaths) async {
    try {
      debugPrint(
          '$_tag: Sharing ${videoPaths.length} video(s) in ONE intent...');

      // Convert all valid video paths to XFile objects
      final xFiles = videoPaths
          .where((path) => File(path).existsSync())
          .map((path) => XFile(path))
          .toList();

      if (xFiles.isNotEmpty) {
        // Share ALL videos in single call (not loop) → prevents overlay/override
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          xFiles,
          text: '🚨 Emergency SOS safety videos',
        );
        debugPrint(
            '$_tag: ✅ All ${xFiles.length} video(s) shared in one intent');
      }
    } catch (e) {
      debugPrint('$_tag: ⚠️ Video share cancelled or failed: $e');
    }
  }
}
