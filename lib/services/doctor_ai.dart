// Simple on-device Doctor AI rules engine (red-flag checks)
// Returns a conservative triage result based on symptoms and vitals.

Map<String, dynamic> checkRedFlags(Map<String, dynamic> ctx) {
  // ctx may contain: symptoms (String), vitals: { spo2, pulse, respRate, bp }
  final String symptoms = (ctx['symptoms'] as String?)?.toLowerCase() ?? '';
  final Map<String, dynamic> vitals = (ctx['vitals'] as Map<String, dynamic>?) ?? {};

  bool critical = false;
  final List<String> reasons = [];
  final List<String> actions = [];

  // Keyword-based critical signs
  final criticalKeywords = ['unconscious', 'not breathing', 'no breathing', 'no pulse', 'cardiac arrest', 'severe bleeding', 'bleeding heavily', 'chest pain', 'difficulty breathing', 'choking', 'stroke', 'slurred speech', 'face droop', 'weakness on one side'];
  for (final k in criticalKeywords) {
    if (symptoms.contains(k)) {
      critical = true;
      reasons.add('Detected critical symptom: $k');
    }
  }

  // Vitals checks
  final double? spo2 = vitals['spo2'] is num ? (vitals['spo2'] as num).toDouble() : null;
  if (spo2 != null && spo2 < 90.0) {
    critical = true;
    reasons.add('Low oxygen saturation: ${spo2.toStringAsFixed(0)}%');
  }
  final num? pulseN = vitals['pulse'] as num?;
  if (pulseN != null) {
    final pulse = pulseN.toInt();
    if (pulse < 40 || pulse > 140) {
      reasons.add('Abnormal pulse: $pulse bpm');
      if (pulse < 40 || pulse > 130) critical = true;
    }
  }
  final num? rrN = vitals['respRate'] as num?;
  if (rrN != null && rrN > 30) {
    reasons.add('High respiratory rate: $rrN');
    critical = true;
  }

  if (critical) {
    actions.add('Call emergency services immediately.');
    actions.add('If unconscious and not breathing, start CPR if trained.');
    actions.add('Control severe bleeding with direct pressure.');
  } else {
    // Non-critical suggestions
    if (symptoms.isNotEmpty) {
      actions.add('Measure pulse, oxygen saturation (SpO2), and respiratory rate.');
      actions.add('If symptoms worsen (chest pain, severe difficulty breathing, fainting), call emergency services.');
    } else {
      actions.add('No red-flags detected from the provided input.');
      actions.add('Monitor symptoms and measure vitals where possible.');
    }
  }

  final severity = critical ? 'critical' : 'low';
  final brief = critical
      ? 'Possible critical condition detected — call emergency services immediately.'
      : 'No immediate red flags detected. Follow monitoring guidance.';

  return {
    'ok': true,
    'severity': severity,
    'reasons': reasons,
    'immediate_actions': actions,
    'brief_message_for_contacts': brief,
  };
}
