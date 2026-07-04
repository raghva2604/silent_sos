import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsHelpScreen extends StatefulWidget {
  const PermissionsHelpScreen({super.key});

  @override
  State<PermissionsHelpScreen> createState() => _PermissionsHelpScreenState();
}

class _PermissionsHelpScreenState extends State<PermissionsHelpScreen> {
  PermissionStatus? _contacts;
  PermissionStatus? _location;
  PermissionStatus? _notification;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final cs = await Permission.contacts.status;
    final ls = await Permission.location.status;
    final ns = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _contacts = cs;
      _location = ls;
      _notification = ns;
    });
  }

  Widget _row(String title, PermissionStatus? s, VoidCallback onRequest) {
    return ListTile(
      title: Text(title),
      subtitle: Text(s?.toString() ?? 'Unknown'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(onPressed: onRequest, child: const Text('Request')),
        const SizedBox(width: 8),
        TextButton(
            onPressed: () async => await openAppSettings(),
            child: const Text('Open Settings')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _row('Contacts', _contacts, () async {
              await Permission.contacts.request();
              await _refresh();
            }),
            _row('Location (Foreground)', _location, () async {
              await Permission.location.request();
              await _refresh();
            }),
            _row('Location (Background)', null, () async {
              // request background location
              await Permission.locationAlways.request();
              await _refresh();
            }),
            _row('Notifications', _notification, () async {
              await Permission.notification.request();
              await _refresh();
            }),
            const SizedBox(height: 20),
            const Text(
                'Tip: If a permission is permanently denied, use Open Settings to enable it manually.'),
          ],
        ),
      ),
    );
  }
}
