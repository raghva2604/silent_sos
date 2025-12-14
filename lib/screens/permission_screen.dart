import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../src/widgets/futuristic_background.dart';
import '../src/widgets/futuristic_option.dart';
import 'dart:async';
import '../src/screens/home_screen.dart';
import 'package:silent_sos/src/widgets/neon_widgets.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with SingleTickerProviderStateMixin {
  bool _allPermissionsGranted = false;
  final Map<String, bool> _permissionStatuses = {};
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    // Initialize map with false values so UI can animate entries
    _permissionStatuses['SMS'] = false;
    _permissionStatuses['Contacts'] = false;
    _permissionStatuses['Location'] = false;
    _permissionStatuses['Notifications'] = false;
    // Start requesting after a short delay to allow entrance animation
    Future.delayed(const Duration(milliseconds: 300), () async {
      _anim.forward();
      await _requestPermissions(showAnimated: true);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions({bool showAnimated = false}) async {
    // Skip permission checks on web platform
    if (kIsWeb) {
      setState(() {
        _permissionStatuses['SMS'] = true;
        _permissionStatuses['Contacts'] = true;
        _permissionStatuses['Location'] = true;
        _permissionStatuses['Notifications'] = true;
        _allPermissionsGranted = true;
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      return;
    }

    // Request SMS
    var smsStatus = await Permission.sms.status;
    _permissionStatuses['SMS'] = smsStatus.isGranted;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 120));

    // If SMS is not granted, show an explanation card with a button to request it explicitly
    if (!smsStatus.isGranted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('SMS Permission required'),
            content: const Text('To enable fully automatic SOS sending (without opening your SMS app), SilentSOS needs permission to send SMS on your behalf. You can choose to grant this now.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
              ElevatedButton(onPressed: () async {
                Navigator.pop(ctx);
                final res = await Permission.sms.request();
                if (!mounted) return;
                setState(() => _permissionStatuses['SMS'] = res.isGranted);
                if (res.isPermanentlyDenied) {
                  // Offer to open app settings
                  showDialog(context: context, builder: (sctx) => AlertDialog(
                    title: const Text('Open Settings'),
                    content: const Text('SMS permission is permanently denied. Please open App Settings to grant it.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(sctx), child: const Text('Close')), TextButton(onPressed: () { Navigator.pop(sctx); openAppSettings(); }, child: const Text('Open Settings'))],
                  ));
                }
              }, child: const Text('Grant SMS')),
            ],
          ),
        );
      });
    }

    // Request Contacts
    var contactStatus = await Permission.contacts.request();
    _permissionStatuses['Contacts'] = contactStatus.isGranted;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 120));

    // Request Location (foreground)
    var locationStatus = await Permission.location.request();
    _permissionStatuses['Location'] = locationStatus.isGranted;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 120));

    // Request Notifications
    var notificationStatus = await Permission.notification.request();
    _permissionStatuses['Notifications'] = notificationStatus.isGranted;
    setState(() {});

  // Request Camera and Microphone (needed for automatic recording)
  var cameraStatus = await Permission.camera.request();
  _permissionStatuses['Camera'] = cameraStatus.isGranted;
  setState(() {});
  await Future.delayed(const Duration(milliseconds: 120));

  var micStatus = await Permission.microphone.request();
  _permissionStatuses['Microphone'] = micStatus.isGranted;
  setState(() {});

    bool allGranted = _permissionStatuses.values.every((granted) => granted);

    setState(() {
      _allPermissionsGranted = allGranted;
    });

    if (allGranted) {
      // give a short animated success pause then navigate
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Widget _permissionTile(String name, bool granted, int index) {
    final anim = CurvedAnimation(parent: _anim, curve: Interval((index / 6).clamp(0.0, 1.0), 1.0, curve: Curves.easeOut));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(anim),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: granted ? Colors.black.withAlpha(80) : Colors.black.withAlpha(40),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: granted ? Colors.green.withAlpha(140) : Colors.white24),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (w, a) => ScaleTransition(scale: a, child: w),
                child: Icon(granted ? Icons.check_circle : Icons.cancel, key: ValueKey<bool>(granted), color: granted ? Colors.greenAccent : Colors.redAccent),
              ),
              const SizedBox(width: 12),
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(granted ? 'Granted' : 'Pending', style: TextStyle(color: granted ? Colors.greenAccent : Colors.white70)),
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
                    ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.elasticOut)), child: const Icon(Icons.security, size: 86, color: Colors.white)),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _anim,
                      child: const Text('Enable Permissions', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(opacity: _anim, child: const Text('We need a few permissions to keep you safe.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center)),
                    const SizedBox(height: 18),
                    const SizedBox(height: 8),
                    // Permission tiles (scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            FuturisticOption(child: Padding(padding: const EdgeInsets.all(8.0), child: _permissionTile('SMS', _permissionStatuses['SMS'] ?? false, 0))),
                            const SizedBox(height: 8),
                            FuturisticOption(child: Padding(padding: const EdgeInsets.all(8.0), child: _permissionTile('Contacts', _permissionStatuses['Contacts'] ?? false, 1))),
                            const SizedBox(height: 8),
                            FuturisticOption(child: Padding(padding: const EdgeInsets.all(8.0), child: _permissionTile('Location', _permissionStatuses['Location'] ?? false, 2))),
                            const SizedBox(height: 8),
                            FuturisticOption(child: Padding(padding: const EdgeInsets.all(8.0), child: _permissionTile('Notifications', _permissionStatuses['Notifications'] ?? false, 3))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ScaleTransition(
                      scale: Tween(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: const Interval(0.4, 1.0, curve: Curves.elasticOut))),
                      child: NeonButton(
                        onTap: () => _requestPermissions(),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.shield, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(_allPermissionsGranted ? 'All Set' : 'Grant Permissions', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_allPermissionsGranted)
                      NeonButton(onTap: () => openAppSettings(), child: const Text('Open App Settings')),
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