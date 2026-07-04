// lib/src/app_state.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Minimal AppState stub to satisfy UI bindings.
/// Replace or extend with your real application state.
class AppState extends ChangeNotifier {
  bool smsGranted = false;
  bool contactsGranted = false;
  bool locationGranted = false;
  bool notificationsGranted = false;
  bool microphoneGranted = false;
  bool cameraGranted = false;
  bool authChecked = false;
  bool isAuthenticated = false;
  String? userId;

  /// selectedContacts is a simple list placeholder used by the UI.
  List<dynamic> selectedContacts = [];

  /// Countdown seconds used by HomeScreen (default 10 seconds for SOS countdown).
  int sosCountdown = 10;

  /// Auto-open app on fall detection (user-controlled, default true)
  bool autoOpenOnFall = true;

  /// Onboarding seen flag (user education)
  bool onboardingSeen = false;

  /// Onboarding complete flag
  bool onboardingComplete = false;

  /// Permissions granted flag
  bool permissionsGranted = false;

  /// A nullable function property used in the provided UI files
  /// (they call `appState.updatePermission?.call('sms', true)`).
  void Function(String, bool)? updatePermission;

  AppState() {
    updatePermission = (String key, bool value) => setPermission(key, value);
    // Load saved app state asynchronously after creation
    Future.delayed(Duration.zero, () async {
      await loadSelectedContacts();
      await loadOnboardingComplete();
      await loadPermissionsGranted();
      await loadAuthState();
    });
  }

  /// Load selected contacts from SharedPreferences on startup
  Future<void> loadSelectedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Support both modern StringList storage and legacy pipe-separated string.
      final list = prefs.getStringList('selected_contacts');
      if (list != null && list.isNotEmpty) {
        selectedContacts = List<dynamic>.from(list);
        debugPrint(
            'AppState: Loaded ${selectedContacts.length} selected contacts from selected_contacts (list)');
      } else {
        final contactsJson = prefs.getString('selected_contacts');
        if (contactsJson != null && contactsJson.isNotEmpty) {
          selectedContacts =
              contactsJson.split('|').where((c) => c.isNotEmpty).toList();
          debugPrint(
              'AppState: Loaded ${selectedContacts.length} selected contacts from selected_contacts (legacy)');
        }
      }
      // Also load any manually persisted recipients saved as 'sos_recipients' (JSON array)
      // Load structured recipient objects saved under 'sos_recipients' and
      // append them to the selectedContacts list as maps (avoid duplicates).
      final rawRecipients = prefs.getString('sos_recipients');
      if (rawRecipients != null && rawRecipients.isNotEmpty) {
        try {
          final List<dynamic> arr = rawRecipients.startsWith('[')
              ? List<dynamic>.from(jsonDecode(rawRecipients))
              : [];
          var appended = 0;
          for (final e in arr) {
            if (e is Map) {
              final name = (e['name'] ?? '')?.toString() ?? '';
              final email = (e['email'] ?? '')?.toString() ?? '';
              final phone = (e['phone'] ?? '')?.toString() ?? '';

              // Check for duplicates by email/phone/string presence
              var exists = false;
              for (final sc in selectedContacts) {
                if (sc is Map) {
                  if (email.isNotEmpty && (sc['email'] == email)) {
                    exists = true;
                    break;
                  }
                  if (phone.isNotEmpty && (sc['phone'] == phone)) {
                    exists = true;
                    break;
                  }
                } else if (sc is String) {
                  if (email.isNotEmpty && sc == email) {
                    exists = true;
                    break;
                  }
                  if (phone.isNotEmpty && sc == phone) {
                    exists = true;
                    break;
                  }
                  if (name.isNotEmpty && sc == name) {
                    exists = true;
                    break;
                  }
                }
              }

              if (!exists) {
                selectedContacts.add(Map<String, dynamic>.from(e));
                appended++;
              }
            }
          }
          debugPrint(
              'AppState: Appended $appended persisted recipients from sos_recipients');
        } catch (e) {
          debugPrint('AppState: failed to parse sos_recipients: $e');
        }
      }
      // Load configured SOS timer duration (saved in seconds) into sosCountdown
      try {
        final timer = prefs.getInt('sosTimerDuration');
        if (timer != null && timer > 0) {
          sosCountdown = timer;
          debugPrint('AppState: Loaded sosCountdown = $sosCountdown');
        }
      } catch (e) {
        debugPrint('AppState: failed to load sosTimerDuration: $e');
      }

      // Load autoOpenOnFall setting
      try {
        autoOpenOnFall = prefs.getBool('autoOpenOnFall') ?? true;
        debugPrint('AppState: Loaded autoOpenOnFall = $autoOpenOnFall');
      } catch (e) {
        debugPrint('AppState: failed to load autoOpenOnFall: $e');
      }

      // Load onboarding seen flag
      try {
        onboardingSeen = prefs.getBool('onboardingSeen') ?? false;
        debugPrint('AppState: Loaded onboardingSeen = $onboardingSeen');
      } catch (e) {
        debugPrint('AppState: failed to load onboardingSeen: $e');
      }

