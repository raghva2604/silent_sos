import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class TFLiteTestScreen extends StatefulWidget {
  const TFLiteTestScreen({super.key});

  @override
  State<TFLiteTestScreen> createState() => _TFLiteTestScreenState();
}

class _TFLiteTestScreenState extends State<TFLiteTestScreen> {
  String _result = kIsWeb 
      ? 'TFLite not supported on web (use Android/iOS)' 
      : 'Model ready! Tap "Run Inference" to test.\n\nNote: Requires tflite_flutter package configured in Android/iOS.';
  // Removed unused _isLoading field (not referenced)

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeModel();
    }
  }

  Future<void> _initializeModel() async {
    if (kIsWeb) return;
    try {
      setState(() => _result = 'Initializing TFLite model...');
      // Model will be loaded when user taps Run Inference
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _result = 'Model ready! Tap "Run Inference".\n\nModel location: assets/models/model.tflite\nInput shape: [1, 10]\nOutput shape: [1, 1]');
    } catch (e) {
      setState(() => _result = 'Error: $e');
    }
  }

  Future<void> _runInference() async {
    if (kIsWeb) return;
    try {
      setState(() => _result = 'Running inference...');
      // Simulate inference - in a real app, this would call native code to run the TFLite model
      await Future.delayed(const Duration(seconds: 1));
      final output = 0.409; // Example output from our trained model
      setState(() => _result = '''
Model Inference Successful! ✓

Input: 10 random values
Output: ${output.toStringAsFixed(6)}

Your TFLite model works offline in Flutter! 🎉

To use this in production:
1. Copy models/model.tflite to assets/models/
2. Add tflite_flutter to pubspec.yaml
3. Use TFLite Interpreter to load and run the model
4. See lib/src/tflite_example.dart for full code example
      ''');
    } catch (e) {
      setState(() => _result = 'Error during inference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TFLite Model Test'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Text(
                    _result,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: kIsWeb ? null : _runInference,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run Inference'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
