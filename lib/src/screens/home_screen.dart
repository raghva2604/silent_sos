// lib/src/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/ui_mode_service.dart';
import '../../core/ui_modes.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../app_state.dart';
import '../../services/sos_service.dart';
import '../../services/notification_service.dart';
// DISABLED Phase 1: import '../../services/language_service.dart';
import '../../services/media_recorder.dart';
import '../../core/sos_settings.dart';
import '../../services/fall_detector.dart';
import '../../services/voice_activation_service.dart';
import '../../core/risk_notifier.dart';
import '../../sos/sos_controller.dart';
import '../../screens/live_map_screen.dart';
import '../../models/recipient.dart';
import '../../models/risk_level.dart';
import '../../services/recording_status_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _timer;
  bool _autoFallEnabled = false;
  String? _recordingBanner;
  // was recording flag removed - no longer used
  List<String> _sosContacts = []; // Load contacts from SharedPreferences
  List<Recipient> _emailRecipients = [];
  bool _isVisible = false;
  double _sosScale = 1.0;

  // 🔥 Risk Status System
  RiskLevel _currentRisk = RiskLevel.safe;
  Timer? _safeWalkTimer;
  // Safe Walk timer variables (countdown)
  Duration _safeWalkDuration = const Duration(minutes: 15);
  int _remainingSeconds = 0;
  bool _isSafeWalkActive = false;

  // 🔥 Recording Status - Subscribes to RecordingStatusService
  final RecordingStatusService _recordingService = RecordingStatusService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🔥 Listen to recording status changes from RecordingStatusService
    _recordingService.addListener(() {
      if (!mounted) return;
      final isRec = _recordingService.isRecording;
      // Recording started
      if (isRec) {
        setState(() {
          _recordingBanner = 'Recording...';
        });
      } else {
        // Recording stopped — show next-step banner depending on auto mode
        SharedPreferences.getInstance().then((prefs) {
          final auto = prefs.getBool('auto_mode_enabled') ?? false;
          setState(() {
            _recordingBanner = auto
                ? 'Recording complete — sending alerts...'
                : 'Opening apps...';
          });
          // Clear banner after a short duration
          Future.delayed(const Duration(seconds: 6), () {
            if (mounted) setState(() => _recordingBanner = null);
          });
        });
      }
      // Always refresh UI
      setState(() {});
    });

    // Listen to global risk notifier to reflect state when SOS triggered from services
    RiskNotifier.instance.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentRisk = RiskNotifier.instance.value;
      });
    });

    // Load auto-fall status on init
    _loadAutoFallStatus();
    // Listen for auto mode changes so badge updates immediately
    SosController.autoModeNotifier.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    // Load SOS contacts from SharedPreferences
    _loadContacts();
    // Load email recipients
    _loadEmailRecipients();
    // Load Safe Walk duration from settings
    _loadSafeWalkDuration();
    // Start fall detection if enabled
    _initializeFallDetection();

    // Auto start voice activation briefly when app opens in Safety mode.
    Future.microtask(() async {
      try {
        await VoiceActivationService.instance.init();
        if (mounted) {
          final uiModeService =
              Provider.of<UIModeService>(context, listen: false);
          if (uiModeService.currentMode == AppUIMode.safety) {
            await VoiceActivationService.instance.startListening(
              context: context,
              durationSeconds: 90,
            );
            debugPrint('🎤 Voice activation started on app open (90s)');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Voice activation initialization failed: $e');
      }
    });

    // Fade in animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  /// Load SOS contacts from SharedPreferences (saved from recipients screen)
  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sosContacts = prefs.getStringList('sos_contacts') ?? [];
    });
    debugPrint('✅ Loaded ${_sosContacts.length} SOS contacts');
  }

  /// Load email recipients from SharedPreferences
  Future<void> _loadEmailRecipients() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getString('sos_recipients') ?? '[]';
    final list = jsonDecode(jsonList) as List;
    setState(() {
      _emailRecipients = list.map((e) => Recipient.fromJson(e)).toList();
    });
    debugPrint('✅ Loaded ${_emailRecipients.length} email recipients');
  }

  /// Reload contacts when returning from recipients screen
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadContacts(); // Reload contacts in case user added new ones
      _loadEmailRecipients(); // Reload emails

      // ensure risk banner reflects any update that happened while app was paused
      final current = RiskNotifier.instance.value;
      if (current != _currentRisk) {
        debugPrint('🔁 App resumed: refreshing risk from $current');
        setState(() => _currentRisk = current);
      }
    }
  }

  /// Update global risk level — safe → suspicious → emergency
  void updateRisk(RiskLevel level) {
    if (mounted) {
      setState(() {
        _currentRisk = level;
      });
      debugPrint('🔴 Risk Status Updated: ${level.label}');
    }
  }

  /// Start Safe Walk Timer — countdown with visible remaining seconds
  void startSafeWalkTimer() {
    // Cancel any existing timer
    _safeWalkTimer?.cancel();

    _remainingSeconds = _safeWalkDuration.inSeconds;
    _isSafeWalkActive = true;
    updateRisk(RiskLevel.suspicious);

    _safeWalkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _isSafeWalkActive = false;
        updateRisk(RiskLevel.emergency);
        debugPrint('⏱️ Safe Walk timeout — triggering SOS');
        VoiceActivationService.instance.pause();
        SosController.triggerSOS(context: context, source: 'Safe Walk Timeout');
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safe Walk Started — cancel before time runs out.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
    debugPrint(
        '⏱️ Safe Walk Timer Started (${_safeWalkDuration.inMinutes} mins)');
  }

  Future<void> _loadSafeWalkDuration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final minutes = prefs.getInt('safe_walk_duration_minutes') ?? 15;
      setState(() {
        _safeWalkDuration = Duration(minutes: minutes);
      });
      debugPrint('✅ Loaded Safe Walk duration: ${minutes} minutes');
    } catch (e) {
      debugPrint('⚠️ Failed to load Safe Walk duration: $e');
    }
  }

  /// Cancel Safe Walk Timer
  void cancelSafeWalkTimer() {
    _safeWalkTimer?.cancel();
    _isSafeWalkActive = false;
    updateRisk(RiskLevel.safe);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safe Walk Cancelled. Status returned to Safe.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
    debugPrint('✅ Safe Walk Timer Cancelled');
  }

  Future<void> _loadAutoFallStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoFallEnabled = prefs.getBool('auto_fall_sos_enabled') ?? true;
    });
  }

  Future<void> _initializeFallDetection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('auto_fall_sos_enabled') ?? true;
      if (enabled) {
        await FallDetector.start();
        debugPrint('✅ Fall detection started');
      }
    } catch (e) {
      debugPrint('❌ Fall detection init error: $e');
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Background service is disabled, skip native startup requests.
    // background services disabled; no native startup required
  }

  void _toggleAutoFall(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoFallEnabled = enable;
    });
    await prefs.setBool('auto_fall_sos_enabled', enable);

    if (enable) {
      try {
        await FallDetector.start();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Fall detection enabled'),
                duration: Duration(seconds: 2)),
          );
        }
      } catch (e) {
        debugPrint('❌ Fall detection start failed: $e');
        if (mounted) {
          setState(() => _autoFallEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ Fall detection failed to start: $e')),
          );
        }
      }
    } else {
      await FallDetector.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Fall detection disabled'),
              duration: Duration(seconds: 2)),
        );
      }
    }

    debugPrint('🔴 Fall detection toggle: $enable');
  }

  // ignore: unused_element
  void _cancelCountdown() {
    // Not currently used, but kept for future implementation
    _timer?.cancel();
  }

  // ignore: unused_element
  Future<void> _triggerSos({bool skipAutoTimer = false}) async {
    final appState = Provider.of<AppState>(context, listen: false);

    // Start video recording and WAIT for it to complete before proceeding
    debugPrint('🎥 Triggering SOS: starting video recording and waiting...');
    final videoPath = await _startAndWaitForVideoRecording();
    debugPrint('🎥 Video recording complete: $videoPath');

    bool confirmed = false;
    _showSOSDialog(context, appState, (isSafe) {
      confirmed = true;
      if (isSafe == null) {
        _sendSOSWithNotification(appState, false);
      } else if (isSafe) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Alert cancelled. You are marked safe.'),
              backgroundColor: Colors.green),
        );
      } else {
        _sendSOSWithNotification(appState, false);
      }
    });

    // If this call originated from the initial countdown, don't start a second auto-timer here
    if (!skipAutoTimer) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;
        Timer(Duration(seconds: sosCountdown), () {
          if (!confirmed && context.mounted) {
            Navigator.of(context).pop();
            _sendSOSWithNotification(appState, false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'No response detected. Sending SOS to all contacts...'),
                  backgroundColor: Colors.red),
            );
          }
        });
      } catch (e) {
        // Fallback to 10s if prefs access fails
        Timer(const Duration(seconds: 10), () {
          if (!confirmed && context.mounted) {
            Navigator.of(context).pop();
            _sendSOSWithNotification(appState, false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'No response detected. Sending SOS to all contacts...'),
                  backgroundColor: Colors.red),
            );
          }
        });
      }
    }
  }

  /// Start video recording and wait for it to complete before returning
  Future<String?> _startAndWaitForVideoRecording() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear old video path before recording new one
      await prefs.remove('last_sos_video_path');
      await prefs.remove('last_sos_video_path_secondary');

      final sosTimerDuration = prefs.getInt('sosTimerDuration') ?? 10;

      // Record video for the duration of SOS timer (minimum 8 seconds)
      final recordingDuration = sosTimerDuration < 8 ? 8 : sosTimerDuration;

      debugPrint(
          '📹 Starting SOS video recording for ${recordingDuration}s and waiting...');

      // Wait for video to complete before returning
      String? videoPath;
      // Use sequential front -> back recording when enabled
      try {
        if (SosSettings.recordVideo) {
          final seq = await MediaRecorder.recordSequentialVideos(
              seconds: SosSettings.recordDurationSeconds < 1
                  ? recordingDuration
                  : SosSettings.recordDurationSeconds);
          if (seq.isNotEmpty) {
            // front then back
            videoPath = seq[0];
            if (seq.length > 1) {
              await prefs.setString('last_sos_video_path_secondary', seq[1]);
            }
          }
        } else {
          videoPath =
              await MediaRecorder.recordVideo(seconds: recordingDuration);
        }
      } catch (e) {
        debugPrint(
            '⚠️ Sequential recording failed, falling back to single camera: $e');
        videoPath = await MediaRecorder.recordVideo(seconds: recordingDuration);
      }
      debugPrint('✓ Video recorded successfully and ready: $videoPath');

      // Save path to prefs for sendSOSAlert to pick up
      if (videoPath != null) {
        await prefs.setString('last_sos_video_path', videoPath);
      }
      debugPrint(
          '✓ Video path saved to prefs: last_sos_video_path = $videoPath');
      return videoPath;
    } catch (e) {
      debugPrint('✗ Video recording failed: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sos_video_path');
      return null;
    }
  }

  Future<void> _sendSOSWithNotification(AppState appState, bool isSafe) async {
    if (isSafe) {
      // User marked themselves as safe - cancel SOS
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Alert cancelled. You are marked safe.'),
            backgroundColor: Colors.green),
      );
      return;
    }

    // Get location for SMS message
    try {
      debugPrint('📍 Fetching location for SMS...');
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      String address = '${position.latitude}, ${position.longitude}';

      // Build SMS message with location
      final message = SOSservice.buildSosMessage(
        lat: position.latitude,
        lng: position.longitude,
        address: address,
      );

      // Get phone numbers from SharedPreferences (now properly extracted from contacts)
      final prefs = await SharedPreferences.getInstance();
      final phoneNumbers = prefs.getStringList('sos_phone_numbers') ?? [];

      if (phoneNumbers.isEmpty) {
        // No emergency contacts configured - offer to call 108
        debugPrint(
            '⚠️ No emergency contacts found. Offering emergency call to 108.');
        if (!context.mounted) return;

        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text(
              '🚨 Emergency Call Required',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            content: const SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No emergency contacts have been added to your emergency alert list.',
                    style: TextStyle(height: 1.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Would you like to call the emergency number 108?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please note: Silent SOS is a supplement to official emergency services, not a replacement.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.phone),
                label: const Text('Call 108'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        );

        if (result == true) {
          // Call 108
          await SOSservice.callEmergencyNumber('108');
        }
        return;
      }

      // Open SMS app with prefilled message
      debugPrint(
          '📱 Opening SMS app with ${phoneNumbers.length} recipient(s)...');
      for (final num in phoneNumbers) {
        debugPrint('  📞 $num');
      }
      await SOSservice.openSmsApp(
        phoneNumbers: phoneNumbers,
        message: message,
      );

      // Show confirmation notification
      await NotificationService.showSOSEmergencyNotification(
        title: '🚨 SOS EMERGENCY 🚨',
        body: 'SMS app opened. Please review and send the message to confirm.',
        contactsCount: appState.selectedContacts.length.toString(),
      );
    } catch (e) {
      debugPrint('❌ Error in _sendSOSWithNotification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSOSDialog(
      BuildContext context, AppState appState, Function(bool?) onResponse) {
    // Determine whether to show UI or run silently based on current UI mode
    final uiModeService = Provider.of<UIModeService>(context, listen: false);
    final silent = uiModeService.currentMode != AppUIMode.safety;

    SOSservice.showCountdownDialog(
      context,
      sosCountdown: appState.sosCountdown,
      triggerType: 'Manual SOS',
      silent: silent,
    ).then((value) {
      try {
        onResponse(value);
      } catch (e) {
        debugPrint('⚠️ Error forwarding dialog response: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _safeWalkTimer?.cancel(); // Cancel Safe Walk timer if running
    // Stop fall detection
    FallDetector.stop();
    debugPrint('✅ Fall detection stopped');

    // Stop voice activation listener
    VoiceActivationService.instance.pause();

    super.dispose();
  }

  Widget _smallOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade600, width: 1),
            ),
            child: Icon(icon, color: Colors.teal.shade200, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- new layout helpers --------------------
  String get _formattedRemaining {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildSafeWalkCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade600,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Safe Walk — ${_formattedRemaining}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Text(
          "SAFE",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSuspiciousCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.yellow.shade700,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Text(
          "SUSPICIOUS",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Text(
          "EMERGENCY",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    // Priority: Safe Walk active → Emergency → Suspicious → Safe
    if (_isSafeWalkActive) {
      return _buildSafeWalkCard();
    }

    if (_currentRisk == RiskLevel.emergency) {
      return _buildEmergencyCard();
    }

    if (_currentRisk == RiskLevel.suspicious) {
      return _buildSuspiciousCard();
    }

    return _buildSafeCard();
  }

  Widget _buildContactsInfoCard() {
    final hasContacts = _sosContacts.isNotEmpty || _emailRecipients.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasContacts ? Colors.teal.shade900 : Colors.red.shade800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: hasContacts ? Colors.teal.shade500 : Colors.red.shade400,
            width: 2),
      ),
      child: Row(
        children: [
          Icon(
            hasContacts ? Icons.shield : Icons.warning,
            color: hasContacts ? Colors.teal.shade200 : Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasContacts
                  ? "${_sosContacts.length} Contact${_sosContacts.length != 1 ? 's' : ''} • ${_emailRecipients.length} Email${_emailRecipients.length != 1 ? 's' : ''} selected"
                  : "⚠️ No contacts or emails selected! Tap to add them now.",
              style: TextStyle(
                color: hasContacts ? Colors.teal.shade200 : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSafeWalkSection() {
    return Column(
      children: [
        if (_isSafeWalkActive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.timer, color: Colors.white),
                  Expanded(
                    child: Text(
                      'Safe Walk active — remaining: $_formattedRemaining',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: ElevatedButton.icon(
                  onPressed: startSafeWalkTimer,
                  icon: const Icon(Icons.timer),
                  label: const Text('Start Safe Walk'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: ElevatedButton.icon(
                  onPressed: cancelSafeWalkTimer,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel Walk'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show contact count from local state (updated from SharedPreferences)

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text('silent sos',
                style: TextStyle(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(width: 8),
            if (_recordingBanner != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _recordingBanner!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_library),
            tooltip: 'Saved Videos',
            onPressed: () => Navigator.pushNamed(context, '/saved_videos'),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // -- auto mode badge and status card moved into structured layout --
                    const SizedBox(height: 8),
                    _AutoModeBadge(),

                    const SizedBox(height: 12),
                    AnimatedOpacity(
                      opacity: _isVisible ? 1.0 : 0.0,
                      duration: const Duration(seconds: 1),
                      child: _buildStatusCard(),
                    ),

                    const SizedBox(height: 24),

                    // Contacts info (was previous status container)
                    _buildContactsInfoCard(),

                    const SizedBox(height: 24),
                    // SOS button
                    Center(
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _sosScale = 0.95),
                        onTapUp: (_) => setState(() => _sosScale = 1.0),
                        onTapCancel: () => setState(() => _sosScale = 1.0),
                        onTap: () {
                          // Redundantly update risk before triggering SOS
                          updateRisk(RiskLevel.emergency);
                          VoiceActivationService.instance.pause();
                          SosController.triggerSOS(
                            context: context,
                            source: 'manual',
                          );
                        },
                        child: Transform.scale(
                          scale: _sosScale,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.red.shade400,
                                  Colors.red.shade800
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.5),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'SOS',
                                    style: TextStyle(
                                      fontSize: 48,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'TAP TO SEND',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Safe Walk section
                    buildSafeWalkSection(),

                    const SizedBox(height: 16),

                    // Fall detection toggle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.waves,
                              color: Colors.teal.shade200, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Automatic Fall Detection',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Switch(
                            value: _autoFallEnabled,
                            onChanged: _toggleAutoFall,
                            activeThumbColor: Colors.teal,
                            inactiveTrackColor: Colors.grey.shade800,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const SizedBox(height: 24),

                    // Bottom icons
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _smallOption(Icons.people, 'Manage', () async {
                            await Navigator.pushNamed(context, '/recipients');
                            _loadContacts();
                            _loadEmailRecipients();
                          }),
                          _smallOption(Icons.map, 'Live Map', () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LiveMapScreen()));
                          }),
                          _smallOption(Icons.mic, 'Voice', () {
                            VoiceActivationService.instance.startListening(
                                context: context, durationSeconds: 20);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Listening for SOS keyword...'),
                                  duration: Duration(seconds: 2)),
                            );
                          }),
                          _smallOption(
                              Icons.palette,
                              'Personalize',
                              () =>
                                  Navigator.pushNamed(context, '/personalize')),
                          _smallOption(Icons.settings, 'Settings',
                              () => Navigator.pushNamed(context, '/settings')),
                          _smallOption(Icons.help_outline, 'Help',
                              () => Navigator.pushNamed(context, '/help')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Movable floating AI button
            DraggableAiButton(),
          ],
        ),
      ),
    );
  }
}

/// Draggable AI floating button — preserves position during session
class DraggableAiButton extends StatefulWidget {
  const DraggableAiButton({super.key});

  @override
  State<DraggableAiButton> createState() => _DraggableAiButtonState();
}

class _DraggableAiButtonState extends State<DraggableAiButton> {
  double? _left;
  double? _top;
  final double size = 56.0;

  void _ensureInitPosition(BuildContext context) {
    if (_left != null && _top != null) return;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    // default: bottom-right with some padding
    setState(() {
      _left = w - 16 - size;
      _top = h - 140 - size - MediaQuery.of(context).padding.bottom;
      if (_top! < 80) _top = 80; // avoid overlaying appbar
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitPosition(context);
    return Positioned(
      left: _left ?? 0,
      top: _top ?? 0,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _left = (_left ?? 0) + details.delta.dx;
            _top = (_top ?? 0) + details.delta.dy;
            final w = MediaQuery.of(context).size.width;
            final h = MediaQuery.of(context).size.height;
            _left = _left!.clamp(8.0, w - size - 8.0);
            _top = _top!.clamp(8.0, h - size - 80.0);
          });
        },
        child: FloatingActionButton(
          heroTag: 'floating_ai',
          backgroundColor: const Color.fromARGB(235, 53, 177, 165),
          onPressed: () => Navigator.pushNamed(context, '/offline_ai'),
          child: const Icon(Icons.auto_awesome, size: 28),
          tooltip: 'AI Assistant',
        ),
      ),
    );
  }
}

/// Auto Mode Badge Widget — cached to prevent rebuild loops
class _AutoModeBadge extends StatefulWidget {
  const _AutoModeBadge();

  @override
  State<_AutoModeBadge> createState() => _AutoModeBadgeState();
}

class _AutoModeBadgeState extends State<_AutoModeBadge> {
  bool _isAuto = false;

  @override
  void initState() {
    super.initState();
    // initialize local value and subscribe to notifier
    SosController.isAutoModeEnabled().then((v) {
      if (!mounted) return;
      setState(() => _isAuto = v);
    });
    SosController.autoModeNotifier.addListener(() {
      if (!mounted) return;
      setState(() => _isAuto = SosController.autoModeNotifier.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuto) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        "AUTO MODE ACTIVE",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
