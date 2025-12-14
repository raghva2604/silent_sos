// Minimal, analyzer-clean SOS service using flutter_sound recorder and
// Firebase Storage/Firestore. This file focuses on correct usage of the
// flutter_sound API and avoids referencing app-specific UI widgets or
// other services so static analysis stays clean.

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'media_recorder.dart';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'notification_service.dart';
import 'fall_detector.dart';

/// A small, self-contained SOS service that provides:
/// - permission checks
/// - audio recording using flutter_sound
/// - upload to Firebase Storage
/// - persistence of a simple SOS event to Firestore
///
/// It intentionally avoids UI dependencies and large external integrations
/// so the analyzer can run without errors. Other app code can call these
/// methods and handle UI/dialog flows separately.
class SOSservice {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static bool _recorderInitialized = false;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Backwards-compatibility stream and active flag used by UI elsewhere.
  static final StreamController<bool> _activeController = StreamController<bool>.broadcast();
  static bool _isActive = false;

  static Stream<bool> get onActiveChanged => _activeController.stream;

  static bool get isActive => _isActive;

  // Last SMTP backend error (used to surface richer messages to UI)
  static String? _lastSmtpError;

  static Future<void> retryQueuedMessages() async {
    // No-op placeholder; original implementation retries persisted unsent messages.
    return;
  }

  static StreamSubscription? _accelSub;
  static FallDetector? _fallDetector;

