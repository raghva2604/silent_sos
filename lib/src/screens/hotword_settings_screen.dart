import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Screen for managing Vosk hotword model downloads and always-listening detection.
///
/// Provides UI for:
/// - Downloading and extracting hotword model archives
/// - Configuring model URL and storage location
/// - Enabling/disabling background hotword detection
/// - Real-time progress updates during download
class HotwordSettingsScreen extends StatefulWidget {
  const HotwordSettingsScreen({super.key});

  @override
  State<HotwordSettingsScreen> createState() => _HotwordSettingsScreenState();
}

class _HotwordSettingsScreenState extends State<HotwordSettingsScreen> {
  static const MethodChannel _hotwordChannel = MethodChannel('silent_sos/hotword');
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  int _downloadProgress = 0;
  String _status = '';
  bool _serviceRunning = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _hotwordChannel.setMethodCallHandler(_nativeMessageHandler);
  }

  /// Handles native method channel callbacks for download progress and completion.
  Future<void> _nativeMessageHandler(MethodCall call) async {
    // Handle progress and completion events from native downloader
    if (call.method == 'hotwordDownloadProgress') {
      final int progress = (call.arguments is int)
          ? call.arguments as int
          : int.tryParse(call.arguments.toString()) ?? 0;

      setState(() {
        if (progress == -2) {
          _status = 'Retrying download...';
        } else if (progress == -1) {
          _status = 'Downloading (unknown size)...';
        } else if (progress >= 0) {
          _downloadProgress = progress;
          _status = 'Downloading: $progress%';
        }
        _isDownloading = true;
      });
    } else if (call.method == 'hotwordDownloadCompleted') {
      // Save the model directory path so HotwordService can load it
      final prefs = await SharedPreferences.getInstance();
      const modelDir = "/data/data/com.example.silent_sos/files/vosk-models";
      await prefs.setString('hotword_model_dir', modelDir);

      setState(() {
        _isDownloading = false;
        _downloadProgress = 100;
        _status = 'Download complete';
      });
    } else if (call.method == 'hotwordDownloadError') {
      final String error = call.arguments is String
          ? call.arguments as String
          : 'Unknown error';

      setState(() {
        _isDownloading = false;
        _downloadProgress = 0;
        _status = 'Download error: $error';
      });
    }
  }

  /// Load user preferences for hotword model URL and service state.
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('hotword_model_url') ?? '';
    final enabled = prefs.getBool('hotword_service_enabled') ?? false;

    setState(() {
      _urlController.text = url;
      _serviceRunning = enabled;
    });
  }

  /// Save the hotword model URL to persistent storage.
  Future<void> _saveUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hotword_model_url', _urlController.text.trim());
    setState(() {
      _status = 'URL saved';
    });
  }

  /// Initiate download of hotword model from configured URL.
  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _status = 'Enter a model URL first');
      return;
    }

    await _saveUrl();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _status = 'Starting download...';
    });

    try {
      final res = await _hotwordChannel.invokeMethod('downloadVoskModel', {'url': url});
      if (res == true) {
        // Native side will asynchronously report progress via method channel
        setState(() {
          _status = 'Download started...';
        });
      } else {
        setState(() {
          _isDownloading = false;
          _status = 'Failed to start download';
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _isDownloading = false;
        _status = 'Error: ${e.message}';
      });
    }
  }

  /// Cancel ongoing hotword model download.
  Future<void> _cancelDownload() async {
    try {
      await _hotwordChannel.invokeMethod('cancelVoskDownload');
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0;
        _status = 'Download cancelled';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Cancel failed: ${e.message}';
      });
    }
  }

  /// Toggle background hotword detection service on/off.
  void _toggleService(bool enabled) async {
    try {
      // Save enabled state for boot auto-start
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hotword_service_enabled', enabled);

      if (enabled) {
        await _hotwordChannel.invokeMethod('startHotwordService');
      } else {
        await _hotwordChannel.invokeMethod('stopHotwordService');
      }
      setState(() {
        _serviceRunning = enabled;
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Service toggle failed: ${e.message}';
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotword Model Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vosk hotword model URL (zip archive). The app will download and extract to app files dir.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _urlController,
                enabled: !_isDownloading,
                decoration: const InputDecoration(
                  labelText: 'Hotword model URL',
                  border: OutlineInputBorder(),
                  hintText: 'https://example.com/vosk-model.zip',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save URL'),
                    onPressed: _isDownloading ? null : _saveUrl,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download model now'),
                    onPressed: _isDownloading ? null : _startDownload,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Download progress section
              if (_isDownloading) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Downloading...', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _downloadProgress > 0 ? _downloadProgress / 100.0 : null,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _downloadProgress > 0 
                            ? 'Progress: $_downloadProgress%' 
                            : 'Progress: indeterminate',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _cancelDownload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Cancel download'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: _status.startsWith('Download error') 
                    ? Colors.red.shade50 
                    : _status.contains('complete') || _status.contains('saved')
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 14,
                    color: _status.startsWith('Download error') 
                      ? Colors.red.shade900 
                      : _status.contains('complete') || _status.contains('saved')
                      ? Colors.green.shade900
                      : Colors.blue.shade900,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              
              // Service toggle
              SwitchListTile(
                title: const Text("Enable Always-Listening Hotword Detection"),
                subtitle: const Text("Background listening with Vosk model"),
                value: _serviceRunning,
                onChanged: _isDownloading ? null : _toggleService,
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              
              const Text(
                'Tips & Notes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '• On Android 13+, you may be prompted to allow notifications during download.\n'
                '• Download progress is shown in a system notification and in the app UI.\n'
                '• If download fails, the app will automatically retry with exponential backoff.\n'
                '• You can also push a model manually via adb:\n'
                '  adb push <model-folder> /sdcard/vosk-model-small',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

