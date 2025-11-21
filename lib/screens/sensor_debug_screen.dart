import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/foreground_service.dart';

class SensorDebugScreen extends StatefulWidget {
  const SensorDebugScreen({super.key});

  @override
  State<SensorDebugScreen> createState() => _SensorDebugScreenState();
}

class _SensorDebugScreenState extends State<SensorDebugScreen> {
  StreamSubscription<AccelerometerEvent>? _sub;
  double _currentG = 0.0;
  double _threshold = 6.0;

  @override
  void initState() {
    super.initState();
    _loadThreshold();
    _sub = accelerometerEventStream().listen((e) {
      final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / 9.8;
      setState(() {
        _currentG = g;
      });
    });
    // We cannot directly read native awaitingVerification; show local indicator when g > threshold
  }

  Future<void> _loadThreshold() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _threshold = prefs.getDouble('fallThreshold') ?? _threshold;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _pushToNative() async {
    final ok = await ForegroundService.setThreshold(_threshold);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Native threshold updated' : 'Failed to update native threshold')));
  }

  @override
  Widget build(BuildContext context) {
    final danger = _currentG > _threshold;
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(children: [
                  Text('Current g: ${_currentG.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Threshold: ${_threshold.toStringAsFixed(2)} g'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: (_currentG / (_threshold * 2)).clamp(0.0, 1.0)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Slider.adaptive(
                        value: _threshold,
                        min: 2.0,
                        max: 12.0,
                        divisions: 100,
                        label: _threshold.toStringAsFixed(2),
                        onChanged: (v) => setState(() => _threshold = v),
                        onChangeEnd: (v) async {
                          try {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setDouble('fallThreshold', v);
                          } catch (_) {}
                        },
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _pushToNative, icon: const Icon(Icons.sync), label: const Text('Push threshold to native service')),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(children: [
                  Text('Verification hint: ${danger ? 'POTENTIAL IMPACT' : 'OK'}', style: TextStyle(fontSize: 18, color: danger ? Colors.red : Colors.green)),
                  const SizedBox(height: 8),
                  const Text('This debug view reads accelerometer via Dart and lets you tune threshold; remember to push the threshold to native if you use always-on detection.'),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
