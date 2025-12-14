// lib/src/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../../services/sos_service.dart';
import '../../services/notification_service.dart';
import '../../services/language_service.dart';
import '../../services/media_recorder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCountingDown = false;
  int _secondsLeft = 0;
  Timer? _timer;
  bool _autoFallEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAutoFallStatus();
    // Reload contacts when screen initializes
    Future.delayed(Duration.zero, () {
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.loadSelectedContacts();
      }
    });
    // If auto-fall is enabled, start the native/dart detector
    Future.delayed(const Duration(milliseconds: 250), () async {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('auto_fall_sos_enabled') ?? false;
      if (enabled && mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        await SOSservice.startFallDetection(context, List<String>.from(appState.selectedContacts.map((e) => e.toString())));
      }
    });
  }

  Future<void> _loadAutoFallStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoFallEnabled = prefs.getBool('auto_fall_sos_enabled') ?? false;
    });
  }

  void _toggleAutoFall() async {
    final prefs = await SharedPreferences.getInstance();
    final newState = !_autoFallEnabled;
    await prefs.setBool('auto_fall_sos_enabled', newState);
    if (mounted) {
      setState(() {
        _autoFallEnabled = newState;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto Fall SOS ${newState ? 'enabled' : 'disabled'}')),
      );
    }
    // Start/stop detection service to reflect new state immediately
    if (newState) {
      final appState = Provider.of<AppState>(context, listen: false);
      await SOSservice.startFallDetection(context, List<String>.from(appState.selectedContacts.map((e) => e.toString())));
    } else {
      await SOSservice.stopFallDetection();
    }
  }

  void _startCountdown(int seconds) {
    if (_isCountingDown) return;
    setState(() {
      _isCountingDown = true;
      _secondsLeft = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _timer?.cancel();
          _isCountingDown = false;
          // Call async _triggerSos() and let it run (fire and forget is ok here since dialog handles flow)
          _triggerSos();
        }
      });
    });
  }

  // ignore: unused_element
  void _cancelCountdown() {
    // Not currently used, but kept for future implementation
    _timer?.cancel();
    setState(() {
      _isCountingDown = false;
      _secondsLeft = 0;
    });
  }

  Future<void> _triggerSos() async {
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
          const SnackBar(content: Text('✅ Alert cancelled. You are marked safe.'), backgroundColor: Colors.green),
        );
      } else {
        _sendSOSWithNotification(appState, false);
      }
    });

    // Auto-send after configured SOS timer (use saved preference)
    try {
      final prefs = await SharedPreferences.getInstance();
      final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;
      Timer(Duration(seconds: sosCountdown), () {
        if (!confirmed && context.mounted) {
          Navigator.of(context).pop();
          _sendSOSWithNotification(appState, false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No response detected. Sending SOS to all contacts...'), backgroundColor: Colors.red),
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
            const SnackBar(content: Text('No response detected. Sending SOS to all contacts...'), backgroundColor: Colors.red),
          );
        }
      });
    }
  }

  /// Start video recording and save path to prefs (background, non-blocking)
  Future<void> _startVideoRecording() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sosTimerDuration = prefs.getInt('sosTimerDuration') ?? 10;
      
      // Record video for the duration of SOS timer (minimum 8 seconds)
      final recordingDuration = sosTimerDuration < 8 ? 8 : sosTimerDuration;
      
      debugPrint('📹 Starting SOS video recording for ${recordingDuration}s...');
      
      // This runs in background (fire and forget)
      MediaRecorder.recordVideo(seconds: recordingDuration).then((videoPath) async {
        debugPrint('✓ Video recorded successfully: $videoPath');
        // Save path to prefs for sendSOSAlert to pick up
        await prefs.setString('last_sos_video_path', videoPath);
      }).catchError((e) {
        debugPrint('✗ Video recording failed: $e');
      });
    } catch (e) {
      debugPrint('Video recording error: $e');
    }
  }

  /// Start video recording and wait for it to complete before returning
  Future<String?> _startAndWaitForVideoRecording() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear old video path before recording new one
      await prefs.remove('last_sos_video_path');
      
      final sosTimerDuration = prefs.getInt('sosTimerDuration') ?? 10;
      
      // Record video for the duration of SOS timer (minimum 8 seconds)
      final recordingDuration = sosTimerDuration < 8 ? 8 : sosTimerDuration;
      
      debugPrint('📹 Starting SOS video recording for ${recordingDuration}s and waiting...');
      
      // Wait for video to complete before returning
      final videoPath = await MediaRecorder.recordVideo(seconds: recordingDuration);
      debugPrint('✓ Video recorded successfully and ready: $videoPath');
      
      // Save path to prefs for sendSOSAlert to pick up
      await prefs.setString('last_sos_video_path', videoPath);
      debugPrint('✓ Video path saved to prefs: last_sos_video_path = $videoPath');
      return videoPath;
    } catch (e) {
      debugPrint('✗ Video recording failed: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sos_video_path');
      return null;
    }
  }

  Future<void> _sendSOSWithNotification(AppState appState, bool isSafe) async {
    await SOSservice.sendSOSAlert(
      selectedContacts: appState.selectedContacts,
      isSafe: isSafe,
      context: context,
    );

    await NotificationService.showSOSEmergencyNotification(
      title: '🚨 SOS EMERGENCY 🚨',
      body: isSafe
          ? '✅ You are safe. Alert cancelled.'
          : 'Emergency alert sent to ${appState.selectedContacts.length} contact(s). Waiting for response...',
      contactsCount: appState.selectedContacts.length.toString(),
    );
  }

  void _showSOSDialog(BuildContext context, AppState appState, Function(bool?) onResponse) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('🚨 Manual SOS: ${LanguageService().t('are_you_safe')}', 
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1), 
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
                      Text('🚨 ${LanguageService().t('sos_button')} ALERT TRIGGERED', 
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16), 
                        textAlign: TextAlign.center
                      ),
                      const SizedBox(height: 16),
                      const Text('Sending SOS in...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '${appState.sosCountdown}',
                        style: const TextStyle(color: Colors.red, fontSize: 64, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text('Alert will be sent to ${appState.selectedContacts.length} contact(s)', 
                        style: const TextStyle(color: Colors.white70, fontSize: 12)
                      ),
                      const SizedBox(height: 16),
                      // Display custom settings in detail box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withAlpha(100)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer, color: Colors.orange, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Timer: ${appState.sosCountdown}s',
                                  style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.videocam, color: Colors.orange, size: 16),
                                const SizedBox(width: 8),
                                const Text(
                                  'Recording video & location',
                                  style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Press & hold to cancel', 
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
                const SizedBox(height: 12),
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onResponse(true); // Cancel SOS
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('PRESS & HOLD TO CANCEL', 
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onResponse(false); // Send SOS
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red, 
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
            child: const Text("No — I'm not safe", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onResponse(true); // Cancel
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.teal, 
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
            ),
            child: const Text('Yes — Stop the SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final contactsCount = appState.selectedContacts.length;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        title: const Text('silent sos', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Card - Shows contacts ready or not selected
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.teal.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade500, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield, color: Colors.teal.shade200, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      contactsCount > 0 
                        ? '${contactsCount} Contact${contactsCount > 1 ? 's' : ''} Ready' 
                        : 'NO CONTACTS SELECTED',
                      style: TextStyle(
                        color: contactsCount > 0 ? Colors.teal.shade200 : Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Expanded space with centered SOS button
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _startCountdown(appState.sosCountdown > 0 ? appState.sosCountdown : 5),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Colors.red.shade400, Colors.red.shade800],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 8,
                            )
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isCountingDown ? '$_secondsLeft' : 'SOS',
                                style: const TextStyle(
                                  fontSize: 48,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isCountingDown ? 'SENDING...' : 'TAP TO SEND',
                                style: const TextStyle(
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
                  ],
                ),
              ),
            ),

            // Auto Fall Detection Toggle
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.waves, color: Colors.teal.shade200, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Automatic Fall\nDetection',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Switch(
                    value: _autoFallEnabled,
                    onChanged: (_) => _toggleAutoFall(),
                    activeColor: Colors.teal,
                    inactiveThumbColor: Colors.grey.shade700,
                    inactiveTrackColor: Colors.grey.shade800,
                  ),
                ],
              ),
            ),

            // Bottom Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _smallOption(Icons.people, 'Manage', () => Navigator.pushNamed(context, '/recipients')),
                  _smallOption(Icons.map, 'Map', () => Navigator.pushNamed(context, '/map')),
                  _smallOption(Icons.chat_bubble, 'AI', () => Navigator.pushNamed(context, '/ai')),
                  _smallOption(Icons.settings, 'Settings', () => Navigator.pushNamed(context, '/advanced-settings')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
