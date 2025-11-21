import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
// native MethodChannel imported above
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
// splash screen import removed (unused)
import 'screens/emergency_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/debug_auto_send.dart';
import 'screens/medical_chat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/onboarding.dart';
import 'services/notification_service.dart';
import 'services/sos_service.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'services/native_callbacks.dart' as native_callbacks;
import 'theme/futuristic_theme.dart';

// MethodChannel used to receive messages from native (e.g., native notification taps)
final MethodChannel _nativeChannel = MethodChannel('silent_sos/foreground');

// Navigator key used for notification-driven navigation/actions (e.g. "I'm safe" dialog)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// This function is now separate and can be awaited properly.
Future<void> initializeServices() async {
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Ensure we have an authenticated Firebase user for Storage uploads.
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
      debugPrint('Signed in anonymously to Firebase for Storage uploads.');
    }
  } catch (e) {
    debugPrint('Firebase anonymous sign-in failed: $e');
  }

  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService.init failed: $e');
  }

  // Foreground service initialization is handled when the feature is implemented and tested on device.

  // NOTE: Do NOT request runtime permissions here because the Flutter
  // application Activity / UI may not be attached yet. Requesting OS-level
  // runtime permissions before `runApp` can prevent the system dialogs from
  // showing. Permission requests are performed once the UI is ready (see
  // `HomeScreen` initState) to ensure dialogs are displayed correctly.

  try {
    await SOSservice.retryQueuedMessages();
  } catch (e) {
    debugPrint('SOSservice.retryQueuedMessages failed: $e');
  }

  // Initialize Workmanager for periodic background retry of queued messages.
  try {
  Workmanager().initialize(callbackDispatcher);
    // Avoid duplicate registrations by tracking a flag in SharedPreferences.
    try {
      final prefs = await SharedPreferences.getInstance();
      final registered = prefs.getBool('workmanager_offline_retry_registered') ?? false;
      if (!registered) {
        try {
          // Use constraints to prefer unmetered networks and avoid running while on battery if possible.
          Workmanager().registerPeriodicTask(
            'offlineRetry',
            'offlineRetryTask',
            frequency: const Duration(minutes: 15),
            initialDelay: const Duration(seconds: 10),
            constraints: Constraints(
              networkType: NetworkType.unmetered,
              requiresCharging: false,
            ),
          );
          await prefs.setBool('workmanager_offline_retry_registered', true);
        } catch (e) {
          // If constraints aren't supported on the platform or registration fails fall back to minimal registration
          try {
            Workmanager().registerPeriodicTask('offlineRetry', 'offlineRetryTask', frequency: const Duration(minutes: 15), initialDelay: const Duration(seconds: 10));
            await prefs.setBool('workmanager_offline_retry_registered', true);
          } catch (inner) {
            debugPrint('Workmanager register failed: $e / $inner');
          }
        }
      }
    } catch (e) {
      debugPrint('Workmanager register guard failed: $e');
    }
  } catch (e) {
    debugPrint('SOSservice.retryQueuedMessages failed: $e');
  }
}

