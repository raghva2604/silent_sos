import 'package:shared_preferences/shared_preferences.dart';

/// On-device deterministic triage helper (MVP)
/// Provides conservative, explainable rules to determine if an urgent escalation
/// is likely. Keep this lightweight and deterministic so it can run offline.
class AIContext {
  /// Return whether the user has opted into server-side triage.
  static Future<bool> isTriageEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('triage_opt_in') ?? false;
    } catch (_) {
      return false;
    }
  }
  /// Analyze a simple context map and return a low/medium/high urgency label.
  /// Expected context shape (example): { 'symptoms': ['unconscious','bleeding'], 'vitals': {'pulse': 40} }
  static String triage(Map<String, dynamic> ctx) {
    try {
      final symptoms = (ctx['symptoms'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? <String>[];
      final vitals = (ctx['vitals'] as Map?) ?? <String, dynamic>{};
      // High urgency keywords
      final high = ['unconscious', 'not breathing', 'severe bleeding', 'no pulse'];
      for (final s in symptoms) {
        for (final h in high) {
          if (s.contains(h)) return 'high';
        }
      }
      // Low pulse/bradycardia
      final pulse = vitals['pulse'] is num ? (vitals['pulse'] as num).toInt() : null;
      if (pulse != null && pulse < 40) return 'high';
      // Medium urgency: shortness of breath, chest pain
      final med = ['chest pain', 'difficulty breathing', 'severe pain'];
      for (final s in symptoms) {
        for (final m in med) {
          if (s.contains(m)) return 'medium';
        }
      }
      // Default: low
      return 'low';
    } catch (_) {
      return 'low';
    }
  }
}
