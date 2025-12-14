import 'package:flutter/material.dart';

class PushToTalkScreen extends StatefulWidget {
  const PushToTalkScreen({super.key});

  @override
  State<PushToTalkScreen> createState() => _PushToTalkScreenState();
}

class _PushToTalkScreenState extends State<PushToTalkScreen> {
  bool _recording = false;
  String _transcript = '';

  void _toggle() {
    setState(() {
      _recording = !_recording;
      if (!_recording) {
        _transcript = 'Simulated transcript from push-to-talk.';
      } else {
        _transcript = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push-to-talk')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(height: 160, color: Colors.grey.shade900, child: const Center(child: Text('Push-to-talk Mockup'))),
            const SizedBox(height: 16),
            Expanded(child: Center(child: Text(_transcript.isEmpty ? 'Transcript will appear here' : _transcript))),
            GestureDetector(
              onTap: _toggle,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 120,
                height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _recording ? Colors.redAccent : Colors.green),
                child: Center(child: Icon(_recording ? Icons.mic : Icons.mic_none, size: 48, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
