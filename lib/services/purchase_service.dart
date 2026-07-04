import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static bool isPremiumUser = false;

  static bool get isPremium =>
      isPremiumUser; // Optional getter for cleaner access

  static Future<void> loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    isPremiumUser = prefs.getBool('premium') ?? false;
  }

  static Future<void> unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('premium', true);
    isPremiumUser = true;
  }
}
