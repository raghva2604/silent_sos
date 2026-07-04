import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../src/widgets/futuristic_background.dart';
import '../src/widgets/futuristic_option.dart';
import '../src/app_state.dart';
import 'dart:async';
import 'package:silent_sos/src/widgets/neon_widgets.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with SingleTickerProviderStateMixin {
  bool _allPermissionsGranted = false;
  final Map<String, bool> _permissionStatuses = {
    'Contacts': false,
    'Location': false,
    'Notifications': false,
    'Camera': false,
    'Microphone': false,
    'Phone': false,
    'SMS': false,
  };

  // All permissions are REQUIRED for app to function
  static const Map<String, Permission> _requiredPermissions = {
    'Contacts': Permission.contacts,
    'Location': Permission.locationAlways,
    'Notifications': Permission.notification,
    'Camera': Permission.camera,
    'Microphone': Permission.microphone,
    'Phone': Permission.phone,
    'SMS': Permission.sms,
  };

  late final AnimationController _anim;
  bool _requestingPermissions = false;

  @override
  
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    Future.delayed(const Duration(milliseconds: 200), () async {
      if (!mounted) return;
      _anim.forward();
      await _initializePermissions();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _initializePermissions() async {
    if (_requestingPermissions) return;
    _requestingPermissions = true;

    final prefs = await SharedPreferences.getInstance();
    final explainedBefore = prefs.getBool('permissions_explained') ?? false;

    if (!explainedBefore && mounted) {
      await _showPermissionExplanationOnce();
      await prefs.setBool('permissions_explained', true);
    }

    await _requestAllPermissionsSequentially();

    _requestingPermissions = false;
  }

  Future<void> _showPermissionExplanationOnce() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissions Required for Safety'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Silent SOS needs these permissions to keep you safe:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text('📞 Contacts - To store emergency contacts'),
              Text('📍 Location - To send your location at all times'),
              Text('💬 SMS - To send emergency SMS alerts'),
              Text('📷 Camera - To record video evidence'),
              Text('🎤 Microphone - For voice activation'),
              Text('🔔 Notifications - For emergency alerts'),
              Text('📞 Phone - For emergency calling'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (!mounted) return;
  }

  Future<void> _requestAllPermissionsSequentially() async {
    if (_requestingPermissions) return;
    _requestingPermissions = true;

    final appState = Provider.of<AppState>(context, listen: false);

    // Request all required permissions simply
    for (var entry in _requiredPermissions.entries) {
      try {
        final status = await entry.value.request();
        _permissionStatuses[entry.key] = status.isGranted;

        switch (entry.key) {
          case 'Contacts':
            appState.updatePermission?.call('contacts', status.isGranted);
            break;
          case 'Location':
            appState.updatePermission?.call('location', status.isGranted);
            break;
          case 'SMS':
            appState.updatePermission?.call('sms', status.isGranted);
            break;
          case 'Notifications':
            appState.updatePermission?.call('notifications', status.isGranted);
            break;
          case 'Camera':
            appState.updatePermission?.call('camera', status.isGranted);
            break;
          case 'Microphone':
            appState.updatePermission?.call('microphone', status.isGranted);
            break;
          case 'Phone':
            appState.updatePermission?.call('phone', status.isGranted);
            break;
          default:
            break;
        }

        setState(() {
          _allPermissionsGranted =
              _permissionStatuses.values.whereType<bool>().every((v) => v);
        });
      } catch (_) {
        // ignore
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    // All permissions are required to proceed
    const requiredPermissionKeys = {
      'Contacts',
      'Location',
      'Notifications',
      'Camera',
      'Microphone',
      'Phone',
      'SMS',
    };

    final allGranted = requiredPermissionKeys
        .every((key) => _permissionStatuses[key] == true);

    if (allGranted) {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.setPermissionsGranted();
      _allPermissionsGranted = true;

      // Navigate to the next screen instead of popping if this is the root.
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/permissions_complete');
        }
      }
      return;
    }

    if (mounted) {
      setState(() {
        _allPermissionsGranted = allGranted;
      });
    }
  }

  Widget _permissionTile(String name, bool granted, int index) {
    final anim = CurvedAnimation(
        parent: _anim,
        curve:
            Interval((index / 7).clamp(0.0, 1.0), 1.0, curve: Curves.easeOut));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(anim),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: granted
                ? Colors.black.withAlpha(80)
                : Colors.black.withAlpha(40),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: granted ? Colors.green.withAlpha(140) : Colors.white24),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (w, a) =>
                    ScaleTransition(scale: a, child: w),
                child: Icon(granted ? Icons.check_circle : Icons.cancel,
                    key: ValueKey<bool>(granted),
                    color: granted ? Colors.greenAccent : Colors.redAccent),
              ),
              const SizedBox(width: 12),
              Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(granted ? 'Granted' : 'Pending',
                  style: TextStyle(
                      color: granted ? Colors.greenAccent : Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: FuturisticBackground()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                        scale: Tween(begin: 0.9, end: 1.0).animate(
                            CurvedAnimation(
                                parent: _anim, curve: Curves.elasticOut)),
                        child: const Icon(Icons.security,
                            size: 86, color: Colors.white)),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _anim,
                      child: const Text('Enable Permissions',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                        opacity: _anim,
                        child: const Text(
                            'We need a few permissions to keep you safe.',
                            style: TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center)),
                    const SizedBox(height: 18),
                    const SizedBox(height: 8),
                    // Permission tiles (scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            FuturisticOption(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: _permissionTile(
                                        'Contacts',
                                        _permissionStatuses['Contacts'] ??
                                            false,
                                        0))),
                            const SizedBox(height: 8),
                            FuturisticOption(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: _permissionTile(
                                        'Microphone',
                                        _permissionStatuses['Microphone'] ??
                                            false,
                                        1))),
                            const SizedBox(height: 8),
                            FuturisticOption(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: _permissionTile(
                                        'Camera',
                                        _permissionStatuses['Camera'] ?? false,
                                        2))),
                            const SizedBox(height: 8),
                            FuturisticOption(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: _permissionTile(
                                        'Notifications',
                                        _permissionStatuses['Notifications'] ??
                                            false,
                                        3))),
                            const SizedBox(height: 8),
                            FuturisticOption(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: _permissionTile(
                                        'Phone',
                                        _permissionStatuses['Phone'] ?? false,
                                        4))),
                            const SizedBox(height: 8),
                            FuturisticOption(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: _permissionTile(
                                        'Location',
                                        _permissionStatuses['Location'] ?? false,
                                        5))),
                            const SizedBox(height: 8),
                            FuturisticOption(
                                child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: _permissionTile(
                                        'SMS',
                                        _permissionStatuses['SMS'] ?? false,
                                        6))),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ScaleTransition(
                      scale: Tween(begin: 0.95, end: 1.0).animate(
                          CurvedAnimation(
                              parent: _anim,
                              curve: const Interval(0.4, 1.0,
                                  curve: Curves.elasticOut))),
                      child: NeonButton(
                        onTap: () => _requestAllPermissionsSequentially(),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.shield, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                              _allPermissionsGranted
                                  ? 'All Set'
                                  : 'Grant Permissions',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_allPermissionsGranted)
                      NeonButton(
                          onTap: () => openAppSettings(),
                          child: const Text('Open App Settings')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
