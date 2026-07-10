import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../src/app_state.dart';
import '../services/auth_service.dart';
import '../services/fall_detector.dart';
import '../services/language_service.dart';
import '../services/purchase_service.dart';
import '../sos/sos_controller.dart';
import 'premium_upgrade_screen.dart';
import 'privacy_policy_screen.dart';
import 'fake_call_screen.dart';

// ignore_for_file: use_build_context_synchronously
import '../config/api_config.dart';
import '../services/message_templates.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _sosTimerDuration = 10.0;
  // Safe Walk duration in minutes
  int _safeWalkMinutes = 15;
  // ignore: unused_field
  double _vibrationAmplitude = 160.0;
  // ignore: unused_field
  double _fallThreshold = 12.0;
  // ignore: unused_field
  double _fallSensitivity = 1.0;
  bool _isLoading = true;
  bool _autoModeEnabled = false; // toggle between manual/automatic SOS
  // ignore: unused_field
  bool _autoOpenOnFall = true;
  String _selectedTemplate = 'Select message...';

  // Fake call settings
  String _fakeCallMessage =
      'Hello, we are calling from the control room. Are you okay? Please respond.';
  late TextEditingController _fakeCallController;
  String _fakeCallerName = 'Police';
  late TextEditingController _fakeCallerNameController;
  int _fakeCallDelay = 3; // delay in seconds before fake call appears
  bool _autoFakeCallEnabled = true; // toggle for automatic fake call after SOS

  // Auto call message (for when someone picks up the call)
  String _autoCallMessage =
      'Emergency alert. This person is in danger. Please check location sent via SMS or email immediately.';
  late TextEditingController _autoCallMessageController;

  // Smart call settings
  int _retryCount = 1; // number of retry attempts per contact
  int _trackingInterval = 10; // seconds between location updates

  @override
  void initState() {
    super.initState();
    _fakeCallController = TextEditingController(text: _fakeCallMessage);
    _fakeCallerNameController = TextEditingController(text: _fakeCallerName);
    _autoCallMessageController = TextEditingController(text: _autoCallMessage);
    _loadSettings();
  }

  @override
  void dispose() {
    _fakeCallController.dispose();
    _fakeCallerNameController.dispose();
    _autoCallMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _sosTimerDuration = (prefs.getInt('sosTimerDuration') ?? 10).toDouble();
        _safeWalkMinutes = prefs.getInt('safe_walk_duration_minutes') ?? 15;
        _vibrationAmplitude =
            (prefs.getInt('vibrationAmplitude') ?? 160).toDouble();
        _fallThreshold = prefs.getDouble('fall_threshold') ??
            double.tryParse(prefs.getString('fallThreshold') ?? '') ??
            prefs.getDouble('fallThreshold') ??
            12.0;
        _fallSensitivity = prefs.getDouble('fall_sensitivity') ??
            prefs.getDouble('fallSensitivity') ??
            1.0;
        _autoModeEnabled = prefs.getBool('auto_mode_enabled') ?? false;
        debugPrint('SettingsScreen: auto_mode_enabled = $_autoModeEnabled');
        _autoOpenOnFall = prefs.getBool('autoOpenOnFall') ?? true;
        _selectedTemplate = prefs.getString('sos_message_template') ??
            SosTemplates.getDefault();

        // Fake call settings
        _fakeCallMessage =
            prefs.getString('fake_call_message') ?? _fakeCallMessage;
        _fakeCallerName = prefs.getString('fake_caller_name') ?? 'Police';
        _fakeCallDelay = prefs.getInt('fake_call_delay') ?? 3;
        _autoFakeCallEnabled = prefs.getBool('auto_fake_call_enabled') ?? true;
        _autoCallMessage =
            prefs.getString('auto_call_message') ?? _autoCallMessage;
        _fakeCallController.text = _fakeCallMessage;
        _fakeCallerNameController.text = _fakeCallerName;
        _autoCallMessageController.text = _autoCallMessage;

        // Smart call settings
        _retryCount = prefs.getInt('retry_count') ?? 1;
        _trackingInterval = prefs.getInt('tracking_interval') ?? 10;

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

  Future<void> _saveSafeWalkMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('safe_walk_duration_minutes', minutes);
    setState(() => _safeWalkMinutes = minutes);
  }

  // ignore: unused_element
  Future<void> _saveVibrationAmplitude(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vibrationAmplitude', value.toInt());
    setState(() {
      _vibrationAmplitude = value;
    });
  }

  // ignore: unused_element
  Future<void> _saveFallThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fall_threshold', value);
    await prefs.setDouble('fallThreshold', value);
    try {
      await FallDetector.setThreshold(value);
    } catch (_) {}
    setState(() {
      _fallThreshold = value;
    });
  }

  // ignore: unused_element
  Future<void> _saveFallSensitivity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fall_sensitivity', value);
    await prefs.setDouble('fallSensitivity', value);
    try {
      await FallDetector.setSensitivity(value);
    } catch (_) {}
    setState(() {
      _fallSensitivity = value;
    });
  }

  Future<void> _saveSOSTemplate(String template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_message_template', template);
    setState(() {
      _selectedTemplate = template;
    });
  }



  Future<void> _saveFakeCallMessage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fake_call_message', value);
    setState(() => _fakeCallMessage = value);
  }

  Future<void> _playFakeCallPreview() async {
    try {
      final flutterTts = FlutterTts();
      await flutterTts.setLanguage('en-IN');
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setPitch(1.2);
      await flutterTts.setVolume(1.0);
      await flutterTts.speak(_fakeCallMessage);
    } catch (e) {
      debugPrint('⚠️ Fake call preview failed: $e');
    }
  }

  Future<void> _saveFakeCallerName(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fake_caller_name', value);
    setState(() => _fakeCallerName = value);
  }

  Future<void> _saveFakeCallDelay(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fake_call_delay', value);
    setState(() => _fakeCallDelay = value);
  }

  Future<void> _saveAutoFakeCallEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_fake_call_enabled', value);
    setState(() => _autoFakeCallEnabled = value);
  }

  // Smart call settings - persist to SharedPreferences
  Future<void> _saveRetryCount(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('retry_count', value);
    setState(() => _retryCount = value);
  }

  Future<void> _saveTrackingInterval(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tracking_interval', value);
    setState(() => _trackingInterval = value);
  }

  Future<void> _saveAutoCallMessage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_call_message', value);
    setState(() => _autoCallMessage = value);
  }

  void _showTemplateSelector() {
    showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select SOS Message Template'),
        children: SosTemplates.templates
            .map(
              (template) => SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(ctx, template);
                  _saveSOSTemplate(template);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(template,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _saveAutoOpenOnFall(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoOpenOnFall', value);
    // Also update AppState if available
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.setAutoOpenOnFall(value);
    } catch (_) {}
    setState(() {
      _autoOpenOnFall = value;
    });
  }

  // ignore: unused_element
  Future<void> _saveAutoMode(bool value) async {
    // Auto mode is a premium feature; require unlock before enabling.
    if (value && !PurchaseService.isPremium) {
      final upgraded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PremiumUpgradeScreen()),
      );
      if (upgraded != true && !PurchaseService.isPremium) {
        // User did not unlock premium; keep toggle off
        setState(() => _autoModeEnabled = false);
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_mode_enabled', value);
    debugPrint('SettingsScreen: saved auto_mode_enabled = $value');
    // also update controller for consistency (no effect on mode selection)
    await SosController.setAutoMode(value);
    setState(() => _autoModeEnabled = value);
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
          child: Text(LanguageService().t('settings'),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, letterSpacing: 1)),
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
                      min: 5,
                      max: 15,
                      divisions: 2,
                      // ignore: deprecated_member_use
                      activeColor: Colors.teal,
                      label: '${_sosTimerDuration.toInt()}s',
                      onChanged: (value) {
                        setState(() => _sosTimerDuration = value);
                      },
                      onChangeEnd: _saveTimerDuration,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('Safe Walk Duration'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ]),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_walk,
                            color: Colors.black54),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Text('Default Safe Walk duration',
                                style: TextStyle(fontWeight: FontWeight.w600))),
                        DropdownButton<int>(
                          value: _safeWalkMinutes,
                          items: [1, 5, 15, 30, 60]
                              .map((m) => DropdownMenuItem(
                                  value: m, child: Text('$m min')))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            _saveSafeWalkMinutes(v);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Safe Walk set to $v minutes')));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.message),
                    title: const Text('SOS Message Template'),
                    subtitle: Text(_selectedTemplate.length > 50
                        ? '${_selectedTemplate.substring(0, 50)}...'
                        : _selectedTemplate),
                    onTap: _showTemplateSelector,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Auto Alert'),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Auto SOS'),
                    subtitle: const Text(
                        'Send alerts automatically without opening apps'),
                    value: _autoModeEnabled,
                    onChanged: _saveAutoMode,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Fake Call'),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Caller name',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _fakeCallerNameController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'e.g. Police, Mom, Doctor',
                            ),
                            onChanged: (v) => _saveFakeCallerName(v),
                          ),
                          const SizedBox(height: 12),
                          const Text('Fake call message',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _fakeCallController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Enter fake call message',
                            ),
                            onChanged: (v) => _saveFakeCallMessage(v),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _playFakeCallPreview,
                              child: const Text('Play message'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            title: const Text('Auto fake call after SOS'),
                            subtitle: const Text('Show fake call screen automatically after SOS'),
                            value: _autoFakeCallEnabled,
                            onChanged: (value) {
                              _saveAutoFakeCallEnabled(value);
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text('Call delay before appearance (seconds)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 8),
                          Slider(
                            value: _fakeCallDelay.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: '${_fakeCallDelay}s',
                            activeColor: Colors.teal,
                            onChanged: (value) {
                              setState(() => _fakeCallDelay = value.toInt());
                            },
                            onChangeEnd: (value) {
                              _saveFakeCallDelay(value.toInt());
                            },
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Delay: ${_fakeCallDelay}s before fake call appears',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Smart Call Settings'),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Retry count if call fails',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 8),
                          Slider(
                            value: _retryCount.toDouble(),
                            min: 0,
                            max: 5,
                            divisions: 5,
                            label: '$_retryCount',
                            activeColor: Colors.blue,
                            onChanged: (value) {
                              setState(() => _retryCount = value.toInt());
                            },
                            onChangeEnd: (value) {
                              _saveRetryCount(value.toInt());
                            },
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Retry $_retryCount time(s) per contact',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Tracking interval (seconds)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 8),
                          Slider(
                            value: _trackingInterval.toDouble(),
                            min: 5,
                            max: 60,
                            divisions: 11,
                            label: '${_trackingInterval}s',
                            activeColor: Colors.blue,
                            onChanged: (value) {
                              setState(() => _trackingInterval = value.toInt());
                            },
                            onChangeEnd: (value) {
                              _saveTrackingInterval(value.toInt());
                            },
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Update location every ${_trackingInterval}s',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Auto call message (when picked up)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _autoCallMessageController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Message to play during emergency call',
                            ),
                            onChanged: (v) => _saveAutoCallMessage(v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Emergency Trigger'),
                  const SizedBox(height: 10),
                  // Fall detection intensity slider (G threshold)
                  _buildSliderCard(
                    'Fall detection threshold: ${_fallThreshold.toStringAsFixed(1)} g',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Slider(
                          value: _fallThreshold,
                          min: 6.0,
                          max: 20.0,
                          divisions: 14,
                          activeColor: Colors.teal,
                          label: '${_fallThreshold.toStringAsFixed(1)} g',
                          onChanged: (value) {
                            setState(() => _fallThreshold = value);
                          },
                          onChangeEnd: (value) async {
                            await _saveFallThreshold(value);
                            try {
                              await FallDetector.setThreshold(value);
                            } catch (_) {}
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    'Fall threshold set to ${value.toStringAsFixed(1)} g')));
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.info_outline,
                                size: 18, color: Colors.black54),
                            tooltip: 'What is this?',
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Fall detection threshold'),
                                  content: const Text(
                                    'This threshold controls how strong an acceleration spike must be to count as a fall. '
                                    'Values are shown in g units and converted internally to m/s² for the phone accelerometer. Lower values make detection MORE sensitive and may yield false positives. '
                                    'Recommended ranges:\n• 6–9 g: very sensitive (for small/soft falls)\n• 10–14 g: normal (balanced sensitivity)\n• 15–20 g: less sensitive (reduces false positives).\nDefault: 12.0 g.',
                                    style: TextStyle(height: 1.3),
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Close')),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Manage Recipients'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_add,
                            color: Colors.black54, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Select contacts to notify',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text('Who should receive your SOS alerts?',
                                  style: TextStyle(
                                      color: Colors.black54, fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          key: const Key('manage_recipients_button'),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/recipients'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal),
                          child: const Text('Manage',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Escape Tools'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ListTile(
                      leading:
                          const Icon(Icons.phone_in_talk, color: Colors.teal),
                      title: const Text('Fake Call',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Simulate an incoming call to escape discreetly'),
                      trailing: const Icon(Icons.arrow_forward, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FakeCallScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Legal & Compliance'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ListTile(
                      leading:
                          const Icon(Icons.privacy_tip, color: Colors.teal),
                      title: const Text('Privacy Policy',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Read our data protection and usage policy'),
                      trailing: const Icon(Icons.arrow_forward, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen()),
                        );
                      },
                    ),
                  ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Logout',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Sign out of your account'),
                      trailing: const Icon(Icons.exit_to_app, size: 18),
                      onTap: () async {
                        await _logout();
                      },
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withAlpha(100)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Important Disclaimer',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Silent SOS is not a replacement for official emergency services. Always call 108 directly in life-threatening situations.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withAlpha(100)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Background Detection Limitation',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Automatic fall detection and voice activation work only while the app is open. Keep the app active during activities where you may need assistance.',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                            ],
                          ),
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
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          slider,
        ],
      ),
    );
  }

  Future<void> _showDevSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final serverCtrl = TextEditingController(
        text: prefs.getString('server_url') ?? ApiConfig.baseUrl);
    final modelCtrl = TextEditingController(
        text: prefs.getString('ai_model') ?? 'claude-haiku-4.5');
    final smtpCtrl = TextEditingController(
        text: prefs.getString('smtp_backend_url') ??
            '${ApiConfig.baseUrl}/send-email');

    // The dialog uses a local builder context; we intentionally await it
    // and then use the state context after ensuring the widget is still
    // mounted. Suppress the lint here as we've moved UI updates after the
    // dialog completes and check `mounted` before using `context`.
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Developer Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: serverCtrl,
                decoration: InputDecoration(
                    labelText: 'Server URL', hintText: ApiConfig.baseUrl),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: smtpCtrl,
                decoration: InputDecoration(
                    labelText: 'SMTP Backend URL',
                    hintText: '${ApiConfig.baseUrl}/send-email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                    labelText: 'AI Model', hintText: 'claude-haiku-4.5'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final server = serverCtrl.text.trim();
                final model = modelCtrl.text.trim();
                final smtp = smtpCtrl.text.trim();
                Navigator.pop(
                    ctx, {'server': server, 'model': model, 'smtp': smtp});
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
      final smtp = result['smtp'] ?? '';
      await prefs.setString('server_url', server);
      await prefs.setString('smtp_backend_url', smtp);
      await prefs.setString('ai_model', model);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
          const SnackBar(content: Text('Developer settings saved')));
    }

    serverCtrl.dispose();
    modelCtrl.dispose();
  }

  Future<void> _logout() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _isLoading = true);
      await AuthService.signOut();
      Provider.of<AppState>(context, listen: false).clearAuthentication();
      final prefs = await SharedPreferences.getInstance();
      // Remove common auth keys if present (keep user settings intact)
      await prefs.remove('auth_token');
      await prefs.remove('user_profile');
      messenger.showSnackBar(const SnackBar(content: Text('Signed out')));
    } catch (e) {
      debugPrint('Logout failed: $e');
      messenger.showSnackBar(const SnackBar(content: Text('Logout failed')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    }
  }

  // ignore: unused_element
  Future<void> _showVideoRetrievalDialog() async {
    final videoKeyCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retrieve SOS Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the video key (filename) to retrieve:',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            TextField(
              controller: videoKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'Video Key',
                hintText: 'videos/12345.mp4',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child:
                const Text('Retrieve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && videoKeyCtrl.text.isNotEmpty) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Video link feature not available'),
            duration: Duration(seconds: 2)),
      );
    }
    videoKeyCtrl.dispose();
  }
}
