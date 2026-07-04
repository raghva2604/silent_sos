import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  int currentIndex = 0;

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("onboarding_done", true);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }

  Widget buildPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            duration: Duration(milliseconds: 600),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Icon(icon, size: 100, color: Colors.teal),
              );
            },
          ),
          SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Silent SOS"),
        actions: [
          TextButton(
            onPressed: completeOnboarding,
            child: Text("Skip All", style: TextStyle(color: Colors.teal)),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => currentIndex = index);
              },
              children: [
                buildPage(
                  icon: Icons.security,
                  title: "Welcome to Silent SOS",
                  description:
                      "Your AI-powered personal safety assistant.\n\nOne-tap SOS\nVoice-triggered emergency alerts\nAutomatic fall detection\nReal-time location sharing",
                ),
                buildPage(
                  icon: Icons.emergency,
                  title: "How Emergency Alert Works",
                  description: "1️⃣ Press SOS or say 'Hey Silent'\n"
                      "2️⃣ Say 'I need help'\n"
                      "3️⃣ Confirm with 'Yes'\n\n"
                      "App sends SMS, Email, Location & Optional Video.",
                ),
                buildPage(
                  icon: Icons.mic,
                  title: "AI Voice Assistant",
                  description: "Wake word: 'Hey Silent'\n\n"
                      "Trigger phrases:\n"
                      "- I need help\n"
                      "- Send SOS\n"
                      "- Emergency\n\n"
                      "Say 'Yes' to confirm alert.",
                ),
                buildPage(
                  icon: Icons.directions_run,
                  title: "Smart Fall Detection",
                  description: "Detects heavy impact + sudden motion stop.\n\n"
                      "Asks for confirmation.\n"
                      "Auto-sends SOS if no response.\n\n"
                      "Adjustable sensitivity.",
                ),
                buildPage(
                  icon: Icons.videocam,
                  title: "Emergency Evidence Capture",
                  description: "Records video + audio during SOS.\n\n"
                      "Secure local storage.\n"
                      "Instant sharing via SMS.\n\n"
                      "Camera permission optional.",
                ),
                buildPage(
                  icon: Icons.verified_user,
                  title: "You Are in Control",
                  description: "Choose contacts\n"
                      "Enable/disable voice\n"
                      "Enable/disable fall detection\n"
                      "Cancel SOS anytime\n\n"
                      "Your safety. Your control.",
                ),
              ],
            ),
          ),
          SmoothPageIndicator(
            controller: _controller,
            count: 6,
            effect: ExpandingDotsEffect(
              activeDotColor: Colors.teal,
              dotHeight: 8,
              dotWidth: 8,
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: currentIndex == 5
                  ? completeOnboarding
                  : () {
                      _controller.nextPage(
                          duration: Duration(milliseconds: 400),
                          curve: Curves.easeInOut);
                    },
              child: Text(
                currentIndex == 5 ? "Get Started" : "Next",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }
}
