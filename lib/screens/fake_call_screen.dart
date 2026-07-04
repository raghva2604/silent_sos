import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/analytics_service.dart';

/// Fake Call Screen — Gives user escape option by simulating incoming call
/// Auto-dismisses after 15 seconds or when user taps "End Call"
class FakeCallScreen extends StatefulWidget {
  final String callerName;
  final String callerNumber;

  const FakeCallScreen({
    super.key,
    this.callerName = 'police',
    this.callerNumber = '100',
  });

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _secondsRemaining = 15;

  // fake call message and caller
  String fakeMessage =
      "Hello, we are calling from the control room. Are you okay? Please respond.";
  String callerDisplayName = 'Police';

  // tts for police mode
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();

    AnalyticsService.logEvent('fake_call_screen_viewed');

    // Pulse animation for incoming call effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // initialize tts for police voice
    _tts.setLanguage('en-IN');
    _tts.setSpeechRate(0.4); // slower
    _tts.setPitch(1.3); // higher pitch for police tone
    _tts.setVolume(1.0);
    // ensure speak() waits until speech is finished
    _tts.awaitSpeakCompletion(true);

    // Load custom fake call message and caller name from settings.
    _loadFakeCallSettings();

    // Auto-dismiss after 15 seconds in case user ignores
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });

    // Update countdown every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _secondsRemaining--;
        });
      }
      return _secondsRemaining > 0;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing caller icon
              ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.0).animate(
                  CurvedAnimation(
                      parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade700,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.call,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Caller name
              Text(
                callerDisplayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),

              // Caller number
              Text(
                widget.callerNumber,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Auto-dismiss countdown
              Text(
                'Auto-closing in $_secondsRemaining seconds',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 60),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline button (red)
                  GestureDetector(
                    onTap: () async {
                      AnalyticsService.logEvent('fake_call_dismissed');
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade700,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Accept button (green)
                  GestureDetector(
                    onTap: () async {
                      debugPrint('📞 FakeCall: answer tapped');
                      await AnalyticsService.logEvent('fake_call_answered');
                      await _speakPoliceMessage();
                      // leave screen visible a couple seconds after voice ends
                      await Future.delayed(const Duration(seconds: 3));
                      if (mounted) Navigator.pop(context);
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.shade700,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // End call button (bottom)
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'END CALL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadFakeCallSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedMessage = prefs.getString('fake_call_message');
    final loadedCallerName = prefs.getString('fake_caller_name');
    if (loadedMessage != null && loadedMessage.isNotEmpty) {
      setState(() {
        fakeMessage = loadedMessage;
      });
    }
    if (loadedCallerName != null && loadedCallerName.isNotEmpty) {
      setState(() {
        callerDisplayName = loadedCallerName;
      });
    }
  }

  Future<void> _speakPoliceMessage() async {
    debugPrint('📢 FakeCall: speaking police message');
    try {
      await _tts.setPitch(1.2);
      await _tts.setSpeechRate(0.45);
      // make sure we wait for speech to complete
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(fakeMessage);
      debugPrint('✅ FakeCall: police message spoken');
    } catch (e) {
      debugPrint('⚠️ FakeCall: police TTS failed: $e');
    }
  }
}
