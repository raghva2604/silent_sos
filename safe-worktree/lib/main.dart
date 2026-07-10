// Minimal app bootstrap for the existing screens/widgets in this repository.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_options.dart';
import 'core/ui_modes.dart';
import 'src/app_state.dart';
import 'src/global_navigator.dart';
import 'services/sos_integration.dart';
import 'services/vibration_service.dart';
import 'services/language_service.dart';
import 'services/offline_ai_service.dart';
import 'services/sos_service.dart';
import 'services/analytics_service.dart';
import 'services/push_notification_service.dart';
import 'services/notification_service.dart';
import 'services/video_storage_service.dart';
import 'services/background_service.dart';
import 'services/purchase_service.dart';
import 'services/recording_status_service.dart';
import 'services/ui_mode_service.dart';
import 'ui/safety_ui/safety_ui.dart';
import 'ui/saved_videos_screen.dart';
import 'ui_disguises/notes_ui/notes_home.dart';
import 'ui_disguises/instagram_ui/instagram_home.dart';
import 'ui_disguises/bank_ui/bank_home.dart';
import 'ui_disguises/shopping_ui/shopping_home.dart';
import 'ui_disguises/army_ui/army_home.dart';
import 'ui/calculator_ui/calculator_ui.dart';
import 'ui/chat_ui/chat_ui.dart';
import 'screens/game_home_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/onboarding_screen.dart';
import 'src/screens/home_screen.dart';
import 'screens/contact_picker_screen.dart';
import 'screens/map_screen.dart';
import 'screens/live_map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/recipients_picker_screen.dart';
import 'screens/personalize_screen.dart';
import 'screens/help_instructions_screen.dart';
import 'screens/offline_ai_screen.dart';
import 'screens/auth_screen.dart';
// STT test screen has been removed; import deleted to allow building

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize foreground task for background execution
  // FlutterForegroundTask.init(
  //   androidNotificationOptions: AndroidNotificationOptions(
  //     channelId: 'silent_sos_channel',
  //     channelName: 'Silent SOS Service',
  //     channelDescription: 'Monitoring safety sensors in background',
  //     channelImportance: NotificationChannelImportance.LOW,
  //     priority: NotificationPriority.LOW,
  //   ),
  //   iosNotificationOptions: const IOSNotificationOptions(),
  //   foregroundTaskOptions: ForegroundTaskOptions(
  //     eventAction: ForegroundTaskEventAction.doNothing,
  //     autoRunOnBoot: true,
  //     allowWakeLock: true,
  //     allowWifiLock: true,
  //   ),
  // );

  PurchaseService.loadPremiumStatus();

  // Load UI mode service before starting app
  final uiModeService = UIModeService();
  try {
    await uiModeService.load();
    debugPrint('🚀 App starting with UI mode: ${uiModeService.mode}');
  } catch (e) {
    debugPrint('⚠️ UIModeService load failed: $e - using default mode');
  }

  // Distinct startup marker to verify the running build on device/emulator
  debugPrint('🔥 NEW BUILD RUNNING 🔥');

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✓ Firebase initialized successfully');

      // Initialize app analytics and auth
      await AnalyticsService.init();
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await AnalyticsService.setUserId(firebaseUser.uid);
      }

      // Initialize push notifications
      await PushNotificationService.init();
      await PushNotificationService.registerNotificationHandlers();
      debugPrint('✓ Firebase services initialized successfully');
    // ignore: deprecated_member_use
    // DISABLED Phase 1: // DISABLED Phase 1: // DISABLED Phase 1: await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    debugPrint('✓ WorkManager initialized for background tasks');
  } catch (e) {
    debugPrint('⚠️ WorkManager initialization failed: $e');
  }

  // Initialize dedicated background location service
  try {
    await BackgroundService.initialize();
    debugPrint('✓ BackgroundService initialized');
  } catch (e) {
    debugPrint('⚠️ BackgroundService initialization failed: $e');
  }

  // Initialize native upload listeners (MethodChannel) to receive upload progress/events
  SosIntegration.initializeUploadListeners();
  // Note: Notification permission is now requested in PermissionScreen as part of consolidated permission flow
  // protection service removed; nothing to auto-start
  // Forward native hotword events into the unified SOS flow
  SosIntegration.setOnHotwordDetected((phrase) async {
    try {
      debugPrint('🔊 Native hotword detected: $phrase');
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList('selected_contacts') ?? [];
      final contacts = contactsJson.map((j) {
        try {
          return j.contains(':') ? j.split(':')[1] : j;
        } catch (_) {
          return j;
        }
      }).toList();

      // Attempt to show countdown UI if we have a navigator context
      final ctx = SOSservice.navigatorKey.currentState?.context;
      final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;
      if (ctx != null && ctx.mounted) {
        final uiService = Provider.of<UIModeService>(ctx, listen: false);
        final silent = uiService.mode != AppUIMode.safety;
        final res = await SOSservice.showCountdownDialog(
          ctx,
          sosCountdown: sosCountdown,
          triggerType: 'Voice',
          silent: silent,
        );
        if (res == true) {
          // user did not cancel, send background-safe alert
          await SOSservice.sendSOSAlertBackground(
              selectedContacts: contacts, videoPath: null);
        }
      } else {
        // No UI available — simply send background alert
        await SOSservice.sendSOSAlertBackground(
            selectedContacts: contacts, videoPath: null);
      }
    } catch (e) {
      debugPrint('Error handling native hotword event: $e');
    }
  });
  // Register handler for native-saved videos so they are imported into app storage
  SosIntegration.setOnVideoSaved((videoPath) async {
    try {
      debugPrint('🔔 Native video saved event received: $videoPath');
      await VideoStorageService.addFromNative(videoPath);
      debugPrint('🔔 Imported native video to app storage');
    } catch (e) {
      debugPrint('⚠️ Error importing native video: $e');
    }
  });
  // Forward native fall events into the unified SOS flow
  SosIntegration.setOnFallDetected((trigger) async {
    try {
      debugPrint('🦴 Native fall detected: $trigger');
      final prefs = await SharedPreferences.getInstance();

      // Check if fall SOS is enabled
      final fallSosEnabled = prefs.getBool('auto_fall_sos_enabled') ?? true;
      if (!fallSosEnabled) {
        debugPrint('⚠️ Fall SOS is disabled, ignoring fall event');
        return;
      }

      final contactsJson = prefs.getStringList('selected_contacts') ?? [];
      final contacts = contactsJson.map((j) {
        try {
          return j.contains(':') ? j.split(':')[1] : j;
        } catch (_) {
          return j;
        }
      }).toList();

      // Also load phone and email contacts from new structure
      final phoneNumbers = prefs.getStringList('sos_phone_numbers') ?? [];
      final emailRecipients = prefs.getStringList('sos_email_recipients') ?? [];

      debugPrint(
          '🦴 Fall: contacts=$contacts, phones=${phoneNumbers.length}, emails=${emailRecipients.length}');

      final ctx = SOSservice.navigatorKey.currentState?.context;
      final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;
      await AnalyticsService.logEvent('fall_detected', parameters: {
        'trigger': trigger,
        'auto_fall_sos_enabled': fallSosEnabled,
      });

      if (ctx != null && ctx.mounted) {
        debugPrint('✅ Fall: Showing countdown dialog (context ready)');
        final uiService = Provider.of<UIModeService>(ctx, listen: false);
        final silent = uiService.mode != AppUIMode.safety;
        final res = await SOSservice.showCountdownDialog(
          ctx,
          sosCountdown: sosCountdown,
          triggerType: 'Fall Detection',
          silent: silent,
        );
        if (res == true) {
          await SOSservice.sendSOSAlertBackground(
              selectedContacts: contacts, videoPath: null);
        }
      } else {
        debugPrint('⚠️ Fall: No UI context, sending background SOS');
        await SOSservice.sendSOSAlertBackground(
            selectedContacts: contacts, videoPath: null);
      }
    } catch (e) {
      debugPrint('❌ Error handling native fall event: $e');
    }
  });

  // Handle Google Assistant voice commands
  SosIntegration.setOnVoiceCommand((command) async {
    try {
      debugPrint('🎤 Google Assistant command: $command');
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList('selected_contacts') ?? [];
      final contacts = contactsJson.map((j) {
        try {
          return j.contains(':') ? j.split(':')[1] : j;
        } catch (_) {
          return j;
        }
      }).toList();

      final ctx = SOSservice.navigatorKey.currentState?.context;
      final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;
      if (ctx != null && ctx.mounted) {
        final uiService = Provider.of<UIModeService>(ctx, listen: false);
        final silent = uiService.mode != AppUIMode.safety;
        final res = await SOSservice.showCountdownDialog(
          ctx,
          sosCountdown: sosCountdown,
          triggerType: 'Voice (Google Assistant)',
          silent: silent,
        );
        if (res == true) {
          await SOSservice.sendSOSAlertBackground(
              selectedContacts: contacts, videoPath: null);
        }
      } else {
        // no UI context, send directly
        await SOSservice.sendSOSAlertBackground(
            selectedContacts: contacts, videoPath: null);
      }
    } catch (e) {
      debugPrint('Error handling Google Assistant command: $e');
    }
  });

  // Listen for Google Assistant deep link via assistant_bridge method channel
  const MethodChannel assistantChannel = MethodChannel('assistant_bridge');
  assistantChannel.setMethodCallHandler((call) async {
    if (call.method == 'start_sos') {
      debugPrint('🔗 Google Assistant deep link triggered SOS');
      try {
        final prefs = await SharedPreferences.getInstance();
        final contactsJson = prefs.getStringList('selected_contacts') ?? [];
        final contacts = contactsJson.map((j) {
          try {
            return j.contains(':') ? j.split(':')[1] : j;
          } catch (_) {
            return j;
          }
        }).toList();

        final ctx = SOSservice.navigatorKey.currentState?.context;
        final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;

        if (ctx != null && ctx.mounted) {
          debugPrint('✅ Showing countdown from assistant_bridge');
          final res = await SOSservice.showCountdownDialog(
            ctx,
            sosCountdown: sosCountdown,
            triggerType: 'Google Assistant',
          );
          if (res == true) {
            await SOSservice.sendSOSAlertBackground(
                selectedContacts: contacts, videoPath: null);
          }
        } else {
          debugPrint(
              '⚠️ No UI context available for assistant, sending background SOS');
          await SOSservice.sendSOSAlertBackground(
              selectedContacts: contacts, videoPath: null);
        }
      } catch (e) {
        debugPrint('❌ Error handling assistant SOS: $e');
      }
    }
    return null;
  });

  // Listen for native AUTO_SOS calls from platform services (Fall/Voice)
  try {
    const platformChannel = MethodChannel('com.example.silent_sos/sos');
    platformChannel.setMethodCallHandler((call) async {
      try {
        if (call.method == 'AUTO_SOS') {
          final args = call.arguments as Map?;
          final trigger = args != null && args['trigger'] != null
              ? args['trigger'].toString()
              : 'unknown';
          debugPrint('Native AUTO_SOS received: $trigger');
          // Use unified manager which will attempt foreground dialog or background-safe send
          final ctx = navigatorKey.currentState?.context;
          try {
            final prefs = await SharedPreferences.getInstance();
            final contactsJson = prefs.getStringList('selected_contacts') ?? [];
            final contacts = contactsJson.map((j) {
              try {
                return j.contains(':') ? j.split(':')[1] : j;
              } catch (_) {
                return j;
              }
            }).toList();

            final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;
            if (ctx != null && ctx.mounted) {
              final uiService = Provider.of<UIModeService>(ctx, listen: false);
              final silent = uiService.mode != AppUIMode.safety;
              final res = await SOSservice.showCountdownDialog(
                ctx,
                sosCountdown: sosCountdown,
                triggerType: 'Background',
                silent: silent,
              );
              if (res == true) {
                await SOSservice.sendSOSAlertBackground(
                    selectedContacts: contacts, videoPath: null);
              }
            } else {
              // Try bring to foreground then show
              try {
                // no UI, just send background alert
                await SOSservice.sendSOSAlertBackground(
                    selectedContacts: contacts, videoPath: null);
              } catch (e) {
                debugPrint('AUTO_SOS fallback background send failed: $e');
                await SOSservice.sendSOSAlertBackground(
                    selectedContacts: contacts, videoPath: null);
              }
            }
            debugPrint('📱 Auto SOS triggered from native: $trigger');
          } catch (e) {
            debugPrint('Error handling AUTO_SOS: $e');
          }
        }
      } catch (e) {
        debugPrint('Error handling AUTO_SOS: $e');
      }
    });
  } catch (e) {
    debugPrint('⚠️ Failed to set AUTO_SOS handler: $e');
  }

  // Initialize Notifications after first frame to ensure platform plugins are registered
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationService.init();
      await PushNotificationService.registerNotificationHandlers();
      debugPrint('✅ Notification service initialized');
      NotificationService.onNotificationTap.listen((payload) async {
        try {
          debugPrint('Notification tapped payload: $payload');
          if (payload == null) return;
          if (payload.startsWith('autofall') ||
              payload.startsWith('fall_alert') ||
              payload.startsWith('sos_emergency')) {
            // Attempt to bring app UI to foreground and show the countdown dialog
            final ctx = navigatorKey.currentState?.context;
            if (ctx != null && ctx.mounted) {
              final prefs = await SharedPreferences.getInstance();
              final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;
              final uiService = Provider.of<UIModeService>(ctx, listen: false);
              final silent = uiService.mode != AppUIMode.safety;
              await SOSservice.showCountdownDialog(
                ctx,
                sosCountdown: sosCountdown,
                triggerType: 'Background',
                silent: silent,
              );
            } else {
              // App not visible; do nothing here
            }
          }
        } catch (e) {
          debugPrint('Notification tap handler error: $e');
        }
      });
    } catch (e) {
      debugPrint('⚠️ NotificationService.init failed: $e');
    }
  });

  // Native PIN verification is handled by `SosIntegration.initializeUploadListeners()`
  // which sets the shared `silent_sos/foreground` handler. Avoid overriding it here.

  // Initialize services with timeouts to prevent indefinite hangs
  try {
    await LanguageService().init().timeout(const Duration(seconds: 5),
        onTimeout: () {
      debugPrint('⚠️ LanguageService.init() timeout (continuing anyway)');
    });
  } catch (e) {
    debugPrint('⚠️ LanguageService.init() failed: $e (continuing)');
  }

  try {
    await VibrationService().init().timeout(const Duration(seconds: 5),
        onTimeout: () {
      debugPrint('⚠️ VibrationService.init() timeout (continuing anyway)');
    });
  } catch (e) {
    debugPrint('⚠️ VibrationService.init() failed: $e (continuing)');
  }

  try {
    await OfflineAIService().init().timeout(const Duration(seconds: 10),
        onTimeout: () {
      debugPrint('⚠️ OfflineAIService.init() timeout (continuing anyway)');
    });
  } catch (e) {
    debugPrint('⚠️ OfflineAIService.init() failed: $e (continuing)');
  }

  // Note: Retry uploads disabled in minimal build
  // Wire connectivity to retry pending uploads on connectivity restore if needed
  try {
    final conn = Connectivity();
    conn.onConnectivityChanged.listen((result) async {
      try {
        if (!result.contains(ConnectivityResult.none)) {
          debugPrint('🔁 Connectivity restored');
        }
      } catch (e) {
        debugPrint('⚠️ Connectivity check error: $e');
      }
    });
  } catch (e) {
    debugPrint('⚠️ Connectivity monitoring failed: $e');
  }

  // Start foreground task for background execution
  // FlutterForegroundTask.startService(
  //   notificationTitle: 'Silent SOS Active',
  //   notificationText: 'Monitoring safety sensors',
  // );

  // Create AppState instance to provide at top level
  final appState = AppState();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UIModeService>.value(value: uiModeService),
        ChangeNotifierProvider<AppState>.value(value: appState),
      ],
      child: const AppBootstrap(),
    ),
  );
}

