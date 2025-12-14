import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/vibration_service.dart';
import '../services/language_service.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
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
                        color: isSelected
                            ? Colors.blue
                            : Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.blue
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : Colors.white70,
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
                activeColor: Colors.blue,
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
