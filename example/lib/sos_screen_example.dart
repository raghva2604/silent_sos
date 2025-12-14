// Example usage of UploadProgressDialog in a real app screen.
// This file demonstrates best practices for integrating the upload progress widget
// into your SOS trigger flow.

import 'package:flutter/material.dart';
import 'package:silent_sos/services/sos_integration.dart';
import 'package:silent_sos/widgets/upload_progress_dialog.dart';

/// Example SOS screen showing how to use UploadProgressDialog.
///
/// **NOTE:** This is an example implementation. Adapt to your app's architecture.
class ExampleSosScreen extends StatefulWidget {
  const ExampleSosScreen({super.key});

  @override
  State<ExampleSosScreen> createState() => _ExampleSosScreenState();
}

class _ExampleSosScreenState extends State<ExampleSosScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize upload listeners once during app startup
    // (preferably in main() instead of here)
    SosIntegration.initializeUploadListeners();
  }

  /// Trigger SOS send with upload progress tracking.
  Future<void> _triggerSos() async {
    try {
      // Show upload progress dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const UploadProgressDialog(),
      );

      if (result?['success'] == true) {
        // Handle successful upload
        final payload = result?['payload'] as String? ?? '{}';
        debugPrint('Upload succeeded: $payload');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Handle failed upload
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('SOS upload failed: ${result?["error"] ?? "unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error triggering SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Start native audio recording with upload progress tracking.
  Future<void> _startNativeRecording() async {
    try {
      // Show upload progress dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const UploadProgressDialog(),
      );

      if (result?['success'] == true) {
        debugPrint('Recording uploaded: ${result?["payload"]}');
      }

      // Start recording
      await SosIntegration.startNativeRecording(
        maxSeconds: 60,
        label: 'sos_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      // Stop recording after 60 seconds or on user action
      await Future.delayed(const Duration(seconds: 60));
      await SosIntegration.stopNativeRecording();
      // Upload starts automatically, dialog shows progress
    } catch (e) {
      debugPrint('Error with native recording: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _triggerSos,
              icon: const Icon(Icons.emergency),
              label: const Text('Trigger SOS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startNativeRecording,
              icon: const Icon(Icons.mic),
              label: const Text('Record Audio'),
            ),
          ],
        ),
      ),
    );
  }
}
