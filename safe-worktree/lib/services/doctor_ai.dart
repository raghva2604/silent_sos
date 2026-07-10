// Simple on-device Doctor AI rules engine (red-flag checks)
// Returns a conservative triage result based on symptoms and vitals.

Map<String, dynamic> checkRedFlags(Map<String, dynamic> ctx) {
  // ctx may contain: symptoms (String), vitals: { spo2, pulse, respRate, bp }
  final String symptoms = (ctx['symptoms'] as String?)?.toLowerCase() ?? '';

  // Safely extract vitals map, converting dynamic types to proper types
  Map<String, dynamic> vitals = {};
  if (ctx['vitals'] is Map) {
    final vitalData = ctx['vitals'] as Map;
    vitals = vitalData.cast<String, dynamic>();
  }

  bool critical = false;
  final List<String> reasons = [];
  final List<String> actions = [];

  // Keyword-based critical signs - expanded for women safety and all safety contexts
  final criticalKeywords = [
    'unconscious',
    'not breathing',
    'no breathing',
    'no pulse',
    'cardiac arrest',
    'severe bleeding',
    'bleeding heavily',
    'chest pain',
    'difficulty breathing',
    'choking',
    'stroke',
    'slurred speech',
    'face droop',
    'weakness on one side',
    'followed',
    'following',
    'follow',
    'stalk',
    'threat',
    'threatened',
    'attacked',
    'being chased',
    'danger',
    'assault',
    'rape',
    'harassed',
    'unsafe',
    'kidnap',
    'abduct',
    'fight',
    'violence',
    'gun',
    'knife',
    'weapon'
  ];
  for (final k in criticalKeywords) {
    if (symptoms.contains(k)) {
      critical = true;
      reasons.add('Detected critical symptom: $k');
    }
  }

  // Vitals checks
  final double? spo2 =
      vitals['spo2'] is num ? (vitals['spo2'] as num).toDouble() : null;
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
    actions.add('Move to a safe location if being threatened.');
  } else {
    // more informative AI style output for non-critical cases
    if (symptoms.isNotEmpty) {
      actions.add(
          'If you feel followed or threatened, move to a safe public area and contact a trusted person.');
      actions.add('Use your phone to share location with an emergency contact now.');
      actions.add('Keep calm and avoid dangerous zones until help arrives.');

      if (symptoms.contains('fall') || symptoms.contains('hurt') ||
          symptoms.contains('injury')) {
        actions.insert(0, 'Take deep breaths and stay still to prevent further injury.');
        actions.insert(1, 'If able, call emergency services and provide your location.');
      }

      actions.add('Measure pulse, oxygen saturation (SpO2), and respiratory rate.');
      actions.add(
          'If symptoms worsen (chest pain, severe difficulty breathing, fainting), call emergency services.');
    } else {
      actions.add('No red-flags detected from the provided input.');
      actions.add('Monitor symptoms and measure vitals where possible.');
      actions.add('If unsure, open the SOS screen and prepare to send alerts.');
    }

    // Encourage SOS if text length indicates concern but no critical keywords.
    if (!critical && symptoms.length > 60 && reasons.isEmpty) {
      reasons.add('Long description indicates potential serious concern.');
      actions.insert(0, 'Consider sending an SOS alert to trusted contacts.');
    }
  }

  // If no explicit reason was set, add a safe default reason
  if (reasons.isEmpty) {
    reasons
        .add('No major red flags detected yet. Continue to monitor closely.');
  }

  final severity = critical ? 'critical' : 'low';
  final brief = critical
      ? 'Possible critical condition detected — call emergency services immediately and move to a safe place if possible.'
      : 'No immediate red flags detected. Stay alert, and seek help if symptoms worsen.';

  // Add non-emergency safety actions for non-critical yet concerning situations
  if (!critical) {
    if (symptoms.contains('followed') ||
        symptoms.contains('danger') ||
        symptoms.contains('assault')) {
      actions.insert(0,
          'Move to a crowded public area and call someone trusted right now.');
      actions.insert(1, 'Share your location with a trusted contact.');
    }
    if (symptoms.contains('fall') ||
        symptoms.contains('hurt') ||
        symptoms.contains('injury')) {
      actions.insert(0, 'Avoid moving too much; keep warm and call for help.');
      actions.insert(1, 'Check for bleeding and stabilize injured parts.');
    }
  }

  return {
    'ok': true,
    'severity': severity,
    'reasons': reasons,
    'immediate_actions': actions,
    'brief_message_for_contacts': brief,
  };
}
