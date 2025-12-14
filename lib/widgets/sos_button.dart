// lib/widgets/sos_button.dart
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/sos_service.dart';
import '../services/voice_hotword_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SosButtonWidget extends StatefulWidget {
  const SosButtonWidget({super.key});

  @override
  State<SosButtonWidget> createState() => _SosButtonWidgetState();
}

class _SosButtonWidgetState extends State<SosButtonWidget> {
  final SosService _sos = SosService();
  VoiceHotwordService? _hotwordService;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _hotwordService = VoiceHotwordService(
      hotwords: ['help me', 'help me please', 'i need help'],
      onHotwordDetected: (recognizedText) async {
        Fluttertoast.showToast(msg: 'Hotword detected: $recognizedText');
        await _sendSos();
      },
    );
    _hotwordService!.init();
  }

  Future<void> _sendSos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'anonymous';
      final recipients = ['youremail@example.com'];
      final res = await _sos.triggerSos(
        senderUid: uid,
        recipients: recipients,
        captureVideo: false,
        audioDurationSeconds: 6,
      );
      Fluttertoast.showToast(msg: 'SOS sent (doc: ${res['docId']})');
    } catch (e, st) {
      Fluttertoast.showToast(msg: 'SOS failed: $e');
      debugPrint('SOS error: $e\n$st');
    }
  }

  void _toggleListening() {
    if (_listening) {
      _hotwordService?.stopListening();
    } else {
      _hotwordService?.startListening();
    }
    setState(() {
      _listening = !_listening;
    });
  }

  @override
  void dispose() {
    _hotwordService?.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          icon: Icon(Icons.sentiment_very_dissatisfied),
          label: Text('Send SOS Now'),
          onPressed: _sendSos,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: Icon(_listening ? Icons.mic : Icons.mic_none),
          label: Text(_listening ? 'Stop Hotword Listener' : 'Start Hotword Listener'),
          onPressed: _toggleListening,
        ),
      ],
    );
  }
}
