import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/vibration_service.dart';
import '../services/language_service.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  int _recordingDuration = 20;
  String _uploadSpeed = 'medium';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final vibService = VibrationService();
    await vibService.init();
    final langService = LanguageService();
    await langService.init();

    // Load video settings
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordingDuration = prefs.getInt('record_duration_seconds') ?? 20;
      _uploadSpeed = prefs.getString('upload_speed') ?? 'medium';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.grey[900],
      ),
      backgroundColor: Colors.grey[900],
      body: ListView(
        children: [
          // Language Settings
          _buildSectionHeader('Language'),
          _buildLanguageSelector(),
          const Divider(height: 2),

          // Vibration Settings
          _buildSectionHeader('Vibration'),
          _buildVibrationIntensity(),
          _buildVibrationToggle(),
          _buildVibrationPreview(),
          const Divider(height: 2),

          // Video Recording Settings
          _buildSectionHeader('Video Recording'),
          _buildVideoRecordingDuration(),
          _buildUploadSpeedSelector(),
          const Divider(height: 2),

          // App Info
          _buildSectionHeader('About'),
          _buildAboutTile(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[850],
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Consumer<LanguageService>(
      builder: (context, langService, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Language',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: langService.availableLanguages.entries.map((e) {
                  final isSelected = e.key == langService.currentLanguage;
                  return GestureDetector(
                    onTap: () async {
                      await langService.setLanguage(e.key);
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVibrationIntensity() {
    return Consumer<VibrationService>(
      builder: (context, vibService, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vibration Intensity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '${vibService.intensity}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                value: vibService.intensity.toDouble(),
                min: 0,
                max: 100,
                divisions: 10,
                thumbColor: Colors.blue,
                inactiveColor: Colors.grey[700],
                onChanged: (value) async {
                  await vibService.setIntensity(value.toInt());
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Weak',
                      style: TextStyle(fontSize: 10, color: Colors.white60),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Strong',
                      style: TextStyle(fontSize: 10, color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVibrationToggle() {
    return Consumer<VibrationService>(
      builder: (context, vibService, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Enable Vibration',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Switch(
                value: vibService.enabled,
                activeThumbColor: Colors.blue,
                onChanged: (value) async {
                  await vibService.setEnabled(value);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVibrationPreview() {
    final vibService = VibrationService();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ElevatedButton.icon(
        onPressed: () async {
          await vibService.previewVibration();
        },
        icon: const Icon(Icons.vibration),
        label: const Text('Preview Vibration'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[900],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildVideoRecordingDuration() {
    return Consumer<VibrationService>(
      builder: (context, _, __) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recording Duration (per camera)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    '${_recordingDuration}s',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                value: _recordingDuration.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                thumbColor: Colors.blue,
                inactiveColor: Colors.grey[700],
                onChanged: (value) async {
                  setState(() => _recordingDuration = value.toInt());
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('record_duration_seconds', value.toInt());
                },
              ),
              const SizedBox(height: 8),
              Text(
                '🎥 Each front and back camera will record for ${_recordingDuration}s',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadSpeedSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Speed',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['slow', 'medium', 'fast'].map((speed) {
              final isSelected = _uploadSpeed == speed;
              final label = speed == 'slow'
                  ? '🐌 Slow'
                  : speed == 'medium'
                      ? '⚡ Medium'
                      : '🚀 Fast';
              return GestureDetector(
                onTap: () async {
                  setState(() => _uploadSpeed = speed);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('upload_speed', speed);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _uploadSpeed == 'slow'
                ? '📊 Slow: Better quality, longer uploads (≤1 MB/s)'
                : _uploadSpeed == 'fast'
                    ? '📊 Fast: Lower quality, quick uploads (>5 MB/s)'
                    : '📊 Medium: Balanced quality and upload speed (1-5 MB/s)',
            style: TextStyle(fontSize: 11, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutTile() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Silent SOS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Emergency alert system with fall detection, AI health assistant, and automatic contact notification.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white60,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Version: 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}
