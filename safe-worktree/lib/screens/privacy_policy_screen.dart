import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal),
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Data Collection',
              'Silent SOS collects the following data to provide emergency services:\n\n'
                  '• Location data (GPS coordinates) for emergency response\n'
                  '• Contact information for emergency recipients\n'
                  '• Motion sensor data for fall detection\n'
                  '• Voice recordings for emergency keyword detection\n'
                  '• Video recordings (optional) during emergencies\n'
                  '• Device information for troubleshooting',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Data Usage',
              'Your data is used exclusively for:\n\n'
                  '• Sending emergency alerts with your location\n'
                  '• Detecting falls and triggering automatic SOS\n'
                  '• Processing voice commands for emergency detection\n'
                  '• Improving emergency response accuracy\n'
                  '• App functionality and debugging\n\n'
                  'We do NOT sell, share, or monetize your personal data.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Data Storage',
              'Your data is stored securely on our servers with encryption. '
                  'You can request data deletion at any time by contacting our support team.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Emergency Contacts',
              'Your selected emergency contacts are only used to send SOS alerts. '
                  'They do not receive marketing communications or any data other than emergency alerts.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Background Limitation Disclosure',
              'NOTE: Automatic fall detection and voice activation work ONLY while the app is actively running. '
                  'When the app is closed or minimized, these features are unavailable. '
                  'Ensure the app remains open during activities where you may need emergency assistance.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Third-Party Services',
              'We use the following services:\n\n'
                  '• Google Firebase for data synchronization\n'
                  '• Vosk for offline voice recognition\n'
                  '• Mapping services for location\n'
                  '• SMS/Email providers for alerts\n\n'
                  'These services have their own privacy policies.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Children\'s Privacy',
              'Silent SOS is not intended for users under 13 years old. '
                  'We do not knowingly collect data from children.',
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Changes to This Policy',
              'We may update this privacy policy periodically. '
                  'We will notify you of significant changes through the app.',
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Text(
                    'Last updated: March 2026',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _launchUrl('https://silentsos.example.com/privacy'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal),
                        child: const Text(
                          'Full Privacy Policy Online',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.withAlpha(100)),
          ),
          child: Text(
            content,
            style: const TextStyle(
                height: 1.6, fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
