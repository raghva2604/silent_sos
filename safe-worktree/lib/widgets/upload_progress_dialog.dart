import 'package:flutter/material.dart';
import 'package:silent_sos/services/sos_integration.dart';

/// Dialog widget for displaying native SOS recording upload progress.
///
/// Shows real-time progress updates during upload and displays success/error states.
/// Automatically closes on successful upload after a brief success message.
///
/// ## Usage
///
/// ```dart
/// final result = await showDialog<Map<String, dynamic>>(
///   context: context,
///   barrierDismissible: false,
///   builder: (ctx) => const UploadProgressDialog(),
/// );
///
/// if (result?['success'] == true) {
///   print('Upload succeeded: ${result?["payload"]}');
/// }
/// ```
class UploadProgressDialog extends StatefulWidget {
  const UploadProgressDialog({super.key});

  @override
  State<UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog> {
  int _progress = 0;
  bool _isCompleted = false;
  bool _isSuccess = false;
  String _errorMessage = '';
  String _responsePayload = '';

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  /// Sets up listeners for upload progress and completion events.
  void _setupListeners() {
    SosIntegration.setOnUploadProgress((progress) {
      if (!mounted) return;
      setState(() {
        _progress = progress;
      });
      debugPrint('[UploadProgressDialog] Progress: $_progress%');
    });

    SosIntegration.setOnUploadComplete((result) {
      if (!mounted) return;
      setState(() {
        _isCompleted = true;
        _isSuccess = result['success'] as bool? ?? false;
        _errorMessage = result['error'] as String? ?? '';
        _responsePayload = result['payload'] as String? ?? '';
      });
      debugPrint('[UploadProgressDialog] Upload complete: success=$_isSuccess');

      // Auto-close dialog after 2 seconds if successful
      if (_isSuccess) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context)
                .pop({'success': true, 'payload': _responsePayload});
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recording Upload'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isCompleted) ...[
              // Show progress bar during upload
              LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 8,
              ),
              const SizedBox(height: 16),
              Text(
                '$_progress%',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Uploading to backend...',
                textAlign: TextAlign.center,
              ),
            ] else if (_isSuccess) ...[
              // Show success state
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Upload Successful!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_responsePayload.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Backend Response:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    _responsePayload,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 5,
                  ),
                ),
              ]
            ] else ...[
              // Show error state
              const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Upload Failed',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage.isNotEmpty ? _errorMessage : 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isCompleted)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
      ],
    );
  }
}