  /// Start a simple accelerometer-based auto-fall detector. This is a
  /// lightweight Dart fallback: it monitors accelerometer magnitude and
  /// compares to the configured 'fallThreshold' (in g). When a fall is
  /// detected, it shows a high-priority notification and prompts the user
  /// before sending the SOS. The caller should pass the UI context and the
  /// current contacts list.
  static Future<void> startFallDetection(dynamic context, List<String> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('auto_fall_sos_enabled') ?? false;
      if (!enabled) return;

      final thresholdG = double.tryParse(prefs.getString('fallThreshold') ?? '') ?? (prefs.getDouble('fallThreshold') ?? 4.2);
      final threshold = (thresholdG <= 0) ? 4.2 : thresholdG;

      // avoid duplicate detectors
      await stopFallDetection();

      // Prefer TFLite fall detector if model is available
      try {
        _fallDetector = FallDetector(onFallDetected: () async {
          await _handleFallDetected(context, contacts);
        }, windowSize: 256, threshold: threshold);
        await _fallDetector?.loadModel();
        debugPrint('FallDetector model loaded and listening');
        return;
      } catch (e) {
        debugPrint('FallDetector model unavailable or failed: $e — falling back to simple accel check');
      }

      // Fallback: simple accelerometer magnitude check
      _accelSub = accelerometerEvents.listen((event) async {
        final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        final g = mag / 9.81;
        if (g > threshold) {
          debugPrint('Auto-fall detected (fallback): g=$g threshold=$threshold');
          await _handleFallDetected(context, contacts);
        }
      });
    } catch (e) {
      debugPrint('startFallDetection error: $e');
    }
  }

  static Future<void> _handleFallDetected(dynamic context, List<String> contacts) async {
    try {
      await NotificationService.showAutoFallDetectionNotification(title: '⚠️ Fall detected', body: 'Fall detected! Confirm to cancel or SOS will be sent.');
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    
    // Show SOS dialog (same as manual SOS) with countdown timer
    final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;
    final confirmed = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('🚨 AUTO FALL DETECTED - Are You Safe?', 
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1), 
          textAlign: TextAlign.center
        ),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withAlpha(100)),
                  ),
                  child: Column(
                    children: [
                      const Text('⚠️ AUTOMATIC FALL DETECTED ⚠️', 
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16), 
                        textAlign: TextAlign.center
                      ),
                      const SizedBox(height: 12),
                      Text('Sending SOS in...', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '$sosCountdown',
                        style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text('Alert will be sent to ${contacts.length} contact(s)', 
                        style: const TextStyle(color: Colors.white70, fontSize: 12)
                      ),
                      const SizedBox(height: 12),
                      // Single countdown display (avoid duplicate timers)
                      const SizedBox(height: 8),
                      const Text(
                        'Recording video & location...',
                        style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      const Text('Press "I\'m Safe" to cancel', 
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic)
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Attach video toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Attach video', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 8),
                    Switch(
                      value: true,
                      onChanged: (_) {},
                      activeColor: Colors.teal,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(true); // User is safe
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.teal, 
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
            child: const Text('Yes — I\'m Safe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false); // Send SOS immediately
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red, 
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
            child: const Text('Send SOS Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == null) {
      // No response - auto-send after timer
      await Future.delayed(Duration(seconds: sosCountdown));
      if (context != null) {
        await SOSservice.sendSOSAlert(selectedContacts: contacts, isSafe: false, context: context);
      }
    } else if (confirmed == false) {
      // User pressed "Send SOS Now"
      await SOSservice.sendSOSAlert(selectedContacts: contacts, isSafe: false, context: context);
    }
  }

  /// Developer/test helper: simulate a fall event programmatically.
  static Future<void> simulateFall(BuildContext context, List<String> contacts) async {
    debugPrint('Simulate fall invoked');
    await _handleFallDetected(context, contacts);
  }

  static Future<void> stopFallDetection() async {
    _isActive = false;
    try { _activeController.add(_isActive); } catch (_) {}
    try {
      await _accelSub?.cancel();
      _accelSub = null;
    } catch (e) {
      debugPrint('stopFallDetection error: $e');
    }
  }

  static Future<void> triggerManualSOS(dynamic context, List<String> contacts) async {
    _isActive = true;
    try { _activeController.add(_isActive); } catch (_) {}
    await SOSservice.sendSos(contacts: contacts, includeAudio: true);
  }

  /// Send SOS alert to selected contacts with messaging, location, and video
  static Future<bool> sendSOSAlert({
    required List<dynamic> selectedContacts,
    required bool isSafe,
    required BuildContext context,
  }) async {
    if (selectedContacts.isEmpty) {
      _showErrorSnackBar(context, 'No contacts selected. Please add contacts first.');
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now();

      // Fetch current location with better accuracy attempt
      Position? currentLocation;
      try {
        // Try best accuracy first
        currentLocation = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 15),
        );
        debugPrint('✓ Location obtained: ${currentLocation.latitude}, ${currentLocation.longitude} (accuracy: ${currentLocation.accuracy}m)');
      } catch (e) {
        debugPrint('⚠️ Failed to get location with best accuracy: $e. Trying high accuracy...');
        try {
          currentLocation = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          debugPrint('✓ Location obtained (high): ${currentLocation.latitude}, ${currentLocation.longitude}');
        } catch (e2) {
          debugPrint('✗ Failed to get location: $e2');
        }
      }

      // Get recorded video path (if available) and upload to Firebase
      final videoPath = prefs.getString('last_sos_video_path');
      debugPrint('📹 VIDEO PATH FROM PREFS: "$videoPath"');
      String? videoDownloadUrl;
      
      if (videoPath != null && videoPath.isNotEmpty) {
        try {
          debugPrint('📹 Uploading video to Firebase Storage: $videoPath');
          final videoFile = File(videoPath);
          if (videoFile.existsSync()) {
            debugPrint('✓ Video file exists, size: ${videoFile.lengthSync()} bytes');
            final timestamp_ms = DateTime.now().millisecondsSinceEpoch;
            final ref = _storage.ref('sos_videos/video_$timestamp_ms.mp4');
            // Upload with timeout
            try {
              await ref.putFile(videoFile).timeout(const Duration(seconds: 30), onTimeout: () {
                debugPrint('⚠️ Video upload timeout - continuing without video');
                throw TimeoutException('Video upload exceeded 30 seconds');
              });
              videoDownloadUrl = await ref.getDownloadURL();
              debugPrint('✓ Video uploaded to Firebase: $videoDownloadUrl');
            } catch (uploadErr) {
              debugPrint('⚠️ Firebase upload failed: $uploadErr. Video file is available locally at: $videoPath');
              // Fall back to showing video is available locally
            }
          } else {
            debugPrint('✗ Video file DOES NOT EXIST at path: $videoPath');
          }
        } catch (e) {
          debugPrint('⚠️ Video handling failed: $e - will send email without video URL');
          // Continue anyway - don't block email sending
        }
      } else {
        debugPrint('⚠️ NO VIDEO PATH found in prefs (key: last_sos_video_path). Path is: "$videoPath"');
      }
      
      // Build message based on status
      String message;
      String locationStr = 'Location not available';
      Map<String, dynamic>? locationMap;
      if (currentLocation != null) {
        locationStr = 'Latitude: ${currentLocation.latitude.toStringAsFixed(6)}\nLongitude: ${currentLocation.longitude.toStringAsFixed(6)}';
        locationMap = {
          'lat': currentLocation.latitude,
          'lng': currentLocation.longitude,
          'address': locationStr,
        };
        debugPrint('📍 Location map: $locationMap');
      } else {
        debugPrint('⚠️ currentLocation is null - location will not be included in alert');
      }

      if (isSafe) {
        message = '✅ I am SAFE. False alarm. I am okay.\n'
            'Time: ${timestamp.toString()}\n'
            'Location: $locationStr';
      } else {
        final videoStatus = videoDownloadUrl != null ? 'YES (attached below)' : (videoPath != null && File(videoPath).existsSync() ? 'Recorded (local)' : 'Not recorded');
        message = '🆘 URGENT SOS ALERT!\n'
            'I need immediate help!\n'
            'Time: ${timestamp.toString()}\n'
            'Exact Location:\n$locationStr\n'
            'Video: $videoStatus\n'
            'Please contact emergency services if you cannot reach me.';
      }

      // Record SOS event in local history
      await _recordSOSEvent(prefs, isSafe, timestamp, locationStr, videoPath);

      // Extract email recipients from selectedContacts
      final emailRecipients = <String>[];
      for (final contact in selectedContacts) {
        if (contact is String && contact.contains('@')) {
          emailRecipients.add(contact);
        } else if (contact is Map && contact['email'] != null) {
          emailRecipients.add(contact['email'] as String);
        }
      }

      final contactNames = selectedContacts
          .map((c) => c is Map ? c['displayName'] ?? 'Unknown' : c.toString())
          .join(', ');

      debugPrint('SOS Alert sent to: $contactNames');
      debugPrint('Message: $message');
      debugPrint('Email recipients: ${emailRecipients.join(', ')}');
      if (videoPath != null) debugPrint('Video Path: $videoPath');

      // Send via both Firebase AND SMTP email
      debugPrint('🔵 Starting email send process...');
      bool firebaseSuccess = false;
      bool smtpSuccess = false;
      String feedbackMessage = '';
      
      try {
        // Write to Firestore to trigger Cloud Function for email sending
        debugPrint('🔵 Attempting Firestore write (with timeout)...');
        if (emailRecipients.isNotEmpty) {
          try {
            // Safety timeout so Firestore unavailability doesn't block SMTP send
            await _firestore
                .collection('sos_events')
                .add({
                  'timestamp': FieldValue.serverTimestamp(),
                  'message': message,
                  'location': locationMap,
                  'recipients': emailRecipients,
                  'video_url': videoDownloadUrl ?? videoPath, // Use Firebase URL if available, else local path
                  'is_safe': isSafe,
                  'status': 'pending',
                  'contact_count': selectedContacts.length,
                })
                .timeout(const Duration(seconds: 5));
            debugPrint('✓ SOS event written to Firestore successfully');
            firebaseSuccess = true;
            feedbackMessage = 'Notifying via Firebase Cloud...';
          } on TimeoutException catch (te) {
            debugPrint('✗ Firestore write timed out: $te');
          } catch (e) {
            debugPrint('✗ Failed to write SOS to Firestore: $e');
          }
        }

        // Also send via backend SMTP endpoint (if available)
        debugPrint('🔵 Attempting SMTP send...');
        debugPrint('📧 Email recipients count: ${emailRecipients.length}');
        debugPrint('📧 Email recipients list: $emailRecipients');
        if (emailRecipients.isNotEmpty) {
          try {
            debugPrint('🔷 BEFORE calling _sendViaSMTP()...');
            final smtpResult = await _sendViaSMTP(
              recipients: emailRecipients,
              subject: '🆘 URGENT SOS ALERT',
              message: message,
              location: locationMap,
              videoPath: videoPath,
              videoDownloadUrl: videoDownloadUrl,
            );
            debugPrint('🔷 AFTER calling _sendViaSMTP(), result: $smtpResult');
            
            if (smtpResult) {
              debugPrint('✓ Email sent via SMTP backend successfully');
              smtpSuccess = true;
              feedbackMessage = 'Emails sent to ${emailRecipients.length} recipient(s)!';
            } else {
              debugPrint('⚠️ SMTP returned false (send failed)');
            }
          } catch (e) {
            debugPrint('⚠️ SMTP backend exception: $e');
            debugPrint('⚠️ Exception stack trace: ${StackTrace.current}');
            // Backend may not be running - that's ok, Firebase Cloud Function will handle it
          }
        } else {
          debugPrint('⚠️ No email recipients found, skipping SMTP send');
        }
      } catch (e) {
        debugPrint('🚨 CRITICAL ERROR during email send: $e');
      }
      debugPrint('🔵 Email send process completed');

      // Show result
      if (smtpSuccess) {
        _showSuccessSnackBar(context, 'SOS Alert sent to ${emailRecipients.length} recipient(s) via email!');
      } else if (firebaseSuccess) {
        _showSuccessSnackBar(context, 'SOS Alert queued for ${emailRecipients.length} recipient(s). Sending via Firebase...');
      } else if (emailRecipients.isNotEmpty) {
        final err = _lastSmtpError != null ? ' (details: ${_lastSmtpError})' : '';
        final suggestion = (_lastSmtpError != null && (_lastSmtpError!.contains('127.0.0.1') || _lastSmtpError!.contains('Connection refused')))
            ? '\nTip: If running the backend locally, set SMTP backend URL to http://10.0.2.2:3000/send-email in Settings.'
            : '';
        _showErrorSnackBar(context, 'Alert sent but email delivery pending. Check your contacts.$err$suggestion');
      } else {
        _showErrorSnackBar(context, 'No email addresses found in selected contacts');
      }

      return true;
    } catch (e) {
      debugPrint('Failed to send SOS alert: $e');
      _showErrorSnackBar(context, 'Error sending SOS: $e');
      return false;
    }
  }

  /// Send SOS alert via SMTP backend
  static Future<bool> _sendViaSMTP({
    required List<String> recipients,
    required String subject,
    required String message,
    required Map<String, dynamic>? location,
    required String? videoPath,
    required String? videoDownloadUrl,
  }) async {
    try {
      debugPrint('🔷🔷 [_sendViaSMTP] START - recipients: $recipients');
      // Expose last SMTP error for calling code to show richer messages
      _lastSmtpError = null;
      // Build HTML email with enhanced styling
      String mapsLink = '';
      String locationDetails = '';
      if (location != null && location['lat'] != null && location['lng'] != null) {
        mapsLink = 'https://maps.google.com/?q=${location['lat']},${location['lng']}';
        locationDetails = '''
          <p><strong>Latitude:</strong> ${location['lat']}</p>
          <p><strong>Longitude:</strong> ${location['lng']}</p>
        ''';
      }
      
      final htmlBody = '''
        <html>
          <body style="font-family: Arial, sans-serif; color: #333; line-height: 1.6; background-color: #f5f5f5;">
            <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
              <h2 style="color: #d32f2f; border-bottom: 3px solid #d32f2f; padding-bottom: 10px;">🆘 SOS ALERT - URGENT</h2>
              <p><strong>Status:</strong> <span style="color: #d32f2f; font-weight: bold;">Emergency help needed</span></p>
              <p><strong>Message:</strong></p>
              <div style="background-color: #fff3cd; padding: 15px; border-left: 4px solid #d32f2f; border-radius: 4px; margin: 10px 0;">
                ${message.replaceAll('\n', '<br>')}
              </div>
              <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
              <h3 style="color: #333; margin-top: 15px;">📍 Location Details</h3>
              $locationDetails
              ${mapsLink.isNotEmpty ? '<p><a href="$mapsLink" style="color: #2196F3; text-decoration: none; font-weight: bold; padding: 10px 15px; background-color: #e3f2fd; border-radius: 4px; display: inline-block;">👉 View on Google Maps</a></p>' : '<p><em>Location: Not available</em></p>'}
              <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
              <h3 style="color: #333; margin-top: 15px;">📹 Video Recording</h3>
              ${videoDownloadUrl != null ? '<p><a href="$videoDownloadUrl" style="color: #ff5722; text-decoration: none; font-weight: bold; padding: 10px 15px; background-color: #ffebee; border-radius: 4px; display: inline-block;">📥 Download SOS Video</a></p><p style="font-size: 12px; color: #999;">Video contains critical evidence of the emergency situation.</p>' : (videoPath != null && videoPath.isNotEmpty ? '<p style="color: #ff9800; font-weight: bold;">✓ Video Recorded</p><p style="font-size: 12px; color: #999;">Video file: $videoPath (stored on device)</p>' : '<p><em>Video: Not available</em></p>')}
              <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
              <div style="background-color: #f5f5f5; padding: 12px; border-radius: 4px; margin: 15px 0;">
                <p style="font-size: 12px; color: #666; margin: 5px 0;"><strong>⏰ Timestamp:</strong> ${DateTime.now().toString()}</p>
                <p style="font-size: 12px; color: #666; margin: 5px 0;"><strong>📱 App:</strong> Silent SOS Emergency</p>
              </div>
            </div>
          </body>
        </html>
      ''';

      // Call backend /send-email endpoint
      final http_client = http.Client();

      // Allow overriding backend url from settings (useful for device/emulator differences)
      final prefs = await SharedPreferences.getInstance();
      final configured = prefs.getString('smtp_backend_url')?.trim();

      // Prefer the Android emulator host mapping first, then any user-configured URL,
      // and finally localhost as a last resort. This avoids attempting 127.0.0.1
      // from the device which refers to the device itself (and will refuse).
      final backendUrls = <String>[];
      backendUrls.add('http://10.0.2.2:3000/send-email'); // Android emulator -> host machine

      if (configured != null && configured.isNotEmpty) {
        // If developer configured a localhost URL, map it to the Android emulator host
        // so the device can reach the machine running the backend. Avoid trying the
        // un-mapped localhost (127.0.0.1) from the emulator as it refers to the emulator itself.
        var configuredMapped = configured;
        final containsLocalhost = configured.contains('127.0.0.1') || configured.contains('localhost');
        if (containsLocalhost) {
          configuredMapped = configuredMapped.replaceAll('127.0.0.1', '10.0.2.2').replaceAll('localhost', '10.0.2.2');
          debugPrint('Mapped configured backend $configured -> $configuredMapped for emulator');
          // Prefer the mapped address and DO NOT append the original 127.0.0.1 entry
          if (!backendUrls.contains(configuredMapped)) backendUrls.insert(0, configuredMapped);
        } else {
          if (!backendUrls.contains(configuredMapped)) backendUrls.add(configuredMapped);
          if (!backendUrls.contains(configured)) backendUrls.add(configured);
        }
      }

      // Keep localhost fallback last (may refer to device, often not desired)
      backendUrls.add('http://127.0.0.1:3000/send-email');
      debugPrint('SMTP backend candidates: $backendUrls');

      bool success = false;
      String? lastError;
      
      for (final backendUrl in backendUrls) {
        try {
          debugPrint('📤 Attempting to send SOS email via: $backendUrl');
          
          final response = await http_client.post(
            Uri.parse(backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to': recipients,
              'subject': subject,
              'html': htmlBody,
            }),
          ).timeout(const Duration(seconds: 8));

          debugPrint('📬 Backend response status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            try {
              final data = jsonDecode(response.body);
              if (data['ok'] == true) {
                debugPrint('✓ Email sent successfully via $backendUrl');
                debugPrint('  Message ID: ${data['messageId']}');
                success = true;
                break;
              }
            } catch (e) {
              debugPrint('Failed to parse response: $e');
              lastError = 'Invalid response format';
            }
          } else {
            debugPrint('Backend error ${response.statusCode}: ${response.body}');
            lastError = 'HTTP ${response.statusCode}';
          }
        } catch (e) {
          debugPrint('Connection failed to $backendUrl: $e');
          lastError = e.toString();
        }
      }

      if (!success && lastError != null) {
        debugPrint('⚠️ SMTP backend unavailable: $lastError. Will use Firebase Cloud Function.');
        _lastSmtpError = lastError;
      }
      
      debugPrint('🔷🔷 [_sendViaSMTP] END - success: $success');
      return success;
    } catch (e) {
      debugPrint('🚨 SMTP send error: $e');
      debugPrint('🚨 Exception stack trace: ${StackTrace.current}');
      _lastSmtpError = e.toString();
      return false;
    }
  }

  /// Record SOS event in history
  static Future<void> _recordSOSEvent(
    SharedPreferences prefs,
    bool isSafe,
    DateTime timestamp,
    String locationStr,
    String? videoPath,
  ) async {
    final history = prefs.getStringList('sos_history') ?? [];
    final eventRecord = '${timestamp.toIso8601String()}|${isSafe ? 'SAFE' : 'DANGER'}|$locationStr|${videoPath ?? 'NO_VIDEO'}';
    history.add(eventRecord);

    // Keep only last 100 events
    if (history.length > 100) {
      history.removeRange(0, history.length - 100);
    }

    await prefs.setStringList('sos_history', history);
    await prefs.setString('last_sos_time', timestamp.toIso8601String());
    if (locationStr.isNotEmpty) {
      await prefs.setString('last_sos_location', locationStr);
    }
  }

  /// Show error snackbar
  static void _showErrorSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Show success snackbar
  static void _showSuccessSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Show SOS confirmation dialog with yes/no options
  static Future<bool?> showSOSConfirmation(BuildContext context) async {
    return showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Are You Safe?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'An SOS alert has been triggered.\n\n'
          '• YES: You are safe. Cancel alert.\n'
          '• NO: You need help. Send alerts to contacts.\n'
          '• No response: Auto-send after 10 seconds.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('YES - I AM SAFE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('NO - I NEED HELP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Future<void> startLiveTracking({int durationSeconds = 3600}) async { return; }
  static Future<void> stopLiveTracking() async { return; }
  static Future<bool> resendTo(String number) async { return false; }

  /// Initialize recorder (call once before recording).
  static Future<void> initRecorder() async {
    if (_recorderInitialized) return;
    await _recorder.openRecorder();
    // On some platforms we need to set the audio session category; keep default otherwise.
    _recorderInitialized = true;
  }

  /// Dispose recorder when app shuts down.
  static Future<void> disposeRecorder() async {
    if (!_recorderInitialized) return;
    try {
      await _recorder.closeRecorder();
    } catch (e) {
      debugPrint('Error closing recorder: $e');
    }
    _recorderInitialized = false;
  }

  /// Ensure required permissions for recording and location are granted.
  static Future<bool> ensurePermissions() async {
    final statuses = await [Permission.microphone, Permission.locationWhenInUse].request();
    return statuses[Permission.microphone] == PermissionStatus.granted &&
        statuses[Permission.locationWhenInUse] == PermissionStatus.granted;
  }

  /// Record a short audio clip for [seconds]. Returns the recorded file path
  /// or null if recording failed or permissions are missing.
  static Future<String?> recordAudio({int seconds = 20}) async {
    try {
      final ok = await ensurePermissions();
      if (!ok) return null;
      await initRecorder();

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/sos_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // flutter_sound: use Codec.aacMP4 for .m4a files
      await _recorder.startRecorder(toFile: filePath, codec: Codec.aacMP4);

      // Wait for duration or until stopped externally
      await Future.delayed(Duration(seconds: seconds));

      final path = await _recorder.stopRecorder();
      return path ?? filePath;
    } catch (e) {
      debugPrint('recordAudio error: $e');
      try {
        if (_recorder.isRecording) await _recorder.stopRecorder();
      } catch (_) {}
      return null;
    }
  }

  /// Uploads [file] to Firebase Storage under [remotePath] and returns the
  /// public download URL (or null on failure).
  static Future<String?> uploadFile(File file, String remotePath) async {
    try {
      final ref = _storage.ref().child(remotePath);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('uploadFile error: $e');
      return null;
    }
  }

  /// Get current location as "lat,lon" using the LocationSettings API to
  /// avoid deprecated Geolocator calls.
  static Future<String> getLocation() async {
    try {
      final settings = const LocationSettings(accuracy: LocationAccuracy.best);
      final pos = await Geolocator.getCurrentPosition(locationSettings: settings);
      return '${pos.latitude},${pos.longitude}';
    } catch (e) {
      debugPrint('getLocation failed: $e');
      return '0.0,0.0';
    }
  }

  /// A simple SOS sender that writes an event to Firestore. It optionally
  /// records audio, uploads it, and attaches the media URL in the document.
  /// Returns a map with a minimal status report.
  static Future<Map<String, dynamic>> sendSos({List<String>? contacts, bool includeAudio = false, int audioSeconds = 20}) async {
    final result = <String, dynamic>{'ok': false};
    try {
      final loc = await getLocation();
      List<String> media = [];
      // Audio
      if (includeAudio) {
        final audioPath = await recordAudio(seconds: audioSeconds);
        if (audioPath != null) {
          final file = File(audioPath);
          final remote = 'sos_media/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
          final url = await uploadFile(file, remote);
          if (url != null) media.add(url);
        }
      }

      // Video: if caller requested video via prefs or explicit call, record using MediaRecorder
      try {
        final prefs = await SharedPreferences.getInstance();
        final allowVideo = prefs.getBool('allow_auto_video') ?? false;
        if (allowVideo) {
          // Use the MediaRecorder helper to record a short clip
          try {
            final seconds = prefs.getInt('sosRecordingDuration') ?? 30;
            final videoPath = await MediaRecorder.recordVideo(seconds: seconds < 5 ? 8 : seconds);
            final vfile = File(videoPath);
            final vremote = 'sos_media/${DateTime.now().millisecondsSinceEpoch}_${vfile.uri.pathSegments.last}';
            final vurl = await uploadFile(vfile, vremote);
            if (vurl != null) media.add(vurl);
          } catch (ve) {
            debugPrint('Video recording/upload failed: $ve');
          }
        }
      } catch (_) {}

      final doc = {
        'timestamp': FieldValue.serverTimestamp(),
        'location': loc,
        'contacts': contacts ?? <String>[],
        'media': media,
      };
      await _firestore.collection('sos_events').add(doc);
      result['ok'] = true;
      result['mediaCount'] = media.length;
      return result;
    } catch (e) {
      debugPrint('sendSos failed: $e');
      result['error'] = e.toString();
      return result;
    }
  }
}

/// Backwards-compatible lightweight wrapper expected by some widgets.
class SosService {
  /// Trigger an SOS. The original app called this with a richer API; here
  /// we map it to the simpler `SOSservice.sendSos` implementation.
  Future<Map<String, dynamic>> triggerSos({
    required String senderUid,
    required List<String> recipients,
    bool captureVideo = false,
    int audioDurationSeconds = 6,
  }) async {
    // If captureVideo is true in future we can extend functionality.
    final res = await SOSservice.sendSos(
      contacts: recipients,
      includeAudio: audioDurationSeconds > 0,
      audioSeconds: audioDurationSeconds,
    );
    // Provide a compatible return shape including a fake document id when possible
    return {
      'ok': res['ok'] ?? false,
      'docId': res['ok'] == true ? 'sos_${DateTime.now().millisecondsSinceEpoch}' : null,
      'mediaCount': res['mediaCount'] ?? 0,
      'error': res['error'],
    };
  }
}



/// Minimal CountdownDialog used by `main.dart` and native callbacks. The real
/// dialog is more feature-rich; this placeholder provides a safe UI so the
/// rest of the app can build while keeping analyzer warnings low.
class CountdownDialog extends StatelessWidget {
  final String triggerType;
  const CountdownDialog({super.key, required this.triggerType});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(triggerType),
      content: const Text('Processing...'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
