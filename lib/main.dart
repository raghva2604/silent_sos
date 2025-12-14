// Minimal app bootstrap for the existing screens/widgets in this repository.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/app_state.dart';
import 'services/sos_integration.dart';
import 'services/vibration_service.dart';
import 'services/language_service.dart';
import 'services/offline_ai_service.dart';
import 'screens/permission_screen.dart';
import 'screens/onboarding_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/hotword_settings_screen.dart';
import 'screens/ai_assistant_simple.dart';
import 'screens/contact_picker_screen.dart';
import 'screens/map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/advanced_settings_screen.dart';
import 'screens/recipients_picker_screen.dart';
import 'screens/tflite_test_screen.dart';
import 'src/screens/stt_test_screen.dart';

late bool _showOnboarding;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✓ Firebase initialized successfully');
  } catch (e) {
    debugPrint('✗ Firebase initialization failed: $e');
  }
  
  // Check if onboarding has been completed
  final prefs = await SharedPreferences.getInstance();
  _showOnboarding = !(prefs.getBool('onboarding_completed') ?? false);
  // Initialize native upload listeners (MethodChannel) to receive upload progress/events
  SosIntegration.initializeUploadListeners();
  // Initialize language service
  await LanguageService().init();
  // Initialize vibration service
  await VibrationService().init();
  // Initialize offline AI service
  await OfflineAIService().init();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => VibrationService()),
        ChangeNotifierProvider(create: (_) => LanguageService()),
      ],
      child: Consumer<LanguageService>(builder: (ctx, lang, _) {
        return MaterialApp(
          title: lang.t('app_title'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
          home: _showOnboarding ? const OnboardingScreen() : const HomeScreen(),
        routes: {
          '/permissions': (ctx) => const PermissionScreen(),
          '/home': (ctx) => const HomeScreen(),
          '/hotword-settings': (ctx) => const HotwordSettingsScreen(),
          '/recipients': (ctx) => RecipientsPickerScreen(),
          '/ai': (ctx) => const AIAssistantScreenSimple(),
          '/contacts': (ctx) => const ContactPickerScreen(initialContacts: []),
          '/map': (ctx) => const MapScreen(),
          '/settings': (ctx) => const SettingsScreen(),
          '/advanced-settings': (ctx) => const AdvancedSettingsScreen(),
          '/tflite_test': (ctx) => const TFLiteTestScreen(),
          '/stt_test': (ctx) => const STTTestScreen(),
        },
        );
      }),
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

