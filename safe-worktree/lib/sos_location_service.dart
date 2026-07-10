import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
// Foreground task package usage removed for compatibility with current project setup.
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSLocationService {
  static final SOSLocationService _instance = SOSLocationService._internal();
  factory SOSLocationService() => _instance;
  SOSLocationService._internal();

  late StreamSubscription<Position> _locationSubscription;
  bool _isTracking = false;
  DateTime? _lastSent;

  // Replace with real contacts from settings
  // Default emergency helpline number (India) - 108
  final List<String> _emergencyContacts = const ['108'];

  Future<void> startSOSTracking(BuildContext context) async {
    if (_isTracking) return;

    var locationStatus = await Permission.location.request();
    var smsStatus = await Permission.sms.request();
    if (!locationStatus.isGranted || !smsStatus.isGranted) {
      if (context.mounted) {
        _showError(context, "Location and SMS permissions required for SOS.");
      }
      return;
    }

    var bgStatus = await Permission.locationAlways.request();
    if (!bgStatus.isGranted) {
      if (!context.mounted) return;
      _showBackgroundGuidance(context);
      return;
    }

    // Start location updates and send initial SOS. Foreground service
    // integration was removed to avoid incompatible API calls.
    if (!context.mounted) return;
    _sendInitialSOS();
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((Position pos) {
      if (_lastSent == null ||
          DateTime.now().difference(_lastSent!) > const Duration(seconds: 30)) {
        _sendLocationUpdate(pos);
        _lastSent = DateTime.now();
      }
    });

    _isTracking = true;
  }

  Future<void> stopSOSTracking() async {
    if (!_isTracking) return;
    await _locationSubscription.cancel();
    _isTracking = false;
  }

  void _sendInitialSOS() {
    const message = "🚨 EMERGENCY! I need help. Starting location sharing.";
    _sendSmsToAll(message);
  }

  void _sendLocationUpdate(Position pos) {
    final message =
        "📍 My location: https://maps.google.com/?q=${pos.latitude},${pos.longitude}";
    _sendSmsToAll(message);
  }

  void _sendSmsToAll(String message) {
    for (var number in _emergencyContacts) {
      _sendSms(number, message);
    }
  }

  /// Public helper: send SMS to a provided list of phone numbers.
  Future<void> sendSmsToNumbers(List<String> numbers, String message) async {
    for (var number in numbers) {
      await _sendSms(number, message);
    }
  }

  Future<void> _sendSms(String to, String message) async {
    final Uri uri = Uri.parse('smsto:$to?body=${Uri.encodeFull(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Provide user feedback when the SMS intent cannot be opened
        // Best-effort: show a Snackbar via the app's root navigator if possible.
        debugPrint('Cannot launch SMS intent for $to');
      }
    } catch (e) {
      debugPrint('Error launching SMS intent for $to: $e');
    }
  }

  void _showError(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showBackgroundGuidance(BuildContext context) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Background Location'),
          content: const Text(
              'Go to Settings > Apps > SilentSOS > Permissions > Location\n'
              'and select “Allow all the time”.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'))
          ],
        ),
      );
    }
  }
}
