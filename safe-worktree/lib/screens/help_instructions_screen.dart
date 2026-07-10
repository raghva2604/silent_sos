import 'package:flutter/material.dart';

class HelpInstructionsScreen extends StatelessWidget {
  const HelpInstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📖 Help & Instructions'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            context,
            '🆘 How to Trigger SOS',
            [
              '1. Manual: Tap the red SOS button on home screen',
              '2. Voice: Say your voice command (e.g., "Help me")',
              '3. Fall: Detect sudden fall automatically',
              '4. Game Mode: All triggers work while playing games',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '⏱️ SOS Countdown Process',
            [
              '• 10-second countdown appears on screen',
              '• Video records automatically (location captured)',
              '• You can tap "SEND NOW" to emergency contacts',
              '• Or dismiss to cancel (if it was accidental)',
              '• Premium: Auto-sends after countdown to backend',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '🎮 Playing Games Safely',
            [
              '• Games run normally with SOS active in background',
              '• SOS doesn\'t interrupt gameplay',
              '• Countdown will appear over the game if triggered',
              '• Your emergency contacts are always saved',
              '• Can play Puzzle, Snake, Memory, or 2048',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '🎨 Customizing Your Theme',
            [
              '1. Open Settings > Personalize > Theme Store',
              '2. Choose: Default, Dark, Neon, or Minimal',
              '3. Theme applies instantly to entire app',
              '• Doesn\'t affect SOS functionality',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '👥 Managing Contacts',
            [
              '1. Go to Settings > Recipients',
              '2. Add phone numbers and email addresses',
              '3. Select which contacts to alert for SOS',
              '• SMS goes to phone numbers',
              '• Email goes to email addresses',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '💎 Premium vs Free',
            [
              'Premium Features:',
              '  • Auto-send SOS to backend (no confirmation needed)',
              '  • Faster emergency response',
              '  • Video sent with location data',
              '',
              'Free Features:',
              '  • Everything above +',
              '  • Manual SMS/Email sending',
              '  • Full game mode access',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            '⚙️ Advanced Settings',
            [
              '• SOS Countdown Duration: 5-30 seconds',
              '• Auto Fall Detection: Enable/Disable',
              '• Voice Command Sensitivity: Adjust recognition',
              '• Over-Shoulder View: Toggle video preview',
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💚 Safety Tips',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Always keep your phone charged',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• Check emergency contacts regularly',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• Test SOS with trusted contacts first',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• Update location permissions in system settings',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 14, height: 1.6),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
