import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;

typedef FallCallback = void Function();

class FallDetector {
  Interpreter? _interpreter;
  final List<double> _window = [];
  final int windowSize;
  StreamSubscription? _accelSub;
  final FallCallback onFallDetected;
  double threshold;

  FallDetector({required this.onFallDetected, this.windowSize = 256, this.threshold = 0.85});

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/models/fall_detector.tflite');
    _startListening();
  }

  void _startListening() {
    _accelSub = accelerometerEventStream().listen((event) {
      final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _window.add(mag);
      if (_window.length > windowSize) _window.removeAt(0);
      if (_window.length == windowSize) _runInference();
    });
  }

  void _runInference() {
    if (_interpreter == null) return;
    try {
      // Prepare input as a List&lt;List&lt;double&gt;&gt; shaped [1, windowSize]
      final input = List.generate(windowSize, (i) => _window[i].toDouble());
      // Some models expect a 2D float array: [[...]]
      final inputArray = [input];
      // Output: assume 2 classes -> [ [non-fall_score, fall_score] ]
      final output = List.generate(1, (_) => List.filled(2, 0.0));
      _interpreter!.run(inputArray, output);
      final score = (output[0][1] as num).toDouble();
      if (score > threshold) {
        onFallDetected();
      }
    } catch (e) {
      // keep errors visible during development
      debugPrint('Inference error: $e');
    }
  }

  Future<void> dispose() async {
    await _accelSub?.cancel();
    _interpreter?.close();
    _interpreter = null;
  }
}