      // Load onboarding complete flag
      try {
        onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
        debugPrint('AppState: Loaded onboardingComplete = $onboardingComplete');
      } catch (e) {
        debugPrint('AppState: failed to load onboardingComplete: $e');
      }

      // Load permissions granted flag
      try {
        permissionsGranted = prefs.getBool('permissions_granted') ?? false;
        debugPrint('AppState: Loaded permissionsGranted = $permissionsGranted');
      } catch (e) {
        debugPrint('AppState: failed to load permissionsGranted: $e');
      }
    } catch (e) {
      debugPrint('Error loading selected contacts: $e');
    }
    notifyListeners();
  }

  /// Save selected contacts to SharedPreferences
  Future<void> setSelectedContacts(List<dynamic> contacts) async {
    selectedContacts = contacts;
    debugPrint('AppState: Setting ${contacts.length} selected contacts');
    try {
      final prefs = await SharedPreferences.getInstance();
      // Persist a string-list representation for device-selected values.
      final List<String> stringList = contacts.map((c) {
        if (c is String) return c;
        if (c is Map) {
          if (c['email'] != null && c['email'].toString().isNotEmpty) {
            return c['email'].toString();
          }
          if (c['phone'] != null && c['phone'].toString().isNotEmpty) {
            return c['phone'].toString();
          }
          if (c['name'] != null && c['name'].toString().isNotEmpty) {
            return c['name'].toString();
          }
          return jsonEncode(c);
        }
        return c.toString();
      }).toList();
      await prefs.setStringList('selected_contacts', stringList);
      debugPrint(
          'AppState: Saved contacts to preferences (list): ${stringList.length} items');
    } catch (e) {
      debugPrint('Error saving selected contacts: $e');
    }
    notifyListeners();
  }

  /// Set SOS countdown seconds and persist
  Future<void> setSosCountdown(int seconds) async {
    sosCountdown = seconds;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sosTimerDuration', seconds);
    } catch (e) {
      debugPrint('Error saving sosTimerDuration: $e');
    }
    notifyListeners();
  }

  /// Set auto-open on fall and persist
  Future<void> setAutoOpenOnFall(bool value) async {
    autoOpenOnFall = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoOpenOnFall', value);
      debugPrint('AppState: Set autoOpenOnFall = $value');
    } catch (e) {
      debugPrint('Error saving autoOpenOnFall: $e');
    }
    notifyListeners();
  }

  /// Mark onboarding as seen
  Future<void> setOnboardingSeen() async {
    onboardingSeen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboardingSeen', true);
      debugPrint('AppState: Marked onboarding as seen');
    } catch (e) {
      debugPrint('Error saving onboardingSeen: $e');
    }
    notifyListeners();
  }

  /// Set onboarding complete
  Future<void> setOnboardingComplete() async {
    onboardingComplete = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      debugPrint('AppState: Set onboardingComplete = true');
    } catch (e) {
      debugPrint('Error saving onboarding_complete: $e');
    }
    notifyListeners();
  }

  /// Set permissions granted
  Future<void> setPermissionsGranted() async {
    permissionsGranted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('permissions_granted', true);
      debugPrint('AppState: Set permissionsGranted = true');
    } catch (e) {
      debugPrint('Error saving permissions_granted: $e');
    }
    notifyListeners();
  }

  /// Load onboarding complete from prefs
  Future<void> loadOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
      debugPrint('AppState: Loaded onboardingComplete = $onboardingComplete');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading onboarding_complete: $e');
    }
  }

  /// Load permissions granted from prefs
  Future<void> loadPermissionsGranted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      permissionsGranted = prefs.getBool('permissions_granted') ?? false;
      debugPrint('AppState: Loaded permissionsGranted = $permissionsGranted');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading permissions_granted: $e');
    }
  }

  /// Load authentication state from Firebase Auth
  Future<void> loadAuthState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      isAuthenticated = user != null;
      userId = user?.uid;
      debugPrint('AppState: Loaded auth state: isAuthenticated=$isAuthenticated, userId=$userId');
    } catch (e) {
      debugPrint('Error loading auth state: $e');
    }
    authChecked = true;
    notifyListeners();
  }

  void setAuthenticated(bool authenticated, {String? uid}) {
    isAuthenticated = authenticated;
    userId = uid;
    authChecked = true;
    notifyListeners();
  }

  void clearAuthentication() {
    isAuthenticated = false;
    userId = null;
    authChecked = true;
    notifyListeners();
  }

  void setPermission(String key, bool granted) {
    switch (key) {
      case 'sms':
        smsGranted = granted;
        break;
      case 'contacts':
        contactsGranted = granted;
        break;
      case 'location':
        locationGranted = granted;
        break;
      case 'notifications':
        notificationsGranted = granted;
        break;
      case 'microphone':
        microphoneGranted = granted;
        break;
      case 'camera':
        cameraGranted = granted;
        break;
      case 'activity':
        // optional: used for fall detection in newer APIs
        break;
      case 'phone':
        // optional: legacy optional permission
        break;
      default:
        break;
    }
    notifyListeners();
  }

  bool get allPermissionsGranted =>
      contactsGranted &&
      locationGranted &&
      notificationsGranted &&
      microphoneGranted &&
      cameraGranted;
}

