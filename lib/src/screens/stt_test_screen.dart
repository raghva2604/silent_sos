import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class STTTestScreen extends StatefulWidget {
  const STTTestScreen({super.key});

  @override
  State<STTTestScreen> createState() => _STTTestScreenState();
}

class _STTTestScreenState extends State<STTTestScreen> {
  static const _mc = MethodChannel('silent_sos/stt');
  static const _ev = EventChannel('silent_sos/stt_stream');

  String _status = 'idle';
  final List<String> _log = [];
  StreamSubscription? _sub;

  Future<void> _initModel() async {
    setState(() => _status = 'initializing');
    try {
      final ok = await _mc.invokeMethod('initModel', {'modelPath': '/sdcard/Download/vosk_te'});
      setState(() {
        _status = ok == true ? 'model initialized' : 'init failed';
      });
    } catch (e) {
      setState(() => _status = 'init error: $e');
    }
  }

  Future<void> _startListening() async {
    setState(() => _status = 'starting');
    try {
      final ok = await _mc.invokeMethod('startListening');
      if (ok == true) {
        setState(() => _status = 'listening');
        _sub = _ev.receiveBroadcastStream().listen((event) {
          try {
            final map = Map<String, dynamic>.from(event as Map);
            final t = map['text'] ?? '';
            final type = map['type'] ?? '';
            setState(() => _log.insert(0, '[$type] $t'));
          } catch (e) {
            setState(() => _log.insert(0, 'event: $event'));
          }
        }, onError: (err) {
          setState(() => _log.insert(0, 'stream error: $err'));
        });
      } else {
        setState(() => _status = 'start failed');
      }
    } catch (e) {
      setState(() => _status = 'start error: $e');
    }
  }

  Future<void> _stopListening() async {
    setState(() => _status = 'stopping');
    try {
      final ok = await _mc.invokeMethod('stopListening');
      _sub?.cancel();
      setState(() => _status = ok == true ? 'stopped' : 'stop failed');
    } catch (e) {
      setState(() => _status = 'stop error: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline STT Test')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              ElevatedButton(onPressed: _initModel, child: const Text('Init Model')),
              ElevatedButton(onPressed: _startListening, child: const Text('Start')),
              ElevatedButton(onPressed: _stopListening, child: const Text('Stop')),
            ]),
            const SizedBox(height: 12),
            const Text('Event Log:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  reverse: true,
                  itemCount: _log.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Text(_log[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
