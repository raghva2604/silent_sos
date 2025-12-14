import 'package:flutter/material.dart';
import '../services/doctor_ai.dart';

class AIAssistantScreenSimple extends StatefulWidget {
  const AIAssistantScreenSimple({super.key});

  @override
  State<AIAssistantScreenSimple> createState() => _AIAssistantScreenSimpleState();
}

class _AIAssistantScreenSimpleState extends State<AIAssistantScreenSimple> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'type': 'bot',
      'text': 'Hi! I\'m your silent sos AI assistant. I can help you with safety tips, emergency guidance, and health advice. Ask me anything!',
    }
  ];
  bool _isLoading = false;

  void _sendMessage() {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    setState(() {
      _messages.add({'type': 'user', 'text': userMessage});
      _isLoading = true;
    });
    _controller.clear();

    // Use trained AI rules to analyze user message (DoctorAI)
    Future.delayed(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      try {
        // Run conservative red-flag checks first
        try {
          final triage = checkRedFlags({'symptoms': userMessage});
          if (triage['severity'] == 'critical') {
            final reasons = (triage['reasons'] as List<dynamic>).cast<String>();
            final actions = (triage['immediate_actions'] as List<dynamic>).cast<String>();
            final text = '⚠️ CRITICAL: Immediate attention required.\n' + reasons.join('\n') + '\n\nActions:\n' + actions.join('\n');
            if (mounted) {
              setState(() {
                _messages.add({'type': 'bot', 'text': text});
                _isLoading = false;
              });
            }
            return;
          }
        } catch (_) {}
        final lower = userMessage.toLowerCase();
        String response = '';
        
        // Check for specific emergency keywords first
        if (lower.contains('fall') || lower.contains('fell') || lower.contains('trip') || lower.contains('collapse')) {
          response = '🚨 FALL DETECTED\n\nImmediate actions:\n• Check for injuries, fractures, bleeding\n• Check head and neck carefully\n• If severe pain, unconscious, or heavy bleeding → Call 911\n• If minor: rest and monitor for delayed symptoms\n• Avoid moving if spinal injury suspected';
        }
        else if (lower.contains('chest pain') || lower.contains('chest pressure') || (lower.contains('chest') && lower.contains('pain'))) {
          response = '🚨 CHEST PAIN - MEDICAL EMERGENCY\n\nCALL 911 IMMEDIATELY\n\nWhile waiting:\n• Sit or lie down\n• Loosen tight clothing\n• Chew aspirin if available\n• Stay calm and monitor breathing\n• Have phone ready for responders';
        }
        else if ((lower.contains('difficulty') || lower.contains('trouble')) && (lower.contains('breath') || lower.contains('breathing'))) {
          response = '🚨 DIFFICULTY BREATHING - EMERGENCY\n\nCALL 911 NOW\n\nImmediate steps:\n• Sit upright\n• Try to stay calm\n• Loosen tight clothing\n• If allergic reaction: use EpiPen if available\n• Do NOT lie flat';
        }
        else if (lower.contains('unconscious') || lower.contains('unresponsive') || lower.contains('fainted')) {
          response = '🚨 UNCONSCIOUSNESS - EMERGENCY\n\nCALL 911 IMMEDIATELY\n\nActions:\n• Check airway is clear\n• Place in recovery position (on side)\n• Check pulse and breathing\n• Start CPR if trained and no pulse\n• Do not leave person alone';
        }
        else if (lower.contains('bleeding') || lower.contains('bleed') || lower.contains('severe bleeding')) {
          response = '🚨 SEVERE BLEEDING\n\nActions:\n• Apply FIRM direct pressure with clean cloth\n• Elevate injury above heart if possible\n• Keep pressure for 10-15 minutes\n• If heavy bleeding continues → CALL 911\n• Apply tourniquet if limb bleeding won\'t stop';
        }
        else if (lower.contains('poison') || lower.contains('overdose') || lower.contains('toxic') || lower.contains('swallowed')) {
          response = '🚨 POISONING/OVERDOSE - EMERGENCY\n\nCALL POISON CONTROL: 1-800-222-1222\nOr CALL 911\n\n• Do NOT induce vomiting\n• Keep substance container nearby\n• Stay alert and conscious\n• Provide responders with substance info';
        }
        else if (lower.contains('choking')) {
          response = '🚨 CHOKING - EMERGENCY\n\nImmediate actions:\n• Encourage coughing if able\n• If unable to cough/speak:\n  - Heimlich: Stand behind, place fist above navel\n  - Quick upward thrusts\n• If unsuccessful after 30 seconds → CALL 911\n• Keep trying until object removed or help arrives';
        }
        else if (lower.contains('seizure') || lower.contains('convulsion') || lower.contains('shaking')) {
          response = '🚨 SEIZURE\n\nDuring seizure:\n• Protect from injury (move objects away)\n• Turn on side if possible\n• Do NOT restrain person\n• DO NOT put anything in mouth\n• Time the seizure\n• If first seizure or lasts >5 min → CALL 911 after it stops';
        }
        else if (lower.contains('accident') || lower.contains('injury') || lower.contains('injured')) {
          response = 'I understand you\'ve had an accident.\n\nTell me more details:\n• Where are you injured?\n• Are you bleeding?\n• Can you move all limbs?\n• Any difficulty breathing or consciousness issues?\n\nIf SEVERE: Tap the SOS button or call 911';
        }
        else if (lower.contains('fever') || lower.contains('temperature')) {
          response = 'You mentioned fever.\n\nKey information needed:\n• What\'s your temperature? (Normal: <98.6°F)\n• Other symptoms? (cough, sore throat, body aches)\n• Any difficulty breathing?\n\nGuidance:\n• If >103°F, confusion, or severe headache → See doctor\n• Rest, hydrate, take fever-reducing medicine\n• Monitor for worsening symptoms';
        }
        else if (lower.contains('help') || lower.contains('emergency') || lower.contains('sos')) {
          response = 'You can trigger SOS from the home screen:\n\n1. Press the large RED SOS button\n2. Count down will start (default 5 seconds)\n3. Confirm you need help in the dialog\n4. Your location + message sent to all saved emergency contacts\n5. Auto-send in 10 seconds if you don\'t respond\n\nCan also enable auto-fall detection in Settings.';
        }
        else if (lower.contains('contact') || lower.contains('recipient') || lower.contains('email')) {
          response = 'Managing Emergency Contacts:\n\n1. Home > Email or Contacts\n2. View device contacts or add emails\n3. Select up to 5 recipients\n4. Save your selection\n\nYou can also go to Settings > Manage SOS Recipients to change them anytime.';
        }
        else if (lower.contains('hi') || lower.contains('hello') || lower.contains('hey')) {
          response = 'Hello! I\'m your Silent SOS AI Assistant.\n\nI can help with:\n• Emergency guidance (falls, chest pain, bleeding, etc.)\n• First aid advice\n• Symptom assessment\n• Safety tips\n• App features explanation\n\nJust describe what\'s happening or ask a question!';
        }
        else {
          // Default helpful response
          response = 'I understand. Can you provide more details?\n\nTell me:\n• Your symptoms or situation\n• Any injuries or pain\n• Difficulty breathing/consciousness\n• Current location\n\nOr tap SOS if in immediate danger.';
        }
        
        if (mounted) {
          setState(() {
            _messages.add({'type': 'bot', 'text': response});
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _messages.add({'type': 'bot', 'text': 'I\'m having trouble responding. Try again or use the SOS button for immediate help.'});
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('AI Assistant', style: TextStyle(letterSpacing: 1, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _messages.clear();
              _messages.add({'type': 'bot', 'text': 'Hi! I\'m your silent sos AI assistant. How can I help?'});
            }),
            icon: const Icon(Icons.delete_outline, color: Colors.teal),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i < _messages.length) {
                  final msg = _messages[i];
                  final isBot = msg['type'] == 'bot';
                  return Align(
                    alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isBot ? Colors.white : Colors.teal,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,2))],
                      ),
                      child: Text(
                        msg['text']!,
                        style: TextStyle(color: isBot ? Colors.black87 : Colors.white, fontSize: 14),
                      ),
                    ),
                  );
                } else {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: const SizedBox(
                          width: 40,
                          height: 20,
                          child: LinearProgressIndicator(color: Colors.teal),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask for safety tips...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.teal,
                  onPressed: _isLoading ? null : _sendMessage,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