/// Callback dispatcher for WorkManager background tasks - DISABLED Phase 1
/// void callbackDispatcher() {
///   Workmanager().executeTask((task, inputData) async {
///     try {
///       if (task == 'voice_activation') {
///         debugPrint('🎤 [Background] Voice activation task running...');
///       } else if (task == 'fall_detection') {
///         debugPrint('📉 [Background] Fall detection task running...');
///       } else if (task == 'sos_send') {
///         debugPrint('🆘 [Background] SOS send task running...');
///       }
///     } catch (e) {
///       debugPrint('❌ Background task error: $e');
///       return false;
///     }
///     return true;
///   });
/// }

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap>
    with WidgetsBindingObserver {
  bool? _showOnboarding;
  AppUIMode? _currentMode;
  VoidCallback? _modeListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Keep the UI stack in sync with the selected mode.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uiModeService = Provider.of<UIModeService>(context, listen: false);
      _currentMode = uiModeService.mode;
      _modeListener = () {
        final newMode = uiModeService.mode;
        if (newMode != _currentMode) {
          _currentMode = newMode;
          _navigateToMode(newMode);
        }
      };
      uiModeService.addListener(_modeListener!);
    });

    // Load AppState flags
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.loadOnboardingComplete();
      appState.loadPermissionsGranted();
    });

    // CRITICAL: Initialize onboarding/permissions flags synchronously
    // This prevents race conditions and blank screens
    _initializeOnboardingAndPermissionsSync();

    // Setup MethodChannel listener for fall SOS trigger from notification button (removed)
    // SosTrigger.setupListener();

    // Setup fall detection callback from native services
    SosIntegration.setOnFallDetected((trigger) {
      debugPrint('🔴 Native fall detected: $trigger');
      _handleNativeFallDetected();
    });

    // Check for fall trigger from Intent extras (more reliable than SharedPreferences)
    // Use post-frame + microtask to ensure Navigator and widget tree are fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.microtask(() {
        if (mounted) {
          _checkIntentExtrasForFallTrigger();
        }
      });
    });

    // Check for Assistant SOS on initial launch
    _checkAssistantSOS();
  }

  /// Initialize onboarding/permissions flags synchronously to prevent blank screen
  void _initializeOnboardingAndPermissionsSync() {
    debugPrint('🔄 Starting SharedPreferences initialization...');

    // This will be called before first frame, avoiding race conditions
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) {
        debugPrint('⚠️ SharedPreferences loaded but widget not mounted');
        return;
      }

      try {
        final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
        final permissionsGranted = prefs.getBool('permissions_granted') ?? false;

        debugPrint(
            '📋 Onboarding state loaded: complete=$onboardingComplete, permissions=$permissionsGranted');

        setState(() {
          _showOnboarding = !onboardingComplete;
        });

        debugPrint('✅ SharedPreferences state applied successfully');
      } catch (e) {
        debugPrint('⚠️ Error parsing preferences: $e');
        // Default to showing onboarding on error
        if (mounted) {
          setState(() {
            _showOnboarding = true;
          });
        }
      }
    }).catchError((error) {
      debugPrint('⚠️ Error loading SharedPreferences: $error');
      // Default to showing onboarding on error
      if (mounted) {
        setState(() {
          _showOnboarding = true;
        });
      }
    });

    // Fallback: If SharedPreferences takes too long (more than 2 seconds), keep current UI state.
    // Do not force show onboarding if we already loaded a value.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _showOnboarding == null) {
        debugPrint('⚠️ SharedPreferences timeout (2s) - showing onboarding as fallback');
        setState(() {
          _showOnboarding = true;
        });
      }
    });
  }

  /// Handle fall detection events coming through the native method channel
  Future<void> _handleNativeFallDetected() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get selected contacts
      final contactsJson = prefs.getStringList('selected_contacts') ?? [];
      final contacts = contactsJson.map((j) {
        try {
          return j.contains(':') ? j.split(':')[1] : j;
        } catch (_) {
          return j;
        }
      }).toList();

      // Get countdown duration
      final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;

      // Show countdown with "Fall detected" message using unified dialog
      if (mounted && context.mounted) {
        final uiService = Provider.of<UIModeService>(context, listen: false);
        final silent = uiService.mode != AppUIMode.safety;
        final res = await SOSservice.showCountdownDialog(
          context,
          sosCountdown: sosCountdown,
          triggerType: 'Fall Detection',
          silent: silent,
        );
        if (res == true) {
          // User confirmed or timer expired - send SOS
          await SOSservice.sendSOSAlertBackground(
            selectedContacts: contacts,
            videoPath: null,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling native fall: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - checking for Intent extras and SOS flags');

      // CRITICAL: Handle SOS lifecycle sequencing (SMS → Email → Video)
      // This ensures no focus stealing between intents
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.microtask(() async {
          if (mounted) {
            // Check if we're in the middle of SOS flow
            // await SosController.handleAppResume(); // removed

            // Also check for other resume actions
            _checkIntentExtrasForFallTrigger();
            _checkAssistantSOS();
          }
        });
      });
    }
  }

  /// Check if the Intent has fall_triggered extra set by native code
  /// Called with post-frame + microtask to ensure Navigator and widget tree are fully initialized
  Future<bool> _isFallTriggeredFromNative() async {
    const platform = MethodChannel('com.example.silent_sos/fall');

    /// Some devices may invoke this check before the native channel has been fully registered.
    /// Retry once after a short delay to avoid noisy MissingPluginException logs.
    try {
      return await platform.invokeMethod<bool>('is_fall_triggered') ?? false;
    } on MissingPluginException {
      await Future.delayed(const Duration(milliseconds: 250));
      try {
        return await platform.invokeMethod<bool>('is_fall_triggered') ?? false;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkIntentExtrasForFallTrigger() async {
    final fallTriggered = await _isFallTriggeredFromNative();
    if (!fallTriggered) return;

    debugPrint(
        '🔴 Fall trigger detected from Intent extras - showing countdown');

    final prefs = await SharedPreferences.getInstance();
    final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;
    final contactsJson = prefs.getStringList('selected_contacts') ?? [];
    final contacts = contactsJson.map((j) {
      try {
        return j.contains(':') ? j.split(':')[1] : j;
      } catch (_) {
        return j;
      }
    }).toList();

    // Clear the flag
    try {
      const platform = MethodChannel('com.example.silent_sos/fall');
      await platform.invokeMethod('clear_fall_triggered');
    } catch (_) {}

    // Try to get context - use both currentState?.context and currentContext
    BuildContext? ctx =
        navigatorKey.currentState?.context ?? navigatorKey.currentContext;

    if (ctx != null && ctx.mounted) {
      debugPrint(
          '✅ Showing countdown dialog from fall trigger (context ready)');
      final uiService = Provider.of<UIModeService>(ctx, listen: false);
      final silent = uiService.mode != AppUIMode.safety;
      final res = await SOSservice.showCountdownDialog(
        ctx,
        sosCountdown: sosCountdown,
        triggerType: 'Fall Detection',
        silent: silent,
      );
      if (res == true) {
        await SOSservice.sendSOSAlertBackground(
            selectedContacts: contacts, videoPath: null);
      }
    } else {
      debugPrint(
          '⚠️ No UI context available (ctx=$ctx, mounted=${ctx?.mounted}), sending SOS in background immediately');
      await SOSservice.sendSOSAlertBackground(
          selectedContacts: contacts, videoPath: null);
    }
  }

  Future<void> _checkAssistantSOS() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getBool("pending_sos") ?? false;
      final source = prefs.getString("pending_source");
      final timestamp = prefs.getInt("pending_timestamp") ?? 0;

      debugPrint(
          '🔍 DEBUG: pending=$pending, source=$source, timestamp=$timestamp');

      if (pending && (source == "assistant" || source == "fall")) {
        // Clear flags immediately
        prefs.setBool("pending_sos", false);
        prefs.remove("pending_source");
        prefs.remove("pending_timestamp");

        final isAssistant = source == "assistant";
        final isFall = source == "fall";
        debugPrint(
            '${isAssistant ? '🔗' : '🔴'} SOS TRIGGERED on resume (source=$source, time=${DateTime.fromMillisecondsSinceEpoch(timestamp)})');

        // Voice listener paused for mic conflicts (removed)

        // Get selected contacts
        final contactsJson = prefs.getStringList('selected_contacts') ?? [];
        final contacts = contactsJson.map((j) {
          try {
            return j.contains(':') ? j.split(':')[1] : j;
          } catch (_) {
            return j;
          }
        }).toList();

        // Get countdown duration
        final sosCountdown = prefs.getInt('sosTimerDuration') ?? 10;

        // Start SOS flow with proper UI context
        try {
          final ctx = SOSservice.navigatorKey.currentState?.context;
          if (ctx != null && ctx.mounted) {
            debugPrint('✅ Showing countdown from $source SOS');
            final uiService = Provider.of<UIModeService>(ctx, listen: false);
            final silent = uiService.mode != AppUIMode.safety;
            final res = await SOSservice.showCountdownDialog(
              ctx,
              sosCountdown: sosCountdown,
              triggerType: isFall ? 'Fall Detection' : 'Google Assistant',
              silent: silent,
            );
            if (res == true) {
              await SOSservice.sendSOSAlertBackground(
                  selectedContacts: contacts, videoPath: null);
            }
          } else {
            // No context (app not in foreground). Background services are disabled,
            // so we cannot bring the UI forward. Simply send the SOS alert directly.
            debugPrint(
                '⚠️ No UI context and background services disabled, sending SOS directly');
            await SOSservice.sendSOSAlertBackground(
                selectedContacts: contacts, videoPath: null);
          }
        } catch (e) {
          debugPrint('❌ Error in $source SOS flow: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking SOS flag: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_modeListener != null) {
      final uiModeService = Provider.of<UIModeService>(context, listen: false);
      uiModeService.removeListener(_modeListener!);
    }
    super.dispose();
  }

  void _navigateToMode(AppUIMode mode) {
    final nav = SOSservice.navigatorKey.currentState;
    if (nav == null) return;

    // Replace the current stack with the correct mode's home screen.
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => _buildModeHome(mode)),
      (route) => false,
    );
  }

  Widget _buildModeHome(AppUIMode mode) {
    switch (mode) {
      case AppUIMode.safety:
        return const SafetyUI();
      case AppUIMode.game:
        return const GameHomeScreen();
      case AppUIMode.calculator:
        return const CalculatorUI();
      case AppUIMode.chat:
        return const ChatUI();
      case AppUIMode.notes:
        return const NotesUI();
      case AppUIMode.instagram:
        return const InstagramUI();
      case AppUIMode.bank:
        return const BankUI();
      case AppUIMode.shopping:
        return const ShoppingUI();
      case AppUIMode.army:
        return const ArmyUI();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VibrationService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
        ChangeNotifierProvider(create: (_) => RecordingStatusService()),
      ],
      child: Consumer2<LanguageService, UIModeService>(
        builder: (ctx, lang, uiService, _) {
          debugPrint(
              '🔧 AppBootstrap.build(): current UI mode = ${uiService.mode}');
          return Consumer<AppState>(
            builder: (ctx, appState, _) {
              return MaterialApp(
                key: ValueKey(uiService.mode),
                title: lang.t('app_title'),
                navigatorKey: SOSservice.navigatorKey,
                debugShowCheckedModeBanner: false,
                theme: uiService.getThemeData(),
                home: !appState.authChecked
                    ? const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      )
                    : !appState.isAuthenticated
                        ? const AuthScreen()
                        : !appState.onboardingComplete
                            ? const OnboardingScreen()
                            : !appState.permissionsGranted
                                ? const PermissionScreen()
                                : (() {
                                    switch (uiService.mode) {
                              case AppUIMode.safety:
                                return const SafetyUI();
                              case AppUIMode.game:
                                return const GameHomeScreen();
                              case AppUIMode.calculator:
                                return const CalculatorUI();
                              case AppUIMode.chat:
                                return const ChatUI();
                              case AppUIMode.notes:
                                return const NotesUI();
                              case AppUIMode.instagram:
                                return const InstagramUI();
                              case AppUIMode.bank:
                                return const BankUI();
                              case AppUIMode.shopping:
                                return const ShoppingUI();
                              case AppUIMode.army:
                                return const ArmyUI();
                            }
                          })(),
                routes: {
                  '/permissions': (ctx) => const PermissionScreen(),
                  '/permissions_complete': (ctx) {
                    // After permissions are granted, display the appropriate UI mode home
                    final uiService =
                        Provider.of<UIModeService>(ctx, listen: false);
                    return _buildModeHome(uiService.mode);
                  },
                  '/home': (ctx) => const HomeScreen(),
                  '/recipients': (ctx) => const RecipientsPickerScreen(),
                  '/auth': (ctx) => const AuthScreen(),
                  '/contacts': (ctx) =>
                      const ContactPickerScreen(initialContacts: []),
                  '/map': (ctx) => const MapScreen(),
                  '/live_map': (ctx) => const LiveMapScreen(),
                  '/settings': (ctx) => const SettingsScreen(),
                  '/saved_videos': (ctx) => const SavedVideosScreen(),
                  '/personalize': (ctx) => const PersonalizeScreen(),
                  '/offline_ai': (ctx) => const OfflineAiScreen(),
                  '/help': (ctx) => const HelpInstructionsScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Backwards-compatible alias used by tests and external imports.
class SilentSOSApp extends StatelessWidget {
  const SilentSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppBootstrap();
  }
}
