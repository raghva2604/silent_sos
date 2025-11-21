import 'dart:ui';
import 'dart:async';
// Suppress build-context-across-async-gap warnings in this file where guarded by mounted checks
// The tutorial/dialog logic executes in a post-frame callback and verifies `mounted` before
// using the BuildContext; the linter is noisy here so we ignore the rule for this file.
// ignore_for_file: use_build_context_synchronously
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/tutorial_overlay.dart';
import '../services/sos_service.dart';
import '../widgets/futuristic_button.dart';
import 'settings_screen.dart';
import 'map_screen.dart';
import 'contact_picker_screen.dart';
import 'permissions_help_screen.dart';
import '../services/foreground_service.dart';
import '../services/voice_command_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isListening = false;
  List<String> _selectedContacts = [];
  bool _autoSOS = false;
  // Keys for tutorial overlay targets
  final GlobalKey _sosKey = GlobalKey();
  final GlobalKey _autoSOSKey = GlobalKey();
  final GlobalKey _contactsKey = GlobalKey();
  final GlobalKey _mapKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  // tutorial shown programmatically on first run; no stored flag needed here

  @override
  void initState() {
    super.initState();
    // Delay permission requests until the UI is attached so Android can
    // display the system permission dialogs. This will prompt the user on
    // first-run and ensure permissions show up in App Settings.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePermissions();
    });
    // Load previously saved contacts and autoSOS state so selections persist across restarts
    _loadSavedContacts();
    _loadAutoSOSState();
    // Listen for SOS active state changes so we can show/hide the Stop button immediately
    SOSservice.onActiveChanged.listen((active) {
      if (!mounted) return;
      setState(() {});
    });

    // Show tutorial on first run (post-frame so layout exists and keys resolve)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final seen = prefs.getBool('seen_tutorial') ?? false;
        if (!seen && mounted) {
          final steps = [
            TutorialStep(targetKey: _sosKey, title: 'SOS Button', description: 'Tap this big red button to trigger a manual SOS immediately.'),
            TutorialStep(targetKey: _autoSOSKey, title: 'Automatic Fall Detection', description: 'Toggle this to enable background fall detection and auto-send.'),
            TutorialStep(targetKey: _contactsKey, title: 'Contacts', description: 'Pick which contacts will receive your SOS messages.'),
            TutorialStep(targetKey: _mapKey, title: 'Map', description: 'View your current location and nearby points of interest.'),
            TutorialStep(targetKey: _settingsKey, title: 'Settings', description: 'Configure recording, vibration, and other preferences here.'),
          ];

          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Tutorial',
            pageBuilder: (ctx, a1, a2) {
              return TutorialOverlay(
                steps: steps,
                onFinish: () async {
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('seen_tutorial', true);
                  } catch (_) {}
                  if (!mounted) return;
                  Navigator.of(ctx).pop();
                },
              );
            },
          );
        }
      } catch (_) {}
    });
  }

  Future<void> _loadAutoSOSState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('auto_sos') ?? false;
      if (!mounted) return;
      setState(() {
        _autoSOS = enabled;
      });
      if (_autoSOS) {
        // Start fall detection if it was enabled previously
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          // Start detection without a BuildContext to avoid use_build_context_synchronously lint.
          SOSservice.startFallDetection(null, _selectedContacts);
          try {
            ForegroundService.startService();
          } catch (e) {
            debugPrint('Failed to start native foreground service on load: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load autoSOS state: $e');
    }
  }

  Future<void> _ensurePermissions() async {
    try {
      final contactsStatus = await Permission.contacts.status;
      final locationStatus = await Permission.location.status;
        final smsStatus = await Permission.sms.status;
      final notificationStatus = await Permission.notification.status;

      // Request any that are denied (but not permanently denied).
      if (contactsStatus.isDenied) await Permission.contacts.request();
      if (locationStatus.isDenied) await Permission.location.request();
  if (smsStatus.isDenied) await Permission.sms.request();
      if (notificationStatus.isDenied) await Permission.notification.request();

      // Re-check for permanently denied and prompt user to open settings.
      final afterContacts = await Permission.contacts.status;
      final afterLocation = await Permission.location.status;
      final afterNotification = await Permission.notification.status;

      if (afterContacts.isPermanentlyDenied || afterLocation.isPermanentlyDenied || afterNotification.isPermanentlyDenied) {
        if (!mounted) return;
        // Show the dialog in a post-frame callback to avoid using BuildContext across async gaps.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Permissions required'),
              content: const Text('Some permissions were denied permanently. Please open App Settings and enable Contacts / Location / Notifications for full functionality.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                TextButton(onPressed: () async { Navigator.pop(ctx); await openAppSettings(); }, child: const Text('Open Settings')),
              ],
            ),
          );
        });
      }
      // Request background location (allow all the time) after foreground is granted
      try {
        if ((await Permission.location.status).isGranted) {
          final bgStatus = await Permission.locationAlways.status;
          if (!bgStatus.isGranted && !bgStatus.isPermanentlyDenied) {
            await Permission.locationAlways.request();
          }
        }
      } catch (e) {
        debugPrint('Background location request failed: $e');
      }
    } catch (e) {
      debugPrint('Permission ensure failed: $e');
    }
  }

  Future<void> _loadSavedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('selected_contacts') ?? [];
      if (!mounted) return;
      setState(() {
        _selectedContacts = List.from(list);
      });
    } catch (e) {
      debugPrint('Failed to load saved contacts: $e');
    }
  }

  Future<void> _saveSelectedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('selected_contacts', _selectedContacts);
    } catch (e) {
      debugPrint('Failed to save selected contacts: $e');
    }
  }

  Future<void> _openContactPicker() async {
    // Capture whether autoSOS is enabled now so we don't rely on stale state after awaits.
    final shouldStartDetection = _autoSOS;
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => ContactPickerScreen(initialContacts: _selectedContacts)),
    );

    if (!mounted) return;
    if (result == null) return;

    setState(() {
      _selectedContacts = result;
    });

    // Persist the selection so it remains across app restarts
    await _saveSelectedContacts();

    if (shouldStartDetection) {
      // Use a post-frame callback to avoid using BuildContext across async gaps.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SOSservice.startFallDetection(context, _selectedContacts);
      });
    }
  }

  Future<void> _showPermissionStatus() async {
    final statuses = await Future.wait([
      Permission.contacts.status,
      Permission.location.status,
      Permission.notification.status,
    ]);

    final msg = <String>[];
    msg.add('Contacts: ${statuses[0]}');
    msg.add('Location: ${statuses[1]}');
    msg.add('Notifications: ${statuses[2]}');

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission Status'),
          content: Text(msg.join('\n')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'S I L E N T S O S',
          style: TextStyle(
            shadows: [
              Shadow(color: theme.colorScheme.primary.withAlpha((0.9 * 255).round()), blurRadius: 12),
              Shadow(color: theme.colorScheme.secondary.withAlpha((0.6 * 255).round()), blurRadius: 28),
            ],
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, size: 24),
            tooltip: 'Diagnostics',
            onPressed: () => Navigator.pushNamed(context, '/diagnostics'),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, size: 24),
            tooltip: 'AI Assistant',
            onPressed: () => Navigator.pushNamed(context, '/medical_chat'),
          ),
          IconButton(
            icon: const Icon(Icons.verified_user_outlined, size: 26),
            tooltip: 'Check Permissions',
            onPressed: _showPermissionStatus,
          ),
          IconButton(
            icon: const Icon(Icons.shield, size: 26),
            tooltip: 'Permissions Help',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsHelpScreen())),
          ),
          // Settings button (target for tutorial)
          IconButton(
            key: _settingsKey,
            icon: const Icon(Icons.settings_outlined, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1020), Color(0xFF05050A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top status
                Container(
                  padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.colorScheme.primary.withAlpha((0.12 * 255).round()), Colors.transparent]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withAlpha((0.25 * 255).round())),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 30),
                    const SizedBox(width: 15),
                    Text(
                      _selectedContacts.isEmpty ? "NO CONTACTS SELECTED" : "${_selectedContacts.length} CONTACT(S) READY",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ]),
                ),

                // SOS Button
                GestureDetector(
                  key: _sosKey,
                  onTap: () => SOSservice.triggerManualSOS(context, _selectedContacts),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Colors.red.shade700.withAlpha((0.9 * 255).round()), Colors.red.shade900.withAlpha((0.6 * 255).round())]),
                      boxShadow: [BoxShadow(color: Colors.red.withAlpha((0.25 * 255).round()), blurRadius: 30, spreadRadius: 10)],
                    ),
                    child: Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.redAccent, width: 4),
                        ),
                        child: const Center(
                          child: Text('SOS', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                // Simple Cancel button for manual SOS flows (visible when active)
                if (SOSservice.isActive)
                  FuturisticButton(
                    onPressed: () {
                      try {
                        SOSservice.cancelActiveSos(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS cancelled')));
                      } catch (e) {
                        debugPrint('Failed to cancel SOS: $e');
                      }
                    },
                    style: FuturisticButtonStyle.danger,
                    height: 44,
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.stop_circle_outlined, color: Colors.white), SizedBox(width:8), Text('Stop SOS')]),
                  ),

                // Bottom actions
                Column(children: [
                  Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      // replace deprecated withOpacity -> withAlpha
                      color: Colors.white.withAlpha((0.02 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha((0.04 * 255).round())),
                    ),
                    child: SwitchListTile.adaptive(
                      key: _autoSOSKey,
                      title: const Text('Automatic Fall Detection', style: TextStyle(fontWeight: FontWeight.bold)),
                        value: _autoSOS,
                        onChanged: (value) async {
                          setState(() => _autoSOS = value);
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('auto_sos', value);
                          } catch (e) {
                            debugPrint('Failed to persist auto_sos: $e');
                          }

                          // Use a post-frame callback to avoid using BuildContext across async gaps.
                          WidgetsBinding.instance.addPostFrameCallback((_) async {
                            if (!mounted) return;
                            if (value) {
                              SOSservice.startFallDetection(context, _selectedContacts);
                              try {
                                await ForegroundService.startService();
                              } catch (e) {
                                debugPrint('Failed to start native foreground service: $e');
                              }
                            } else {
                              SOSservice.stopFallDetection();
                              try {
                                await ForegroundService.stopService();
                              } catch (e) {
                                debugPrint('Failed to stop native foreground service: $e');
                              }
                            }
                          });
                        },
                      secondary: Icon(Icons.sensors, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(children: [
                    Expanded(
                      child: FuturisticButton(
                        onPressed: _openContactPicker,
                        style: FuturisticButtonStyle.secondary,
                        height: 48,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.contacts_outlined, color: Colors.white), SizedBox(width:8), Text('Contacts')]),
                      ),
                    ),
                    const SizedBox(width: 15),
                      Expanded(
                        child: FuturisticButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
                          style: FuturisticButtonStyle.secondary,
                          height: 48,
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.map_outlined, color: Colors.white), SizedBox(width:8), Text('Map')]),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  // Push-to-talk voice command (MVP)
                  FuturisticButton(
                    onPressed: _isListening
                        ? null
                        : () async {
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              final optIn = prefs.getBool('push_to_talk_opt_in') ?? false;
                              if (!optIn) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Push-to-talk is disabled. Enable it in Settings.')));
                                return;
                              }

                              setState(() => _isListening = true);

                              final ok = await VoiceCommandService.initialize();
                              if (!ok) {
                                if (!mounted) return;
                                setState(() => _isListening = false);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Speech engine unavailable')));
                                return;
                              }

                              StreamSubscription<String>? sub;
                              sub = VoiceCommandService.onResult.listen((text) async {
                                try {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Heard: $text')));
                                  final match = await VoiceCommandService.isTrigger(text);
                                  if (match) {
                                    SOSservice.triggerManualSOS(context, _selectedContacts);
                                  }
                                } catch (_) {}
                                await Future.delayed(const Duration(milliseconds: 200));
                                await sub?.cancel();
                                if (mounted) setState(() => _isListening = false);
                              });

                              // Start listening; the service will respect confidence thresholds and opt-in.
                              await VoiceCommandService.startListening(timeoutSeconds: 8);
                              // If listening times out without result, clear state
                              if (mounted) setState(() => _isListening = false);
                            } catch (e) {
                              debugPrint('Voice listen failed: $e');
                              if (mounted) setState(() => _isListening = false);
                            }
                          },
                    style: FuturisticButtonStyle.primary,
                    height: 48,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_isListening) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) else const Icon(Icons.mic, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(_isListening ? 'Listening…' : 'Push-to-talk'),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ])
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// Helper for the frosted glass effect
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  const GlassmorphicContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(15.0),
            border: Border.all(
              width: 1.5,
              color: Colors.white.withAlpha((0.2 * 255).round()),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

