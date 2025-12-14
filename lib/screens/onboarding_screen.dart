import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.sos,
      title: 'Welcome to silent sos',
      description: 'Your personal emergency alert app. One tap to notify your trusted contacts when you need help.',
    ),
    OnboardingPage(
      icon: Icons.contacts,
      title: 'Add Emergency Contacts',
      description: 'Select up to 5 trusted contacts (family, friends, emergency services). They\'ll receive instant alerts with your location and can check on you.',
    ),
    OnboardingPage(
      icon: Icons.location_on,
      title: 'Real-time Location',
      description: 'Your location is shared with contacts when you send an SOS. You stay in control and can cancel anytime.',
    ),
    OnboardingPage(
      icon: Icons.videocam,
      title: 'Video & Audio Recording',
      description: 'Optional: Record front & back camera + audio when sending SOS. Evidence is automatically attached. Camera access is optional and requires your permission.',
    ),
    OnboardingPage(
      icon: Icons.smart_toy,
      title: 'AI Assistant',
      description: 'Get instant safety advice. Ask the AI for help with any emergency situation. Works both online and offline.',
    ),
    OnboardingPage(
      icon: Icons.psychology,
      title: 'Fall Detection',
      description: 'Automatic detection when you fall. The app will ask for confirmation before sending alerts to your contacts.',
    ),
    OnboardingPage(
      icon: Icons.camera_alt,
      title: 'Camera Permission (Optional)',
      description: 'Optional for video recording in emergencies.\n\n⚠️ WARNING: Camera permission allows the app to access your device\'s camera in the background when recording emergency evidence. You can skip this and enable it later in settings.',
      isCamera: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _acceptPermissionsAndContinue() async {
    // If on camera page (last page), offer skip option
    if (_currentPage == _pages.length - 1) {
      final shouldRequestCamera = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Camera?'),
          content: const Text('Camera permission allows recording emergency evidence in the background.\n\nYou can enable this later in settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Skip for Now'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ) ?? false;

      if (shouldRequestCamera) {
        await Permission.camera.request();
      }

      // Mark onboarding as complete and navigate
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pushReplacementNamed('/permissions');
      }
      return;
    }

    // For earlier pages, just go to next page
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _requestRequiredPermissions() async {
    // Request required permissions (not camera, which is optional)
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.contacts,
      Permission.notification,
    ].request();

    if (statuses[Permission.location]!.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required for SOS alerts')),
        );
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('silent sos', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          if (_currentPage < _pages.length - 1)
            TextButton(
              onPressed: () async {
                await _requestRequiredPermissions();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_completed', true);
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pushReplacementNamed('/permissions');
                }
              },
              child: const Text('Skip All', style: TextStyle(color: Colors.teal)),
            )
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _currentPage = page),
        children: _pages.map((page) => _buildPage(page)).toList(),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.grey[100],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentPage ? Colors.teal : Colors.grey[300],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    onPressed: _currentPage == _pages.length - 1
                        ? _acceptPermissionsAndContinue
                        : () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                    child: Text(_currentPage == _pages.length - 1 ? 'Get Started' : 'Next', style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(page.icon, size: 80, color: Colors.teal),
          const SizedBox(height: 32),
          Text(
            page.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final bool isCamera;

  OnboardingPage({required this.icon, required this.title, required this.description, this.isCamera = false});
}
