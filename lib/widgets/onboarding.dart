import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silent_sos/src/widgets/neon_widgets.dart';
import 'package:lottie/lottie.dart';

class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({super.key});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  final PageController _pc = PageController();
  int _idx = 0;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Welcome to SilentSOS',
      'body':
          'Quick setup to keep you safe: add emergency contacts, allow location & SMS permissions.'
    },
    {
      'title': 'Automatic Fall Detection',
      'body':
          'The app monitors for hard impacts. If a fall is detected, you will get a countdown to cancel before alerts are sent.'
    },
    {
      'title': 'Live Location Sharing',
      'body':
          'When SOS is triggered you can share a short link so your contacts can follow your live location.'
    },
    {
      'title': 'Media Recording',
      'body':
          'If enabled, the app records short front/back clips during an SOS to help responders.'
    },
    {
      'title': 'Privacy & Control',
      'body':
          'You can always change preferences in Settings. This tutorial shows only once.'
    },
  ];

  Future<void> _complete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_v1_shown', true);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
            child: Card(
              color: const Color(0xFF071029),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pc,
                      onPageChanged: (i) => setState(() => _idx = i),
                      itemCount: _pages.length,
                      itemBuilder: (ctx, i) {
                        final p = _pages[i];
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Lottie animation per page for a modern feel (network URL used to avoid bundling large assets)
                              if (i == 0)
                                Center(
                                    child: SizedBox(
                                        height: 140,
                                        child: Lottie.network(
                                            'https://assets10.lottiefiles.com/packages/lf20_touohxv0.json',
                                            fit: BoxFit.contain))),
                              if (i == 2)
                                Center(
                                    child: SizedBox(
                                        height: 140,
                                        child: Lottie.network(
                                            'https://assets2.lottiefiles.com/packages/lf20_j1adxtyb.json',
                                            fit: BoxFit.contain))),
                              Text(p['title']!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800)),
                              const SizedBox(height: 12),
                              Text(p['body']!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: Colors.white70)),
                              const Spacer(),
                              if (i == 1)
                                Center(
                                    child: Icon(Icons.warning_amber_rounded,
                                        size: 84,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary))
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        NeonButton(
                          onTap: () {
                            _pc.jumpToPage(0);
                          },
                          child: const Text('Back'),
                        ),
                        const Spacer(),
                        Row(
                            children: List.generate(
                                _pages.length,
                                (i) => Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    width: _idx == i ? 14 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: _idx == i
                                            ? Colors.white
                                            : Colors.white24,
                                        borderRadius:
                                            BorderRadius.circular(8))))),
                        const Spacer(),
                        NeonButton(
                          onTap: _idx == _pages.length - 1
                              ? _complete
                              : () {
                                  _pc.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.ease);
                                },
                          child:
                              Text(_idx == _pages.length - 1 ? 'Done' : 'Next'),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
