// lib/src/app_state.dart
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

  /// selectedContacts is a simple list placeholder used by the UI.
  List<dynamic> selectedContacts = [];

  /// Countdown seconds used by HomeScreen.
  int sosCountdown = 5;

  /// A nullable function property used in the provided UI files
  /// (they call `appState.updatePermission?.call('sms', true)`).
  void Function(String, bool)? updatePermission;

  AppState() {
    updatePermission = (String key, bool value) => setPermission(key, value);
    // Load contacts asynchronously after creation
    Future.delayed(Duration.zero, () => loadSelectedContacts());
  }

  /// Load selected contacts from SharedPreferences on startup
  Future<void> loadSelectedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getString('selected_contacts');
      if (contactsJson != null && contactsJson.isNotEmpty) {
        selectedContacts = contactsJson.split('|').where((c) => c.isNotEmpty).toList();
        debugPrint('AppState: Loaded ${selectedContacts.length} selected contacts from selected_contacts');
      }
      // Also load any manually persisted recipients saved as 'sos_recipients' (JSON array)
      final rawRecipients = prefs.getString('sos_recipients');
      if (rawRecipients != null && rawRecipients.isNotEmpty) {
        try {
          final List<dynamic> arr = rawRecipients.startsWith('[') ? List<dynamic>.from(jsonDecode(rawRecipients)) : [];
          for (final e in arr) {
            if (e is Map) {
              final name = (e['name'] ?? '') as String;
              final email = (e['email'] ?? '') as String;
              final display = name.isNotEmpty ? name : (email.isNotEmpty ? email : null);
              if (display != null && !selectedContacts.contains(display)) selectedContacts.add(display);
            }
          }
          debugPrint('AppState: Appended ${arr.length} persisted recipients from sos_recipients');
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
      final contactsJson = contacts.map((c) => c.toString()).join('|');
      await prefs.setString('selected_contacts', contactsJson);
      debugPrint('AppState: Saved contacts to preferences: $contactsJson');
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
      default:
        break;
    }
    notifyListeners();
  }

  bool get allPermissionsGranted =>
      smsGranted &&
      contactsGranted &&
      locationGranted &&
      notificationsGranted &&
      microphoneGranted &&
      cameraGranted;
}

