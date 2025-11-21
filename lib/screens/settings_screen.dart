import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/foreground_service.dart';
import 'package:flutter/services.dart';
import '../services/media_recorder.dart';
import '../services/storage_service.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/futuristic_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _sosTimerDuration = 10.0;
  double _vibrationAmplitude = 160.0;
  double _fallThreshold = 4.2;
  double _sosRecordingDuration = 30.0;
  String _sosRecordingQuality = 'medium';
  String _includeMediaDefault = 'ask';
  
  bool _isLoading = true;
  bool _nativeAutoSend = false;
  bool _forceFullScreenOnDetection = false;
  
  bool _allowAutoAudio = false;
  bool _allowAutoVideo = false;
  bool _pushToTalkOptIn = false;
  double _voiceConfidenceThreshold = 0.7;
  String _voiceTriggers = '';
  bool _mergeVideos = true;
  List<String> _lastUploadedMedia = [];
  bool _triageOptIn = false;
  bool _useMedicalChat = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _sosTimerDuration = (prefs.getInt('sosTimerDuration') ?? 10).toDouble();
        _vibrationAmplitude = (prefs.getInt('vibrationAmplitude') ?? 160).toDouble();
        _fallThreshold = double.tryParse(prefs.getString('fallThreshold') ?? '') ?? (prefs.getDouble('fallThreshold') ?? 4.2);
        _sosRecordingDuration = (prefs.getInt('sosRecordingDuration') ?? 30).toDouble();
        _sosRecordingQuality = prefs.getString('sosRecordingQuality') ?? 'medium';
  _includeMediaDefault = prefs.getString('include_media_default') ?? 'ask';
        _nativeAutoSend = prefs.getBool('native_auto_send') ?? false;
  _forceFullScreenOnDetection = prefs.getBool('force_fullscreen_on_detection') ?? false;
        _allowAutoAudio = prefs.getBool('allow_auto_audio') ?? false;
        _allowAutoVideo = prefs.getBool('allow_auto_video') ?? false;
  _pushToTalkOptIn = prefs.getBool('push_to_talk_opt_in') ?? false;
  _voiceConfidenceThreshold = prefs.getDouble('voice_confidence_threshold') ?? 0.7;
  _voiceTriggers = prefs.getString('voice_triggers') ?? '';
        _mergeVideos = prefs.getBool('merge_videos') ?? true;
        _lastUploadedMedia = prefs.getStringList('last_uploaded_media') ?? [];
        _triageOptIn = prefs.getBool('triage_opt_in') ?? false;
        _useMedicalChat = prefs.getBool('use_medical_chat') ?? true;
        _isLoading = false;
      });
    } catch (e, st) {
      // Defensive: ensure UI doesn't stay stuck. Log and clear loading flag.
      debugPrint('Failed to load settings: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveTimerDuration(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sosTimerDuration', value.toInt());
    setState(() {
      _sosTimerDuration = value;
    });
  }

  Future<void> _saveVibrationAmplitude(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vibrationAmplitude', value.toInt());
    setState(() {
      _vibrationAmplitude = value;
    });
  }

  Future<void> _saveFallThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fallThreshold', value.toString());
    // push to native as well
    try {
      await ForegroundService.setThreshold(value);
    } catch (_) {}
    setState(() {
      _fallThreshold = value;
    });
  }

  Future<void> _saveNativeAutoSend(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      // Request SEND_SMS permission when enabling native auto-send
      try {
        final status = await Permission.sms.request();
        if (!status.isGranted) {
          // Permission denied; do not enable
          await prefs.setBool('native_auto_send', false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SEND_SMS permission is required to enable native auto-send')));
          }
          setState(() => _nativeAutoSend = false);
          return;
        }
      } catch (_) {}
    }
    await prefs.setBool('native_auto_send', value);
    // If enabling native auto-send, ensure media inclusion defaults to 'always'
    // when the user has opted into automatic video. This makes the native
    // auto-send include the persisted `last_uploaded_media` links without
    // requiring an extra manual confirmation.
    if (value) {
      // Enable allow_auto_video if not already enabled so recording will occur
      // during the in-app countdown flow. Note: background camera recording
      // while the app is fully backgrounded may not be possible on all OEMs.
      await prefs.setBool('allow_auto_video', true);
      await prefs.setString('include_media_default', 'always');
    }
    setState(() => _nativeAutoSend = value);
  }

  Future<void> _saveForceFullScreenOnDetection(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('force_fullscreen_on_detection', value);
    setState(() => _forceFullScreenOnDetection = value);
  }


  Future<void> _saveAllowAutoAudio(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allow_auto_audio', value);
    setState(() => _allowAutoAudio = value);
  }

  Future<void> _savePushToTalkOptIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_to_talk_opt_in', value);
    setState(() => _pushToTalkOptIn = value);
  }

  Future<void> _saveVoiceConfidenceThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('voice_confidence_threshold', value);
    setState(() => _voiceConfidenceThreshold = value);
  }

  Future<void> _saveVoiceTriggers(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_triggers', value);
    setState(() => _voiceTriggers = value);
  }

  Future<void> _saveAllowAutoVideo(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('allow_auto_video', value);
    setState(() => _allowAutoVideo = value);
  }

  Future<void> _saveMergeVideos(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('merge_videos', value);
    setState(() => _mergeVideos = value);
  }

  Future<void> _saveRecordingDuration(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sosRecordingDuration', value.toInt());
    setState(() {
      _sosRecordingDuration = value;
    });
  }

  Future<void> _saveRecordingQuality(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sosRecordingQuality', value);
    setState(() => _sosRecordingQuality = value);
  }

  Future<void> _saveIncludeMediaDefault(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('include_media_default', value);
    setState(() => _includeMediaDefault = value);
  }

  Future<void> _refreshLastUploadedMedia() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('last_uploaded_media') ?? [];
    setState(() => _lastUploadedMedia = list);
  }

  Future<void> _saveTriageOptIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('triage_opt_in', value);
    setState(() => _triageOptIn = value);
  }

  Future<void> _saveUseMedicalChat(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_medical_chat', value);
    setState(() => _useMedicalChat = value);
  }

  Future<void> _previewVibration() async {
    HapticFeedback.mediumImpact();
    // Also use the vibration plugin to show the chosen amplitude
    try {
      final amp = _vibrationAmplitude.toInt().clamp(1, 255);
      final has = await Vibration.hasVibrator() || await Vibration.hasCustomVibrationsSupport();
      if (has) {
        try {
          await Vibration.vibrate(duration: 250, amplitude: amp);
        } catch (_) {
          await Vibration.vibrate(duration: 250);
        }
      }
    } catch (_) {}
    // We also request the service to start briefly so native vibrate code can run if available.
    try {
      await ForegroundService.startService();
    } catch (_) {}
  }

  Future<void> _previewFallIntensity() async {
    // Map fall threshold to a demonstration amplitude so the user can feel effect
    // Higher threshold -> requires stronger impact -> show stronger vibration as preview
    // Map threshold range [3.0,12.0] to amplitude [80, 255]
    final minT = 3.0;
    final maxT = 12.0;
    final t = _fallThreshold.clamp(minT, maxT);
    final ratio = ((t - minT) / (maxT - minT)).clamp(0.0, 1.0);
    final amp = (80 + (ratio * (255 - 80))).toInt().clamp(1, 255);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Previewing fall -> vibration amplitude $amp')));
    try {
      final has = await Vibration.hasVibrator() || await Vibration.hasCustomVibrationsSupport();
      if (has) {
        try {
          await Vibration.vibrate(duration: 350, amplitude: amp);
        } catch (_) {
          await Vibration.vibrate(duration: 350);
        }
      }
    } catch (_) {}
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FuturisticHeader(title: 'Settings'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SOS Countdown Timer', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('10s', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: _sosTimerDuration,
                          min: 10,
                          max: 60,
                          divisions: 5,
                          label: '${_sosTimerDuration.toInt()} seconds',
                          onChanged: (value) {
                            setState(() {
                              _sosTimerDuration = value;
                            });
                          },
                          onChangeEnd: (value) {
                            _saveTimerDuration(value);
                          },
                        ),
                      ),
                      const Text('60s', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Center(child: Text('${_sosTimerDuration.toInt()} seconds', style: Theme.of(context).textTheme.titleMedium)),
                  const SizedBox(height: 20),

                  Text('Vibration Strength', style: Theme.of(context).textTheme.titleLarge),
                  Slider(
                    value: _vibrationAmplitude,
                    min: 50,
                    max: 255,
                    divisions: 20,
                    label: _vibrationAmplitude.toInt().toString(),
                    onChanged: (v) async {
                      setState(() => _vibrationAmplitude = v);
                      // Provide immediate tactile feedback while sliding so the user
                      // can feel the amplitude effect.
                      try {
                        final amp = _vibrationAmplitude.toInt().clamp(1, 255);
                        final has = await Vibration.hasVibrator() || await Vibration.hasCustomVibrationsSupport();
                        if (has) {
                          try {
                            await Vibration.vibrate(duration: 80, amplitude: amp);
                          } catch (_) {
                            await Vibration.vibrate(duration: 80);
                          }
                        }
                      } catch (_) {}
                    },
                    onChangeEnd: _saveVibrationAmplitude,
                  ),
                  Center(child: Text('${_vibrationAmplitude.toInt()}')),
                  const SizedBox(height: 12),
                  // Debug: show last uploaded media (helpful to verify persistence between Flutter and native)
                  Card(
                    color: const Color(0xFF071029),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Debug: last uploaded media', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (_lastUploadedMedia.isEmpty) const Text('No media persisted yet', style: TextStyle(color: Colors.white70)) else ...[
                            for (final u in _lastUploadedMedia.take(5)) Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Text(u, style: const TextStyle(fontSize: 12))),
                            if (_lastUploadedMedia.length > 5) Text('+ ${_lastUploadedMedia.length - 5} more', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                          const SizedBox(height: 8),
                          Row(children: [
                            ElevatedButton(onPressed: _refreshLastUploadedMedia, child: const Text('Refresh')),
                            const SizedBox(width: 8),
                            ElevatedButton(onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await Clipboard.setData(ClipboardData(text: _lastUploadedMedia.join('\n')));
                              if (!mounted) return;
                              messenger.showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                            }, child: const Text('Copy')),
                          ])
                        ],
                      ),
                    ),
                  ),

                  Text('Fall Detection Threshold (g)', style: Theme.of(context).textTheme.titleLarge),
                  Slider(
                    value: _fallThreshold,
                    min: 3.0,
                    max: 12.0,
                    divisions: 90,
                    label: _fallThreshold.toStringAsFixed(2),
                    onChanged: (v) => setState(() => _fallThreshold = v),
                    onChangeEnd: _saveFallThreshold,
                  ),
                  Center(child: Text('${_fallThreshold.toStringAsFixed(2)} g')),
                  const SizedBox(height: 20),

                  SwitchListTile.adaptive(
                    title: const Text('Native auto-send SMS on detection'),
                    value: _nativeAutoSend,
                    onChanged: (v) => _saveNativeAutoSend(v),
                    secondary: const Icon(Icons.send),
                  ),

                  SwitchListTile.adaptive(
                    title: const Text('Show SOS UI above other apps'),
                    subtitle: const Text('When enabled the app will attempt to display the SOS UI as a full-screen/overlay on detection (may require additional permissions on some devices).'),
                    value: _forceFullScreenOnDetection,
                    onChanged: (v) => _saveForceFullScreenOnDetection(v),
                    secondary: const Icon(Icons.fullscreen),
                  ),
                  // WhatsApp options are removed from the app UI to prioritize SMS and server-based flows.

                  SwitchListTile.adaptive(
                    title: const Text('Allow automatic audio send'),
                    subtitle: const Text('When enabled, the app may automatically record short audio after an SOS is triggered (requires explicit opt-in).'),
                    value: _allowAutoAudio,
                    onChanged: (v) => _saveAllowAutoAudio(v),
                    secondary: const Icon(Icons.mic),
                  ),

                  SwitchListTile.adaptive(
                    title: const Text('Enable Push-to-Talk (voice commands)'),
                    subtitle: const Text('Allow initiating SOS via short voice commands (requires opt-in).'),
                    value: _pushToTalkOptIn,
                    onChanged: (v) => _savePushToTalkOptIn(v),
                    secondary: const Icon(Icons.record_voice_over),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Voice confidence threshold', style: Theme.of(context).textTheme.bodyLarge),
                        Slider(
                          value: _voiceConfidenceThreshold,
                          min: 0.4,
                          max: 0.95,
                          divisions: 11,
                          label: _voiceConfidenceThreshold.toStringAsFixed(2),
                          onChanged: (v) => setState(() => _voiceConfidenceThreshold = v),
                          onChangeEnd: (v) => _saveVoiceConfidenceThreshold(v),
                        ),
                        Text('Minimum confidence required to accept voice commands: ${(_voiceConfidenceThreshold * 100).toInt()}%'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text('Custom voice triggers (comma-separated)', style: Theme.of(context).textTheme.bodyLarge),
                  TextFormField(
                    initialValue: _voiceTriggers,
                    decoration: const InputDecoration(hintText: 'e.g. help, emergency, assist me'),
                    onFieldSubmitted: (v) => _saveVoiceTriggers(v),
                    onChanged: (v) => setState(() => _voiceTriggers = v),
                  ),

                  SwitchListTile.adaptive(
                    title: const Text('Allow automatic video send'),
                    subtitle: const Text('When enabled, the app may automatically record short video after an SOS is triggered (requires explicit opt-in).'),
                    value: _allowAutoVideo,
                    onChanged: (v) => _saveAllowAutoVideo(v),
                    secondary: const Icon(Icons.videocam),
                  ),

                  const SizedBox(height: 8),
                  // Doctor AI & Medical Chat toggles
                  SwitchListTile.adaptive(
                    title: const Text('Enable Doctor AI triage (server) ⚕️'),
                    subtitle: const Text('When enabled, uploaded media and context may be sent to the configured Doctor AI webhook for triage. Requires consent.'),
                    value: _triageOptIn,
                    onChanged: (v) => _saveTriageOptIn(v),
                    secondary: const Icon(Icons.health_and_safety_outlined),
                  ),

                  SwitchListTile.adaptive(
                    title: const Text('Show Medical Assistant (chat) in app'),
                    subtitle: const Text('Toggle to show/hide the in-app AI chat assistant.'),
                    value: _useMedicalChat,
                    onChanged: (v) => _saveUseMedicalChat(v),
                    secondary: const Icon(Icons.chat_bubble_outline),
                  ),

                  const SizedBox(height: 6),
                  // Default include-media behavior for each SOS
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _includeMediaDefault,
                          decoration: const InputDecoration(labelText: 'Default include media'),
                          items: const [
                            DropdownMenuItem(value: 'ask', child: Text('Ask each time')),
                            DropdownMenuItem(value: 'always', child: Text('Always include media')),
                            DropdownMenuItem(value: 'never', child: Text('Never include media')),
                          ],
                          onChanged: (v) {
                            if (v != null) _saveIncludeMediaDefault(v);
                          },
                        ),
                      ),
                    ],
                  ),

                  SwitchListTile.adaptive(
                    title: const Text('Merge front+back into single video'),
                    subtitle: const Text('If enabled, the app will merge the back+front clips into one file before upload/share (may increase processing time).'),
                    value: _mergeVideos,
                    onChanged: (v) => _saveMergeVideos(v),
                    secondary: const Icon(Icons.merge_type),
                  ),

                  // WhatsApp backend settings removed from the UI.

                  const Divider(),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _previewVibration,
                    icon: const Icon(Icons.vibration),
                label: Text('Preview vibration & ensure service started'),
                  ),
                  const SizedBox(height: 12),

                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.98, end: 1.0),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: ElevatedButton.icon(
                      onPressed: () async {
                      // Quick debug action: record a short video and upload to verify pipeline.
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(const SnackBar(content: Text('Starting short recording...')));
                      try {
                        final path = await MediaRecorder.recordVideo(seconds: 8);
                        final file = File(path);
                        final remote = 'sos_media/test_${DateTime.now().millisecondsSinceEpoch}.mp4';
                          try {
                            final url = await StorageService.uploadFile(file, remote);
                            messenger.showSnackBar(SnackBar(content: Text('Uploaded: $url')));
                          } catch (e) {
                            // Storage unavailable (billing disabled) or upload failed — fallback to share sheet
                            messenger.showSnackBar(const SnackBar(content: Text('Upload failed, opening share sheet...')));
                              try {
                                await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'SOS test media'));
                              } catch (se) {
                                messenger.showSnackBar(SnackBar(content: Text('Share failed: $se')));
                              }
                          }
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text('Record failed: $e')));
                      }
                    },
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Test record & upload (8s)'),
                    ),
                  ),

                  const SizedBox(height: 18),
                  Text('Automatic video length (seconds)', style: Theme.of(context).textTheme.titleLarge),
                  Slider(
                    value: _sosRecordingDuration,
                    min: 30,
                    max: 60,
                    divisions: 3,
                    label: '${_sosRecordingDuration.toInt()}s',
                    onChanged: (v) => setState(() => _sosRecordingDuration = v),
                    onChangeEnd: (v) => _saveRecordingDuration(v),
                  ),
                  Center(child: Text('${_sosRecordingDuration.toInt()} seconds')),
                  const SizedBox(height: 10),
                  // Recording quality selector to control automatic SOS recording
                  const SizedBox(height: 12),
                  Text('Recording quality', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _sosRecordingQuality,
                          items: const [
                            DropdownMenuItem(value: 'veryLow', child: Text('Very low (small)')),
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(value: 'high', child: Text('High (large files)')),
                          ],
                          onChanged: (v) {
                            if (v != null) _saveRecordingQuality(v);
                          },
                        ),
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _previewVibration,
                          icon: const Icon(Icons.vibration),
                          label: const Text('Preview vibration'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _previewFallIntensity,
                          icon: const Icon(Icons.sensors),
                          label: const Text('Preview fall intensity'),
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
    );
  }
}
