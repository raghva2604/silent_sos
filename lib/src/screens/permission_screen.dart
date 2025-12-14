// lib/src/screens/permission_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/particle_background.dart';
import '../widgets/neon_widgets.dart';
import '../app_state.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  // This UI expects your AppState to be the provider with flags:
  // smsGranted, contactsGranted, locationGranted, notificationsGranted
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: ParticleBackground(color: Colors.tealAccent, count: 20, opacity: 0.05)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  const Icon(Icons.security, size: 64, color: Colors.white),
                  const SizedBox(height: 14),
                  const Text('Enable Permissions', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('We need a few permissions to keep you safe.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  // Privacy caution banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withAlpha(100)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: const Text(
                            'Camera & Audio may record in background when app is minimized.',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        _permCard('SMS', appState.smsGranted, Icons.message, () async {
                          final res = await Permission.sms.request();
                          appState.updatePermission?.call('sms', res.isGranted);
                          if (res.isPermanentlyDenied) openAppSettings();
                        }, description: 'Send emergency alerts to contacts'),
                        _permCard('Contacts', appState.contactsGranted, Icons.contacts, () async {
                          final res = await Permission.contacts.request();
                          appState.updatePermission?.call('contacts', res.isGranted);
                          if (res.isPermanentlyDenied) openAppSettings();
                        }, description: 'Access your emergency contacts'),
                        _permCard('Location', appState.locationGranted, Icons.location_on, () async {
                          final res = await Permission.location.request();
                          appState.updatePermission?.call('location', res.isGranted);
                          if (res.isPermanentlyDenied) openAppSettings();
                        }, description: 'Share your live location in emergencies'),
                        _permCard('Microphone', appState.notificationsGranted, Icons.mic, () async {
                          final res = await Permission.microphone.request();
                          appState.updatePermission?.call('microphone', res.isGranted);
                          if (res.isPermanentlyDenied) openAppSettings();
                        }, description: '⚠️ May record audio in background', isWarning: true),
                        _permCard('Camera', appState.notificationsGranted, Icons.camera_alt, () async {
                          final res = await Permission.camera.request();
                          appState.updatePermission?.call('camera', res.isGranted);
                          if (res.isPermanentlyDenied) openAppSettings();
                        }, description: '⚠️ May record video in background', isWarning: true),
                        _permCard('Notifications', appState.notificationsGranted, Icons.notifications, () async {
                          final res = await Permission.notification.request();
                          appState.updatePermission?.call('notifications', res.isGranted);
                          if (res.isPermanentlyDenied) openAppSettings();
                        }, description: 'Receive high-priority SOS alerts'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Neon "All Set" button; use enabled/disabled colors
                  GestureDetector(
                    onTap: appState.allPermissionsGranted
                        ? () => Navigator.of(context).pushReplacementNamed('/home')
                        : null,
                    child: Opacity(
                      opacity: appState.allPermissionsGranted ? 1.0 : 0.55,
                      child: NeonButton(
                        onTap: appState.allPermissionsGranted
                            ? () => Navigator.of(context).pushReplacementNamed('/home')
                            : () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.shield, color: Colors.white),
                            SizedBox(width: 10),
                            Text('All Set', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permCard(String label, bool granted, IconData icon, VoidCallback onTap, {String description = '', bool isWarning = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isWarning ? Colors.red.withAlpha(15) : Colors.white10,
          border: Border.all(
            color: granted ? Colors.greenAccent.withAlpha((0.7 * 255).round()) : (isWarning ? Colors.red.withAlpha(80) : Colors.white12),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: granted ? Colors.greenAccent.withAlpha((0.18 * 255).round()) : (isWarning ? Colors.red.withAlpha(30) : Colors.white12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(granted ? Icons.check : icon, color: granted ? Colors.greenAccent : (isWarning ? Colors.red : Colors.white70)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: granted
                      ? Text('✓ Granted', key: const ValueKey('g'), style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w800, fontSize: 12))
                      : Text('Allow', key: const ValueKey('a'), style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
                )
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isWarning ? Colors.orange : Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