// Top-level callback for Workmanager. This must be a top-level function.
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await SOSservice.retryQueuedMessages();
    } catch (e) {
      debugPrint('Workmanager retry task failed: $e');
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  // Run the app inside a guarded zone and perform all Flutter initializations
  // inside that same zone to avoid 'Zone mismatch' errors when bindings are
  // initialized in one zone and `runApp` is executed in another.
  runZonedGuarded(() async {
    // Ensure Flutter bindings and services are initialized inside the zone.
  WidgetsFlutterBinding.ensureInitialized();
  // Start background initialization but do not await it so the UI can appear
  // immediately. Heavy work (network, Firebase, retries) should not block
  // `runApp` or the initial splash screen — this prevents a blank/black
  // startup when initialization is slow or network/unavailable.
  initializeServices();

    // Set system UI appearance
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Register a top-level PlatformDispatcher error handler for errors from the engine.
    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (_) {}
      // Return false to let the engine handle the error as well.
      return false;
    };

    runApp(const SilentSOSApp());

    // Show onboarding overlay once after app launch if not seen before
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final shown = prefs.getBool('onboarding_v1_shown') ?? false;
        if (!shown) {
          // Use navigatorKey.currentState to avoid capturing a BuildContext across async gaps
          navigatorKey.currentState?.push(PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, a1, a2) => const OnboardingOverlay(),
          ));
        }
      } catch (_) {}
    });

    // Register a handler for native-initiated messages (foreground taps).
    _nativeChannel.setMethodCallHandler((call) async {
      try {
        if (call.method == 'nativeAlert') {
          final payload = call.arguments as String?;
          if (payload == 'fall_alert') {
            // Cancel any native scheduled auto-send (we'll show the in-app countdown which
            // can record media and provide richer controls). Best-effort: ignore errors.
            try {
              await _nativeChannel.invokeMethod('cancelAutoSend');
            } catch (_) {}

            final nav = navigatorKey.currentState;
            if (nav == null) return;
            // Show the existing CountdownDialog so the user can cancel or let it auto-send.
            nav.push(PageRouteBuilder(
              opaque: false,
              barrierDismissible: true,
              pageBuilder: (context, animation, secondaryAnimation) {
                return Center(
                  child: CountdownDialog(triggerType: 'Fall Detected'),
                );
              },
            ));
          }
        } else if (call.method == 'debugAutoSendResult') {
          // Forward native debug results into a Dart stream so UI can observe them.
          try {
            final arg = call.arguments;
            if (arg is Map) {
              native_callbacks.addDebugAutoSendResult(Map<String, dynamic>.from(arg.cast<String, dynamic>()));
            }
          } catch (_) {}
        } else if (call.method == 'nativeRecordingComplete') {
        } else if (call.method == 'nativeDiagnostic') {
          try {
            final arg = call.arguments;
            if (arg is Map) {
              // payload is expected to be a JSON string under 'payload'
              final p = arg['payload'];
              if (p is String) {
                native_callbacks.addNativeDiagnostic(p);
              }
            }
          } catch (_) {}
          try {
            final arg = call.arguments;
            if (arg is Map) {
              native_callbacks.addRecordingComplete(Map<String, dynamic>.from(arg.cast<String, dynamic>()));
            }
          } catch (_) {}
        }
      } catch (_) {}
    });

    // If the activity was launched from a native notification, request any pending payload now.
    try {
      Future.microtask(() async {
        try {
          final pending = await _nativeChannel.invokeMethod('getPendingPayload');
          if (pending != null && pending is String && pending == 'fall_alert') {
            try {
              await _nativeChannel.invokeMethod('cancelAutoSend');
            } catch (_) {}
            final nav = navigatorKey.currentState;
            if (nav != null) {
              nav.push(PageRouteBuilder(
                opaque: false,
                barrierDismissible: true,
                pageBuilder: (context, animation, secondaryAnimation) {
                  return Center(
                    child: CountdownDialog(triggerType: 'Fall Detected'),
                  );
                },
              ));
            }
          }
        } catch (_) {}
      });
    } catch (_) {}
    // Listen for notification taps and show a quick 'Are you safe?' dialog when tapped.
    try {
      NotificationService.onNotificationTap.listen((payload) {
        if (payload == 'fall_alert') {
          // Use navigatorKey.currentContext to get a valid BuildContext at call time.
          final ctx = navigatorKey.currentContext;
          if (ctx == null) return;
          final nav = navigatorKey.currentState;
          if (nav == null) return;
          // Cancel native scheduled auto-send and show the richer CountdownDialog which allows cancellation and media options.
          _nativeChannel.invokeMethod('cancelAutoSend').catchError((_) {});
          nav.push(PageRouteBuilder(
            opaque: false,
            barrierDismissible: true,
            pageBuilder: (context, animation, secondaryAnimation) {
              return Center(
                child: CountdownDialog(triggerType: 'Fall Detected'),
              );
            },
          ));
        }
      });
    } catch (_) {}
  }, (error, stack) {
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
    debugPrint('Uncaught zone error: $error');
  });

}

class SilentSOSApp extends StatelessWidget {
  const SilentSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SilentSOS',
      theme: futuristicTheme,
      home: const EmergencyScreen(),
      routes: {
        '/settings': (ctx) => const SettingsScreen(),
        '/diagnostics': (ctx) => const DiagnosticsScreen(),
        '/debug': (ctx) => const DebugAutoSendScreen(),
        '/medical_chat': (ctx) => const MedicalChatScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
