import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/foreground_service.dart';
import 'package:provider/provider.dart';
import '../src/app_state.dart';
import '../services/language_service.dart';
import 'package:vibration/vibration.dart';
import '../services/vibration_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../services/sos_service.dart';
// ignore_for_file: use_build_context_synchronously

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _sosTimerDuration = 10.0;
  double _vibrationAmplitude = 160.0;
  double _fallThreshold = 4.2;
  // Unused fields; uncomment when features are integrated
  // double _sosRecordingDuration = 30.0;
  // String _sosRecordingQuality = 'medium';
  // String _includeMediaDefault = 'ask';

  bool _isLoading = true;
  bool _nativeAutoSend = false;
  bool _forceFullScreenOnDetection = false;

  bool _allowAutoAudio = false;
  // Unused fields; uncomment when features are integrated
  // bool _allowAutoVideo = false;
  bool _pushToTalkOptIn = false;
  bool _autoFallSosEnabled = false;

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
        // _sosRecordingDuration = (prefs.getInt('sosRecordingDuration') ?? 30).toDouble();
        // _sosRecordingQuality = prefs.getString('sosRecordingQuality') ?? 'medium';
        // _includeMediaDefault = prefs.getString('include_media_default') ?? 'ask';
        _nativeAutoSend = prefs.getBool('native_auto_send') ?? false;
        _forceFullScreenOnDetection = prefs.getBool('force_fullscreen_on_detection') ?? false;
        _allowAutoAudio = prefs.getBool('allow_auto_audio') ?? false;
        // _allowAutoVideo = prefs.getBool('allow_auto_video') ?? false;
        _pushToTalkOptIn = prefs.getBool('push_to_talk_opt_in') ?? false;
        _autoFallSosEnabled = prefs.getBool('auto_fall_sos_enabled') ?? false;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to load settings: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTimerDuration(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sosTimerDuration', value.toInt());
    setState(() {
      _sosTimerDuration = value;
    });
    // Update AppState so Home uses new countdown immediately
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.setSosCountdown(value.toInt());
    } catch (_) {}
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
      try {
        final status = await Permission.sms.request();
        if (!status.isGranted) {
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
    if (value) {
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
    if (value) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        await prefs.setBool('push_to_talk_opt_in', false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission required for voice features')));
        setState(() => _pushToTalkOptIn = false);
        return;
      }
    }
    await prefs.setBool('push_to_talk_opt_in', value);
    setState(() => _pushToTalkOptIn = value);
  }

  Future<void> _saveAutoFallSosEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_fall_sos_enabled', value);
    setState(() => _autoFallSosEnabled = value);
    // Start or stop the fall detector accordingly
    if (value) {
      final appState = Provider.of<AppState>(context, listen: false);
      await SOSservice.startFallDetection(context, List<String>.from(appState.selectedContacts.map((e) => e.toString())));
    } else {
      await SOSservice.stopFallDetection();
    }
  }

  // Uncomment when voice/recording features are fully integrated:
  // Future<void> _saveVoiceConfidenceThreshold(double value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setDouble('voice_confidence_threshold', value);
  //   setState(() => _voiceConfidenceThreshold = value);
  // }

  // Future<void> _saveVoiceTriggers(String value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('voice_triggers', value);
  //   setState(() => _voiceTriggers = value);
  // }

  // Future<void> _saveAllowAutoVideo(bool value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool('allow_auto_video', value);
  //   setState(() => _allowAutoVideo = value);
  // }

  // Future<void> _saveMergeVideos(bool value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool('merge_videos', value);
  //   setState(() => _mergeVideos = value);
  // }

  // Future<void> _saveRecordingDuration(double value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setInt('sosRecordingDuration', value.toInt());
  //   setState(() {
  //     _sosRecordingDuration = value;
  //   });
  // }

  // Future<void> _saveRecordingQuality(String value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('sosRecordingQuality', value);
  //   setState(() => _sosRecordingQuality = value);
  // }

  // Future<void> _saveIncludeMediaDefault(String value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString('include_media_default', value);
  //   setState(() => _includeMediaDefault = value);
  // }

  // Future<void> _refreshLastUploadedMedia() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final list = prefs.getStringList('last_uploaded_media') ?? [];
  //   setState(() => _lastUploadedMedia = list);
  // }

  // Future<void> _saveUseMedicalChat(bool value) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setBool('use_medical_chat', value);
  //   setState(() => _useMedicalChat = value);
  // }

  // Vibration preview helper removed (unused). Keep implementation in VCS history if needed.

  // Future<void> _previewFallIntensity() async {
  //   final minT = 3.0;
  //   final maxT = 12.0;
  //   final t = _fallThreshold.clamp(minT, maxT);
  //   final ratio = ((t - minT) / (maxT - minT)).clamp(0.0, 1.0);
  //   final amp = (80 + (ratio * (255 - 80))).toInt().clamp(1, 255);
  //   final messenger = ScaffoldMessenger.of(context);
  //   messenger.showSnackBar(SnackBar(content: Text('Previewing fall -> vibration amplitude $amp')));
  //   try {
  //     final has = await Vibration.hasVibrator() || await Vibration.hasCustomVibrationsSupport();
  //     if (has) {
  //       try {
  //         await Vibration.vibrate(duration: 350, amplitude: amp);
  //       } catch (_) {
  //         await Vibration.vibrate(duration: 350);
  //       }
  //     }
  //   } catch (_) {}
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: GestureDetector(
          // Hidden: long-press the title to open developer settings (server URL / AI model)
          onLongPress: _showDevSettingsDialog,
          child: Text(LanguageService().t('settings'), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      _buildSectionHeader(LanguageService().t('sos_timer')),
                      const SizedBox(height: 12),
                      _buildSliderCard(
                        '${_sosTimerDuration.toInt()} ${LanguageService().t('seconds')}',
                        Slider(
                          value: _sosTimerDuration,
                          min: 10,
                          max: 60,
                          divisions: 5,
                          activeColor: Colors.teal,
                          label: '${_sosTimerDuration.toInt()}s',
                          onChanged: (value) {
                            setState(() => _sosTimerDuration = value);
                          },
                          onChangeEnd: _saveTimerDuration,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader(LanguageService().t('vibration_strength')),
                      const SizedBox(height: 12),
                      _buildSliderCard(
                        '${LanguageService().t('amplitude')}: ${_vibrationAmplitude.toInt()}',
                        Slider(
                          value: _vibrationAmplitude,
                          min: 50,
                          max: 255,
                          divisions: 20,
                          activeColor: Colors.teal,
                          label: _vibrationAmplitude.toInt().toString(),
                          onChanged: (v) async {
                            setState(() => _vibrationAmplitude = v);
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
                          onChangeEnd: (v) async {
                            await _saveVibrationAmplitude(v);
                            // Also update VibrationService intensity (map 50-255 -> 0-100)
                            final mapped = (((v - 50) / (255 - 50)) * 100).toInt().clamp(0, 100);
                            await VibrationService().setIntensity(mapped);
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader(LanguageService().t('fall_threshold')),
                      const SizedBox(height: 12),
                      _buildSliderCard(
                        '${_fallThreshold.toStringAsFixed(2)} g',
                        Slider(
                          value: _fallThreshold,
                          min: 3.0,
                          max: 12.0,
                          divisions: 90,
                          activeColor: Colors.teal,
                          label: _fallThreshold.toStringAsFixed(2),
                          onChanged: (v) => setState(() => _fallThreshold = v),
                          onChangeEnd: _saveFallThreshold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Preview fall vibration pattern
                              await VibrationService().vibrateFallAlertPattern();
                            },
                            icon: const Icon(Icons.vibration),
                            label: Text(LanguageService().t('preview_vibration')),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              // Toggle sample detection: show a snackbar to simulate
                              final prefs = await SharedPreferences.getInstance();
                              final enabled = prefs.getBool('fall_detection_enabled') ?? false;
                              await prefs.setBool('fall_detection_enabled', !enabled);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fall detection ${!enabled ? 'enabled' : 'disabled'}')));
                            },
                            child: const Text('Toggle Fall Detection'),
                          ),
                          const SizedBox(width: 8),
                          if (kDebugMode)
                            ElevatedButton.icon(
                              onPressed: () async {
                                final appState = Provider.of<AppState>(context, listen: false);
                                await SOSservice.simulateFall(context, List<String>.from(appState.selectedContacts.map((e) => e.toString())));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulated fall event')));
                              },
                              icon: const Icon(Icons.warning, color: Colors.white),
                              label: const Text('Simulate Fall', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Features'),
                      const SizedBox(height: 12),
                      // Language selector
                      _buildSectionHeader('Language'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))]),
                        child: FutureBuilder(
                          future: SharedPreferences.getInstance(),
                          builder: (ctx, snap) {
                            final ls = LanguageService();
                            final map = ls.availableLanguages;
                            final current = ls.currentLanguage;
                            return Row(
                              children: [
                                const Icon(Icons.language, color: Colors.black54),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: current,
                                    items: map.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                                    onChanged: (v) async {
                                      if (v == null) return;
                                      await ls.setLanguage(v);
                                      if (!mounted) return;
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language updated')));
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildToggleCard(
                        'Native Auto-Send SMS',
                        'Automatically send SOS via SMS on detection',
                        Icons.sms,
                        _nativeAutoSend,
                        (v) => _saveNativeAutoSend(v),
                      ),
                      const SizedBox(height: 10),
                      _buildToggleCard(
                        'Full-Screen on Detection',
                        'Show SOS UI above other apps',
                        Icons.fullscreen,
                        _forceFullScreenOnDetection,
                        (v) => _saveForceFullScreenOnDetection(v),
                      ),
                      const SizedBox(height: 10),
                      _buildToggleCard(
                        'Auto Audio Send',
                        'Automatically record audio on SOS',
                        Icons.mic,
                        _allowAutoAudio,
                        (v) => _saveAllowAutoAudio(v),
                      ),
                      const SizedBox(height: 10),
                      _buildToggleCard(
                        'Push-to-Talk',
                        'Use voice commands to trigger SOS',
                        Icons.record_voice_over,
                        _pushToTalkOptIn,
                        (v) => _savePushToTalkOptIn(v),
                      ),
                      const SizedBox(height: 10),
                      _buildToggleCard(
                        'Auto Fall SOS',
                        'Automatically trigger SOS on fall detection',
                        Icons.notifications_active,
                        _autoFallSosEnabled,
                        (v) => _saveAutoFallSosEnabled(v),
                      ),
                      const SizedBox(height: 12),
                      // Hotword settings entry
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hearing, color: Colors.black54, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Hotword Model', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text('Manage offline hotword model and download', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pushNamed(context, '/hotword-settings'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                              child: const Text('Open', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Manage recipients entry
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_add, color: Colors.black54, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Manage SOS Recipients', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text('Pick contacts to notify during SOS', style: TextStyle(color: Colors.black54, fontSize: 12)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              key: const Key('manage_recipients_button'),
                              onPressed: () => Navigator.pushNamed(context, '/recipients'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                              child: const Text('Open', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.teal,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSliderCard(String label, Widget slider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 12),
          slider,
        ],
      ),
    );
  }

  Widget _buildToggleCard(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? Colors.teal : Colors.black54, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.teal,
            activeTrackColor: Colors.teal.withAlpha(100),
          ),
        ],
      ),
    );
  }

  Future<void> _showDevSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final serverCtrl = TextEditingController(text: prefs.getString('server_url') ?? 'http://localhost:8000');
    final modelCtrl = TextEditingController(text: prefs.getString('ai_model') ?? 'claude-haiku-4.5');

    // The dialog uses a local builder context; we intentionally await it
    // and then use the state context after ensuring the widget is still
    // mounted. Suppress the lint here as we've moved UI updates after the
    // dialog completes and check `mounted` before using `context`.
    final result = await showDialog<Map<String,String>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Developer Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: serverCtrl,
                decoration: const InputDecoration(labelText: 'Server URL', hintText: 'http://localhost:8000'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: 'AI Model', hintText: 'claude-haiku-4.5'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final server = serverCtrl.text.trim();
                final model = modelCtrl.text.trim();
                Navigator.pop(ctx, {'server': server, 'model': model});
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final server = result['server'] ?? '';
      final model = result['model'] ?? '';
      await prefs.setString('server_url', server);
      await prefs.setString('ai_model', model);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(const SnackBar(content: Text('Developer settings saved')));
    }

    serverCtrl.dispose();
    modelCtrl.dispose();
  }
}
