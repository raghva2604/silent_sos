import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../src/app_state.dart';

/// Captures a small diagnostics report and writes it to the app documents
/// directory. Offers to share the resulting file.
Future<void> captureDiagnostics(BuildContext context, AppState appState) async {
  final buffer = StringBuffer();
  buffer.writeln('Silent SOS Diagnostics');
  buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
  buffer.writeln('');

  buffer.writeln('Selected contacts (${appState.selectedContacts.length}):');
  for (var c in appState.selectedContacts) {
    buffer.writeln(' - $c');
  }
  buffer.writeln('');

  buffer.writeln('AppState permissions (cached flags):');
  buffer.writeln(' sms: ${appState.smsGranted}');
  buffer.writeln(' contacts: ${appState.contactsGranted}');
  buffer.writeln(' location: ${appState.locationGranted}');
  buffer.writeln(' notifications: ${appState.notificationsGranted}');
  buffer.writeln(' camera: ${appState.cameraGranted}');
  buffer.writeln(' microphone: ${appState.microphoneGranted}');
  buffer.writeln('');

  buffer.writeln('Runtime permission states:');
  final perms = <String, Permission>{
    'sms': Permission.sms,
    'contacts': Permission.contacts,
    'location': Permission.location,
    'notifications': Permission.notification,
    'camera': Permission.camera,
    'microphone': Permission.microphone,
    'storage': Permission.storage,
  };

  for (final entry in perms.entries) {
    try {
      final status = await entry.value.status;
      buffer.writeln('${entry.key.padRight(12)} : ${status.toString()}');
    } catch (e) {
      buffer.writeln('${entry.key.padRight(12)} : error checking (${e.toString()})');
    }
  }

  buffer.writeln('');
  buffer.writeln('End of report');

  try {
    final dir = await getApplicationDocumentsDirectory();
    final safeTs = DateTime.now().toUtc().toIso8601String().replaceAll(':', '_');
    final file = File('${dir.path}/silent_sos_diagnostics_$safeTs.txt');
    await file.writeAsString(buffer.toString());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Diagnostics saved: ${file.path}')));
    }

    try {
      // Some versions of `share_plus` may not include `shareFiles`.
      // Fall back to sharing the file contents as plain text.
      final content = await file.readAsString();
      await Share.share(content, subject: 'Silent SOS diagnostics');
    } catch (_) {
      // Sharing is optional; ignore failures silently
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save diagnostics: $e')));
    }
  }
}
